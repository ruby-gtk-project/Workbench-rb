# frozen_string_literal: true

require 'fileutils'

require 'gtk4'
require 'adwaita'

require_relative '../settings'
require_relative '../session'
require_relative '../style'
require_relative '../theme_selector'
require_relative '../actions'
require_relative '../window'

module Workbench
  # Application is the port's entry point, ported from upstream's
  # src/application.js.
  #
  # On startup it installs the stylesheet, applies the stored colour scheme,
  # registers the application actions, and reopens a window on every session
  # it finds — a scratch session from the data directory, or a project
  # remembered in `recent-projects`. With nothing to reopen it starts a new
  # session, which is where upstream opens the Welcome demo on a first run and
  # the Library after that; neither is ported yet.
  #
  # Upstream's application object is an Adw.Application. Adwaita::Application
  # is broken in the Ruby bindings, so the application comes from Gtk and
  # Adwaita is initialised by hand, which is what Adw.Application would do.
  class Application
    APPLICATION_ID = 'org.rubygtkproject.Workbench'

    def initialize(app_settings: Settings.app)
      @app_settings = app_settings
    end

    attr_reader :app_settings

    def build
      app.tap do |application|
        application.signal_connect('startup') do
          Adwaita.init
          FileUtils.mkdir_p(Session.data_dir)
          Style.install
          apply_color_scheme
          app_settings.on_change('color-scheme') { apply_color_scheme }
          actions.build
        end

        application.signal_connect('activate') { restore_sessions }

        application.signal_connect('open') do |_application, files, hint|
          open_files(files, hint)
        end
      end
    end

    def run(argv = []) = app.run(argv)

    def app
      @app ||= Gtk::Application.new(APPLICATION_ID, :handles_open)
    end

    def actions
      @actions ||= Actions.new(application: app, app_settings: app_settings)
    end

    private

      def apply_color_scheme
        Adwaita::StyleManager.default.color_scheme =
          ThemeSelector::SCHEMES.fetch(app_settings.get_int('color-scheme'), :default)
      end

    # One window per session, as upstream's restoreSessions does, and a fresh
    # session when there is nothing to restore.
      def restore_sessions
        if app.windows.empty?
          Session.all(settings: app_settings).then do |sessions|
            if sessions.empty?
              actions.open_session(Session.create)
            else
              sessions.each { |session| actions.open_session(session) }
            end
          end
        else
          app.active_window.present
        end
      end

    # Upstream only opens a folder handed to it with the "project" hint.
      def open_files(files, hint)
        files.first.then do |file|
          if file && hint == 'project'
            Session.add_to_recent_projects(file.path, settings: app_settings)
            actions.open_session(Session.new(file.path))
          end
        end
      end
  end
end
