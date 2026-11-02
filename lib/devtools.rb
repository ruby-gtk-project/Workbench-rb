# frozen_string_literal: true

require 'adwaita'

require_relative 'term_console'

# Devtools is the bottom half of the window, ported from upstream's
# src/Devtools.js and the `Adw.ToolbarView panel_devtools` definition in
# src/window.blp.
#
# It owns the console toolbar — the Console toggle, the Inspector button, the
# Clear button — the console itself, and the collapsing behaviour of the paned
# that separates it from the panels: dragging the handle to the bottom turns
# the console off, turning it off collapses the pane to the height of the
# toolbar, and turning it back on restores the height it had.
class Devtools
  COLLAPSE_THRESHOLD = 50
  DEFAULT_HEIGHT = 200

  ACTIONS = { 'console' => ['<Control><Shift>K'] }.freeze

  def initialize(application:, window:, settings:, paned:)
    @application = application
    @window = window
    @settings = settings
    @paned = paned
    @position = nil
  end

  attr_reader :application, :window, :settings, :paned

  def term_console
    @term_console ||= TermConsole.new(
      application:  application,
      window:       window,
      settings:     settings,
      button_clear: button_clear,
    )
  end

  def build
    panel.tap do |view|
      view.add_top_bar(toolbar)
      view.content = content

      toolbar.tap do |bar|
        bar.start_widget = start_box
        bar.end_widget = end_box

        start_box.tap do |box|
          box.append(button_console)
          box.append(button_inspector)
        end

        end_box.append(button_clear)
      end

      content.append(term_console.build)

      settings.bind('show-console', button_console, 'active')

      window.add_action(action_console)
      action_console.signal_connect('activate') do
        settings.set_boolean('show-console', !settings.get_boolean('show-console'))
      end
      ACTIONS.each do |name, accelerators|
        application.set_accels_for_action("win.#{name}", accelerators)
      end

      button_console.signal_connect_after('notify::active') { setup_paned }
      paned.signal_connect_after('notify::position') { follow_position }

      setup_paned
    end
  end

  def panel
    @panel ||= Adwaita::ToolbarView.new.tap do |view|
      view.name = 'panel_devtools'
    end
  end

  def button_inspector
    @button_inspector ||= Gtk::Button.new.tap do |button|
      button.child = Adwaita::ButtonContent.new.tap do |label|
        label.icon_name = 'find-location-symbolic'
        label.label = '_Inspector'
        label.use_underline = true
      end
      button.tooltip_text = 'Open GTK Inspector (Ctrl+Shift+I)'
    end
  end

  private

    def toolbar
      @toolbar ||= Gtk::CenterBox.new.tap do |box|
        box.name = 'toolbar_devtools'
        box.add_css_class('toolbar')
        box.add_css_class('panel_header')
      end
    end

    def start_box = @start_box ||= Gtk::Box.new(:horizontal, 6)

    def end_box = @end_box ||= Gtk::Box.new(:horizontal, 6)

    def content = @content ||= Gtk::Box.new(:horizontal, 0)

    def button_console
      @button_console ||= Gtk::ToggleButton.new.tap do |button|
        button.child = Adwaita::ButtonContent.new.tap do |label|
          # Upstream's "re.sonny.Workbench-terminal-symbolic".
          label.icon_name = 'utilities-terminal-symbolic'
          label.label = 'C_onsole'
          label.use_underline = true
        end
        button.action_name = 'win.console'
        button.tooltip_text = 'Show Logs (Ctrl+Shift+K)'
      end
    end

    def button_clear
      @button_clear ||= Gtk::Button.new.tap do |button|
        button.child = Adwaita::ButtonContent.new.tap do |label|
          # Upstream's "re.sonny.Workbench-eraser4-symbolic".
          label.icon_name = 'edit-clear-symbolic'
          label.label = 'Cl_ear'
          label.use_underline = true
        end
        button.action_name = 'win.clear'
        button.tooltip_text = 'Clear Console (Ctrl+K)'
      end
    end

    def action_console = @action_console ||= Gio::SimpleAction.new('console')

    def toolbar_height = toolbar.height

    def paned_height = paned.height

    def collapsed?
      paned_height <= paned.position + toolbar_height
    end

    def collapse
      term_console.widget.visible = false
      settings.set_boolean('show-console', false)
      paned.position = paned_height - toolbar_height
    end

    def uncollapse
      term_console.widget.visible = true
      settings.set_boolean('show-console', true)
    end

    # Dragging the handle most of the way down is the same as turning the
    # console off.
    def follow_position
      if paned.position + toolbar_height > paned_height - COLLAPSE_THRESHOLD
        collapse
      else
        uncollapse
      end
    end

    def setup_paned
      if button_console.active?
        term_console.widget.visible = true
        if collapsed?
          content.set_size_request(-1, DEFAULT_HEIGHT)
          if @position && @position < paned_height - toolbar_height - COLLAPSE_THRESHOLD
            paned.position = @position
          else
            paned.position = paned_height - DEFAULT_HEIGHT
          end
        end
      else
        @position = paned.position
        paned.position = paned_height - toolbar_height
        term_console.widget.visible = false
        content.set_size_request(-1, toolbar_height)
      end
    end
end
