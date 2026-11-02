# frozen_string_literal: true

require 'adwaita'

# PanelStyle is the CSS panel, ported from upstream's src/PanelStyle.js and
# the `Adw.ToolbarView panel_style` definition in src/window.blp.
#
# It is the simplest of the panels: a header with a title and the CSS editor
# below it. Its visibility and the header bar's Style toggle are two views of
# the session's `show-style` key, exactly as upstream binds them.
class PanelStyle
  def initialize(settings:, button:, code_view:)
    @settings = settings
    @button = button
    @code_view = code_view
  end

  attr_reader :settings, :button, :code_view

  def build
    panel.tap do |view|
      view.add_top_bar(header)
      view.content = content

      header.start_widget = title

      content.tap do |box|
        box.append(separator)
        box.append(code_view.build)
      end

      settings.bind('show-style', button, 'active')
      button.bind_property(
        'active',
        panel,
        'visible',
        :sync_create,
      )
    end
  end

  def panel
    @panel ||= Adwaita::ToolbarView.new.tap do |view|
      view.name = 'panel_style'
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

    def title
      @title ||= Gtk::Label.new.tap do |label|
        label.label = '<b>Style CSS</b>'
        label.use_markup = true
        label.add_css_class('dim-label')
      end
    end

    def content = @content ||= Gtk::Box.new(:vertical, 0)

    def separator = @separator ||= Gtk::Separator.new(:horizontal)
end
