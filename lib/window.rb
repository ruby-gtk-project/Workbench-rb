# frozen_string_literal: true

require 'adwaita'

require_relative 'language'
require_relative 'settings'
require_relative 'session'
require_relative 'document'
require_relative 'xml_document'
require_relative 'blueprint_document'
require_relative 'javascript_document'
require_relative 'type_script_document'
require_relative 'vala_document'
require_relative 'rust_document'
require_relative 'python_document'
require_relative 'css_document'
require_relative 'code_view'
require_relative 'app_menu'
require_relative 'theme_selector'
require_relative 'panel_code'
require_relative 'panel_style'
require_relative 'panel_ui'
require_relative 'panel_preview'
require_relative 'previewer'
require_relative 'devtools'
require_relative 'save_project_dialog'

# Window is one session open for editing, ported from upstream's
# src/window.blp and src/window.js.
#
# The header bar carries the Library button, the four panel toggles and the Run
# button; below it the panels sit side by side above the console, separated by
# a paned the console collapses into. Each panel's visibility is a key of the
# session's settings, so a window reopens the way it was left, and the
# placeholder shows when every panel is off.
#
# Closing the window is where a scratch session is decided: a saved project is
# only forgotten, an untouched session is deleted, and an edited one asks
# whether to keep it.
#
# Two things upstream does here are missing because the components they belong
# to are not ported: the per-language builders and compilers
# (src/langs/*/Builder.js and Compiler.js), so Run formats the documents and
# redraws the preview but does not execute the code; and the Extensions and
# Permissions dialogs, so `win.extensions` and `win.permissions` have no
# action behind them yet and their menu items are insensitive.
class Window
  ACTIONS = {
    'run'    => ['<Control>Return'],
    'format' => ['<Control><Shift>Return'],
    'close'  => ['<Control>W'],
    'reveal' => ['<Control>M'],
  }.freeze

  # The languages this port can hold a document for, now that lib/lsp_client.rb
  # exists: every language's document, including blueprint's.
  DOCUMENT_LANGUAGES = %w[javascript typescript vala rust python xml css blueprint].freeze

  # Upstream's per-language Document subclass for each language that has one;
  # xml's own document otherwise.
  DOCUMENT_CLASSES = {
    'blueprint'  => BlueprintDocument,
    'javascript' => JavaScriptDocument,
    'typescript' => TypeScriptDocument,
    'vala'       => ValaDocument,
    'rust'       => RustDocument,
    'python'     => PythonDocument,
    'css'        => CssDocument,
    'xml'        => XmlDocument,
  }.freeze

  PANEL_KEYS = %w[show-preview show-ui show-style show-code].freeze

  # The height the panels keep when the console is expanded.
  DEVTOOLS_MIN_HEIGHT = 200

  def initialize(application:, session:, app_settings: Settings.app)
    @application = application
    @session = session
    @app_settings = app_settings
  end

  attr_reader :application, :session, :app_settings

  def settings = session.settings

  def build
    window.tap do |win|
      application.add_window(win)
      win.title = "Workbench — #{session.name}"
      win.content = toolbar_view

      toolbar_view.tap do |view|
        view.top_bar_style = :raised
        view.add_top_bar(header_bar)
        view.content = toast_overlay
      end

      header_bar.tap do |bar|
        bar.pack_start(button_library)
        bar.title_widget = toggles
        bar.pack_end(button_menu)
        bar.pack_end(button_run)

        toggles.tap do |box|
          box.append(button_code)
          box.append(button_style)
          box.append(button_ui)
          box.append(button_preview)
        end

        button_menu.popover.add_child(theme_selector.build, AppMenu::THEME_SWITCHER)
      end

      toast_overlay.child = paned

      # The preview panel and the previewer are built first: switching the
      # code panel's language resets the previewer, which needs its widgets.
      panel_preview.build
      previewer.build

      paned.tap do |pane|
        pane.start_child = panels_box
        pane.end_child = devtools.build
        pane.shrink_start_child = false
        pane.shrink_end_child = true
        pane.resize_start_child = true
        pane.resize_end_child = true

        panels_box.tap do |box|
          box.append(panel_code.build)
          box.append(panel_style.build)
          box.append(panel_ui.build)
          box.append(panel_preview.panel)
          box.append(placeholder)
          box.set_size_request(-1, DEVTOOLS_MIN_HEIGHT)
        end
      end

      devtools.button_inspector.signal_connect('clicked') { previewer.open_inspector }

      install_actions
      restore_geometry

      PANEL_KEYS.each { |key| settings.on_change(key) { update_placeholder } }
      update_placeholder

      win.signal_connect('close-request') do
        on_close_session
        true
      end

      win.present
    end
  end

  # Upstream's load(): stop everything, read every document off disk, then
  # start everything again so the first preview is drawn from the real files.
  def load
    session.load
    panel_ui.stop
    previewer.stop
    documents.each_value(&:stop)
    documents.each_value(&:load)
    previewer.use_internal
    term_console.clear
    panel_ui.start
    panel_ui.update
    previewer.start
    previewer.update(true)
    documents.each_value(&:start)
    term_console.scroll_to_end
    self
  end

  # Upstream's runCode(), without the compile step: the console is cleared, the
  # session's icons are picked up again, the documents are formatted and the
  # preview is redrawn.
  def run
    button_run.sensitive = false
    term_console.clear
    previewer.stop
    panel_ui.stop

    session.load_icons
    panel_ui.update
    format_code

    previewer.start
    panel_ui.start
    previewer.update(true)

    button_run.sensitive = true
    term_console.scroll_to_end
    self
  end

  # Upstream's formatCode(): only the documents the visible panels show.
  def format_code
    visible_documents.each(&:format)
    self
  end

  def window
    @window ||= Adwaita::ApplicationWindow.new(application).tap do |win|
      win.set_default_size(1920, 1200)
    end
  end

  def code_views
    @code_views ||= DOCUMENT_LANGUAGES.to_h do |id|
      [id, CodeView.new(language_id: id)]
    end
  end

  def documents
    @documents ||= DOCUMENT_LANGUAGES.to_h do |id|
      Language[id].then do |language|
        [
          id,
          DOCUMENT_CLASSES.fetch(id).new(
            session:   session,
            code_view: code_views.fetch(id),
            language:  language,
          ),
        ]
      end
    end
  end

  def panel_code
    @panel_code ||= PanelCode.new(
      settings:     settings,
      app_settings: app_settings,
      button:       button_code,
      previewer:    previewer,
      code_views:   code_views,
      typescript:   app_settings.get_boolean('typescript'),
    )
  end

  def panel_style
    @panel_style ||= PanelStyle.new(
      settings:  settings,
      button:    button_style,
      code_view: code_views.fetch('css'),
    )
  end

  def panel_ui
    @panel_ui ||= PanelUI.new(
      settings:     settings,
      button:       button_ui,
      application:  application,
      term_console: term_console,
      documents:    { 'xml' => documents.fetch('xml'), 'blueprint' => documents.fetch('blueprint') },
    )
  end

  def panel_preview
    @panel_preview ||= PanelPreview.new(settings: settings, button: button_preview)
  end

  def previewer
    @previewer ||= Previewer.new(
      panel:        panel_preview,
      xml_source:   panel_ui,
      css_view:     code_views.fetch('css'),
      term_console: term_console,
      settings:     settings,
      session:      session,
    )
  end

  def devtools
    @devtools ||= Devtools.new(
      application: application,
      window:      window,
      settings:    settings,
      paned:       paned,
    )
  end

  def term_console = devtools.term_console

  def button_run
    @button_run ||= Gtk::Button.new.tap do |button|
      button.child = Adwaita::ButtonContent.new.tap do |content|
        content.icon_name = 'media-playback-start-symbolic'
        content.label = '_Run'
        content.use_underline = true
      end
      button.action_name = 'win.run'
      button.tooltip_text = 'Run (Ctrl+⏎)'
      button.add_css_class('suggested-action')
    end
  end

  private

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Gtk::HeaderBar.new

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    def paned
      @paned ||= Gtk::Paned.new(:vertical).tap do |pane|
        pane.vexpand = true
      end
    end

    def panels_box
      @panels_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.vexpand = true
        box.homogeneous = true
      end
    end

    def placeholder
      @placeholder ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.name = 'placeholder'
        box.visible = false
        box.halign = :center
        box.valign = :center
        box.append(placeholder_image)
      end
    end

    def placeholder_image
      @placeholder_image ||= Gtk::Image.new.tap do |image|
        # Upstream's "re.sonny.Workbench-placeholder-symbolic".
        image.icon_name = 'applications-engineering-symbolic'
        image.pixel_size = 512
      end
    end

    def button_library
      @button_library ||= Gtk::Button.new.tap do |button|
        button.child = Adwaita::ButtonContent.new.tap do |content|
          # Upstream's "re.sonny.Workbench-library-symbolic".
          content.icon_name = 'view-grid-symbolic'
          content.label = '_Library'
          content.use_underline = true
        end
        button.action_name = 'app.library'
        button.tooltip_text = 'Open Library of Demos and Examples (Ctrl+Shift+O)'
      end
    end

    def toggles
      @toggles ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.homogeneous = true
      end
    end

    def button_code = @button_code ||= toggle('_Code', 'text-x-generic-symbolic')
    def button_style = @button_style ||= toggle('_Style', 'applications-graphics-symbolic')
    def button_ui = @button_ui ||= toggle('_UI', 'view-paged-symbolic')
    def button_preview = @button_preview ||= toggle('_Preview', 'video-display-symbolic')

    # Upstream's toggles are an Image and a Label in a Box, styled flat and
    # `view-toggler`; its icons are its own, so the port uses stock ones.
    def toggle(label, icon_name)
      Gtk::ToggleButton.new.tap do |button|
        button.child = Gtk::Box.new(:horizontal, 0).tap do |box|
          box.halign = :center
          box.append(Gtk::Image.new(icon_name: icon_name))
          box.append(Gtk::Label.new(label).tap { |text| text.use_underline = true })
        end
        button.add_css_class('flat')
        button.add_css_class('view-toggler')
      end
    end

    def button_menu
      @button_menu ||= Gtk::MenuButton.new.tap do |button|
        button.menu_model = AppMenu.new.model
        button.icon_name = 'open-menu-symbolic'
        button.tooltip_text = 'Main Menu'
        button.primary = true
      end
    end

    def theme_selector = @theme_selector ||= ThemeSelector.new(app_settings)

    def visible_documents
      documents.values.select do |document|
        case document.language.panel
        when 'code'  then panel_code.panel.visible? && panel_code.language == document.language.name
        when 'style' then panel_style.panel.visible?
        when 'ui'    then panel_ui.panel.visible?
        end
      end
    end

    def install_actions
      action_run.signal_connect('activate') { run }
      action_format.signal_connect('activate') { format_code }
      action_close.signal_connect('activate') { window.close }
      action_reveal.signal_connect('activate') { reveal }

      [action_run, action_format, action_close, action_reveal].each do |action|
        window.add_action(action)
      end

      window.add_action(settings.create_action('safe-mode'))
      window.add_action(settings.create_action('auto-preview'))

      ACTIONS.each do |name, accelerators|
        application.set_accels_for_action("win.#{name}", accelerators)
      end
    end

    def action_run = @action_run ||= Gio::SimpleAction.new('run')
    def action_format = @action_format ||= Gio::SimpleAction.new('format')
    def action_close = @action_close ||= Gio::SimpleAction.new('close')
    def action_reveal = @action_reveal ||= Gio::SimpleAction.new('reveal')

    def reveal
      Gtk::FileLauncher.new(Gio::File.new_for_path(session.directory))
                       .launch(window, nil) { |_source, _result| }
    end

    # Upstream's persistWindowState, from troll.
    def restore_geometry
      settings.get_int('window-width').then do |width|
        settings.get_int('window-height').then do |height|
          if width.positive? && height.positive?
            window.set_default_size(width, height)
          end
        end
      end
      if settings.get_boolean('window-maximized')
        window.maximize
      end
      if settings.get_boolean('window-fullscreened')
        window.fullscreen
      end

      window.signal_connect('notify::default-width') { record_geometry }
      window.signal_connect('notify::default-height') { record_geometry }
      window.signal_connect('notify::maximized') { record_geometry }
      window.signal_connect('notify::fullscreened') { record_geometry }
    end

    def record_geometry
      unless window.maximized? || window.fullscreened?
        settings.set_int('window-width', window.default_width)
        settings.set_int('window-height', window.default_height)
      end
      settings.set_boolean('window-maximized', window.maximized?)
      settings.set_boolean('window-fullscreened', window.fullscreened?)
    end

    def update_placeholder
      placeholder.visible = PANEL_KEYS.none? { |key| settings.get_boolean(key) }
    end

    # Upstream's onCloseSession.
    def on_close_session
      if session.project?
        Session.remove_from_recent_projects(session.directory, settings: app_settings)
        close_window
      elsif !settings.get_boolean('edited')
        session.delete
        close_window
      else
        prompt_session_close
      end
    end

    def prompt_session_close
      SaveProjectDialog.new(window).choose do |response, destination|
        case response
        when SaveProjectDialog::DISCARD
          session.delete
          close_window
        when SaveProjectDialog::SAVE
          session.save_as_project(destination).then do |project|
            Session.add_to_recent_projects(project.directory, settings: app_settings)
          end
          close_window
        end
      end
    end

    def close_window
      session.unload
      window.destroy
    end
end
