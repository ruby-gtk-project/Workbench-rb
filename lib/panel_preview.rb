# frozen_string_literal: true

require 'adwaita'

# PanelPreview is the preview panel, ported from the `Adw.ToolbarView
# panel_preview` and `menu preview_menu` definitions in upstream's
# src/window.blp, together with the `show-preview` binding src/window.js makes
# for it.
#
# The panel holds the three states a preview can be in, as a stack: shown
# inline in the viewport, or offered as a separate window, or already open in
# one. The previewer switches between them; this class only owns the widgets
# and the menu.
class PanelPreview
  INLINE = 'inline'
  OPEN_WINDOW = 'open_window'
  CLOSE_WINDOW = 'close_window'

  WINDOWED_DESCRIPTION =
    "This interface can only be previewed as a separate window.\n" \
    'We recommend using “Always on Top”.'

  def initialize(settings:, button:)
    @settings = settings
    @button = button
  end

  attr_reader :settings, :button

  def build
    panel.tap do |view|
      view.add_top_bar(header)
      view.content = content

      header.tap do |bar|
        bar.start_widget = button_menu
        bar.center_widget = dropdown_align
        bar.end_widget = button_screenshot
      end

      content.tap do |box|
        box.append(separator)
        box.append(stack)

        stack.tap do |pages|
          pages.add_named(inline_page, INLINE)
          pages.add_named(open_window_page, OPEN_WINDOW)
          pages.add_named(close_window_page, CLOSE_WINDOW)
        end
      end

      inline_page.tap do |box|
        box.append(scrolled_window)
        box.append(inline_separator)

        scrolled_window.child = output
      end

      open_window_page.child = open_window_buttons
      open_window_buttons.append(button_open_window)

      close_window_page.child = close_window_buttons
      close_window_buttons.append(button_close_window)

      settings.bind('show-preview', button, 'active')
      button.bind_property(
        'active',
        panel,
        'visible',
        :sync_create,
      )
    end
  end

  def show(name) = stack.visible_child_name = name

  def panel
    @panel ||= Adwaita::ToolbarView.new.tap do |view|
      view.name = 'panel_preview'
    end
  end

  # The viewport the inline preview is placed in. Its name scopes the CSS the
  # previewed stylesheet is rewritten into, so the preview's styles cannot
  # leak into the rest of the window.
  def output
    @output ||= Gtk::Viewport.new.tap do |viewport|
      viewport.halign = :fill
      viewport.valign = :fill
      viewport.add_css_class('background')
    end
  end

  def stack = @stack ||= Gtk::Stack.new

  def dropdown_align
    @dropdown_align ||= Gtk::DropDown.new.tap do |drop|
      drop.model = Gtk::StringList.new(%w[Fill Center])
      drop.tooltip_text = 'Select Preview Mode'
      drop.visible = false
      # Upstream's makeDropdownFlat.
      drop.first_child.add_css_class('flat')
    end
  end

  def button_screenshot
    @button_screenshot ||= Gtk::Button.new.tap do |button|
      # Upstream's own "re.sonny.Workbench-screenshot-symbolic"; the port ships
      # no icon theme, so it uses the stock camera icon.
      button.icon_name = 'camera-photo-symbolic'
      button.tooltip_text = 'Screenshot Preview'
    end
  end

  def button_open_window
    @button_open_window ||= Gtk::Button.new(label: 'Show Preview Window').tap do |button|
      button.add_css_class('pill')
      button.add_css_class('suggested-action')
    end
  end

  def button_close_window
    @button_close_window ||= Gtk::Button.new(label: 'Close Preview Window').tap do |button|
      button.add_css_class('pill')
    end
  end

  # `menu preview_menu`: the two session toggles the window exposes as
  # stateful actions.
  def menu_model
    @menu_model ||= Gio::Menu.new.tap do |menu|
      menu.append('Auto-Update', 'win.auto-preview')
      menu.append('Safe Mode', 'win.safe-mode')
    end
  end

  private

    def header
      @header ||= Gtk::CenterBox.new.tap do |box|
        box.add_css_class('toolbar')
        box.add_css_class('panel_header')
        box.height_request = 46
      end
    end

    def button_menu
      @button_menu ||= Gtk::MenuButton.new.tap do |button|
        button.label = 'Preview'
        button.halign = :center
        button.valign = :center
        button.add_css_class('flat')
        button.menu_model = menu_model
      end
    end

    def content = @content ||= Gtk::Box.new(:vertical, 0)

    def separator = @separator ||= Gtk::Separator.new(:horizontal)

    def inline_separator = @inline_separator ||= Gtk::Separator.new(:horizontal)

    def inline_page = @inline_page ||= Gtk::Box.new(:horizontal, 0)

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
        window.vexpand = true
        window.hexpand = true
      end
    end

    def open_window_page = @open_window_page ||= windowed_status_page

    def close_window_page = @close_window_page ||= windowed_status_page

    def windowed_status_page
      Adwaita::StatusPage.new.tap do |page|
        page.title = 'Windowed Preview'
        page.description = WINDOWED_DESCRIPTION
        # Upstream's "re.sonny.Workbench-multitasking-windows-symbolic".
        page.icon_name = 'view-dual-symbolic'
      end
    end

    def open_window_buttons = @open_window_buttons ||= centered_box

    def close_window_buttons = @close_window_buttons ||= centered_box

    def centered_box
      Gtk::Box.new(:horizontal, 0).tap do |box|
        box.halign = :center
      end
    end
end
