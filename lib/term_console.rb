# frozen_string_literal: true

require 'adwaita'

# TermConsole is the log pane at the bottom of the window, ported from
# upstream's src/TermConsole.js and the `menu menu_console` definition in
# src/window.blp.
#
# Upstream's console is a Vte.Terminal following a log file with `tail`, which
# is how the output of the out-of-process previewers and of `console.log` in
# previewed code reaches it. The Vte bindings are not available to the port, so
# the pane is a read-only text view the app writes to with `#log`, and the
# three terminal operations the window binds accelerators to — clear, copy,
# select all — act on its buffer. The palette upstream sets on the terminal
# becomes the view's foreground and background, which still follow the theme.
class TermConsole
  ACTIONS = {
    'clear'              => ['<Control>K'],
    'console_copy'       => ['<Control><Shift>C'],
    'console_select_all' => ['<Control><Shift>A'],
  }.freeze

  LIGHT_BACKGROUND = '#fcfcfc'
  DARK_BACKGROUND = '#262626'

  def initialize(application:, window:, settings:, button_clear:)
    @application = application
    @window = window
    @settings = settings
    @button_clear = button_clear
  end

  attr_reader :application, :window, :settings, :button_clear

  def build
    box.tap do |b|
      b.append(scrolled_window)
      scrolled_window.child = text_view

      install_actions

      settings.bind('show-console', button_clear, 'visible')

      text_view.signal_connect('notify::visible') do |this|
        if this.visible?
          scroll_to_end
        end
      end

      buffer.signal_connect('notify::has-selection') { update_copy_action }

      text_view.add_controller(gesture_click)
      gesture_click.signal_connect('pressed') do |_gesture, _presses, x, y|
        popover_menu.pointing_to = Gdk::Rectangle.new(
          x.to_i,
          y.to_i,
          1,
          1,
        )
        popover_menu.popup
      end

      install_colors_provider
      Adwaita::StyleManager.default.signal_connect('notify::dark') { update_colors }
      update_colors
    end
  end

  # Upstream feeds the terminal; the port appends to the buffer and keeps the
  # view pinned to the bottom.
  def log(message)
    buffer.insert(buffer.end_iter, "#{message}\n")
    scroll_to_end
    self
  end

  def clear
    buffer.text = ''
    self
  end

  def scroll_to_end
    scrolled_window.vadjustment.then do |adjustment|
      adjustment.value = adjustment.upper
    end
    self
  end

  def box = @box ||= Gtk::Box.new(:vertical, 0)

  def widget = box

  def scrolled_window
    @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
      window.vexpand = true
      window.hexpand = true
    end
  end

  def text_view
    @text_view ||= Gtk::TextView.new.tap do |view|
      view.monospace = true
      view.editable = false
      view.cursor_visible = false
      view.left_margin = 6
      view.right_margin = 6
      view.top_margin = 6
      view.bottom_margin = 6
    end
  end

  def menu_model
    @menu_model ||= Gio::Menu.new.tap do |menu|
      Gio::Menu.new.tap do |section|
        section.append('Copy', 'win.console_copy')
        section.append('Select All', 'win.console_select_all')
        section.append('Clear', 'win.clear')
        menu.append_section(nil, section)
      end
    end
  end

  private

    def buffer = text_view.buffer

    def gesture_click
      @gesture_click ||= Gtk::GestureClick.new.tap do |gesture|
        gesture.button = 3
      end
    end

    # Parented lazily, on the first right-click, rather than unconditionally
    # from `build`: a popover kept permanently parented to a GtkTextView that
    # is never shown is what produced a storm of "GtkPopoverMenu is not a
    # child of GtkTextView" warnings — and the CPU-pinned hang that came with
    # it — the moment a second window (and so a second such popover) existed.
    def popover_menu
      @popover_menu ||= Gtk::PopoverMenu.new(menu_model).tap do |popover|
        popover.has_arrow = false
        popover.halign = :start
        popover.set_parent(text_view)
      end
    end

    def action_clear = @action_clear ||= Gio::SimpleAction.new('clear')

    def action_console_copy
      @action_console_copy ||= Gio::SimpleAction.new('console_copy').tap do |action|
        action.enabled = false
      end
    end

    def action_console_select_all
      @action_console_select_all ||= Gio::SimpleAction.new('console_select_all')
    end

    def install_actions
      action_clear.signal_connect('activate') { clear }
      action_console_copy.signal_connect('activate') { copy_selection }
      action_console_select_all.signal_connect('activate') { select_all }

      [action_clear, action_console_copy, action_console_select_all].each do |action|
        window.add_action(action)
      end

      ACTIONS.each do |name, accelerators|
        application.set_accels_for_action("win.#{name}", accelerators)
      end
    end

    def copy_selection
      buffer.selection_bounds.then do |bounds|
        if bounds
          Gdk::Display.default.clipboard.set(
            buffer.get_text(bounds[0], bounds[1], true),
          )
        end
      end
    end

    def select_all
      buffer.select_range(buffer.start_iter, buffer.end_iter)
      update_copy_action
    end

    def update_copy_action
      action_console_copy.enabled = !buffer.selection_bounds.nil?
    end

    # Upstream's updateTerminalColors, reduced to the two colours a text view
    # has: the background it sets on the terminal, and a foreground that reads
    # against it.
    def update_colors
      Adwaita::StyleManager.default.dark?.then do |dark|
        colors_provider.load_from_data(<<~CSS)
          #term_console, #term_console text {
            background-color: #{dark ? DARK_BACKGROUND : LIGHT_BACKGROUND};
            color: #{dark ? '#ffffff' : '#000000'};
          }
        CSS
      end
    end

    def colors_provider = @colors_provider ||= Gtk::CssProvider.new

    def install_colors_provider
      text_view.name = 'term_console'
      Gdk::Display.default.then do |display|
        if display
          Gtk::StyleContext.add_provider_for_display(
            display,
            colors_provider,
            Gtk::StyleProvider::PRIORITY_APPLICATION,
          )
        end
      end
    end
end
