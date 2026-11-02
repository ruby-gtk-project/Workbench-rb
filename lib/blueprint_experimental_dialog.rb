# frozen_string_literal: true

require 'adwaita'

# BlueprintExperimentalDialog is the warning shown by the UI panel's flask
# button, ported from the `Adw.Dialog dialog_blueprint_experimental` definition
# in upstream's src/window.blp, together with the handler src/PanelUI.js
# attaches to its documentation button.
class BlueprintExperimentalDialog
  DOCUMENTATION_URI = 'https://gnome.pages.gitlab.gnome.org/blueprint-compiler'

  def initialize(parent)
    @parent = parent
  end

  attr_reader :parent

  def build
    dialog.tap do |d|
      d.child = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = status_page

        status_page.child = button_documentation

        button_documentation.signal_connect('clicked') do
          Gtk::UriLauncher.new(DOCUMENTATION_URI).launch(parent, nil) { |_source, _result| }
        end
      end
    end
  end

  def present = build.present(parent)

  def dialog
    @dialog ||= Adwaita::Dialog.new.tap do |d|
      d.content_width = 368
      d.content_height = 480
    end
  end

  private

    def toolbar_view
      @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
        view.extend_content_to_top_edge = true
      end
    end

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.vexpand = true
        page.title = "Blueprint is\nExperimental"
        page.description = 'Future versions may have breaking syntax'
        # Upstream's icon is its own "re.sonny.Workbench-beaker"; the port
        # ships no icon theme of its own, so it uses the stock one.
        page.icon_name = 'applications-science-symbolic'
      end
    end

    def button_documentation
      @button_documentation ||= Gtk::Button.new(label: 'Documentation').tap do |button|
        button.halign = :center
        button.add_css_class('suggested-action')
        button.add_css_class('pill')
      end
    end
end
