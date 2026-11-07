# frozen_string_literal: true

require 'adwaita'
require 'ashpd'

require_relative 'settings'
require_relative 'session'
require_relative 'window'
require_relative 'about_dialog'
require_relative 'shortcuts_window'
require_relative 'library_window'

# Actions installs the application's actions, ported from upstream's
# src/actions.js.
#
# These are the actions the primary menu and the application's accelerators
# refer to: quitting, the About dialog, opening a URI or one of the platform
# demos, the colour scheme, and the two that make windows — a new scratch
# session, and a project chosen from disk.
#
# Upstream opens a project by handing the folder back to the application's
# `open` handler and shows a captured screenshot through the XDG desktop
# portal (Xdp.Portal#open_directory). The port reaches that same portal
# through the ashpd gem's Ashpd::OpenUri — a Rust/zbus binding rather than
# the libportal GI typelib upstream uses, but the same
# org.freedesktop.portal.OpenURI call.
class Actions
  PLATFORM_TOOLS = %w[adwaita-1-demo gtk4-demo gtk4-widget-factory].freeze

  ACCELERATORS = {
    'app.quit'            => ['<Control>Q'],
    'app.new'             => ['<Control>N'],
    "app.open('project')" => ['<Control>O'],
  }.freeze

  def initialize(application:, app_settings: Settings.app)
    @application = application
    @app_settings = app_settings
  end

  attr_reader :application, :app_settings

  def build
    application.tap do |app|
      simple_actions.each_value { |action| app.add_action(action) }
      app.add_action(app_settings.create_action('color-scheme'))

      action_quit.signal_connect('activate') { app.quit }
      action_about.signal_connect('activate') { AboutDialog.new(app).present }
      # Ruby-GNOME unwraps a simple-typed GVariant parameter to its native
      # Ruby value before the 'activate' handler sees it, so `target` here is
      # already a plain String, not a GLib::Variant — calling `.value` on it
      # raised NoMethodError and made these three actions unreachable the
      # moment they were actually activated.
      action_open_uri.signal_connect('activate') { |_action, target| open_uri(target) }
      action_platform_tools.signal_connect('activate') do |_action, target|
        platform_tool(target)
      end
      action_new.signal_connect('activate') { new_project }
      action_open.signal_connect('activate') { open_project }
      action_show_screenshot.signal_connect('activate') do |_action, target|
        show_screenshot(target)
      end

      ACCELERATORS.each { |name, accelerators| app.set_accels_for_action(name, accelerators) }

      shortcuts_window.build
      library_window.install_action
    end
  end

  # Opens a window on a session and reads its documents in.
  def open_session(session)
    Window.new(
      application:  application,
      session:      session,
      app_settings: app_settings,
    ).tap do |window|
      window.build
      window.load
    end
  end

  def shortcuts_window = @shortcuts_window ||= ShortcutsWindow.new(application)

  def library_window
    @library_window ||= LibraryWindow.new(application: application, app_settings: app_settings) do |session|
      open_session(session)
    end
  end

  private

    def simple_actions
      @simple_actions ||= {
        'quit'            => action_quit,
        'about'           => action_about,
        'open_uri'        => action_open_uri,
        'platform_tools'  => action_platform_tools,
        'new'             => action_new,
        'open'            => action_open,
        'show-screenshot' => action_show_screenshot,
      }
    end

    def action_quit = @action_quit ||= Gio::SimpleAction.new('quit')
    def action_about = @action_about ||= Gio::SimpleAction.new('about')
    def action_new = @action_new ||= Gio::SimpleAction.new('new')

    def action_open_uri
      @action_open_uri ||= Gio::SimpleAction.new('open_uri', string_type)
    end

    def action_platform_tools
      @action_platform_tools ||= Gio::SimpleAction.new('platform_tools', string_type)
    end

    def action_open = @action_open ||= Gio::SimpleAction.new('open', string_type)

    def action_show_screenshot
      @action_show_screenshot ||= Gio::SimpleAction.new('show-screenshot', string_type)
    end

    def string_type = GLib::VariantType.new('s')

    def open_uri(uri)
      Gtk::UriLauncher.new(uri).launch(application.active_window, nil) { |_source, _result| }
    end

    # Upstream only spawns the three tools it names, so a crafted target
    # cannot run anything else.
    def platform_tool(name)
      if PLATFORM_TOOLS.include?(name)
        Process.detach(Process.spawn(name, out: File::NULL, err: File::NULL))
      end
    rescue SystemCallError => error
      warn("#{name}: #{error.message}")
    end

    def new_project = open_session(Session.create)

    def open_project
      Gtk::FileDialog.new.then do |chooser|
        chooser.select_folder(application.active_window, nil) do |_source, result|
          chooser.select_folder_finish(result).then do |folder|
            if folder
              Session.add_to_recent_projects(folder.path, settings: app_settings)
              open_session(Session.new(folder.path))
            end
          end
        rescue StandardError
          # The chooser was dismissed.
          nil
        end
      end
    end

    # Ashpd::OpenUri.open talks to a real xdg-desktop-portal over D-Bus and
    # blocks the calling thread until the user answers any dialog it shows
    # (see the ashpd gem's own docs), so it runs off the main loop. Without a
    # running portal — true of a headless/sandbox-less dev shell — it raises
    #   RuntimeError: Portal request failed: org.freedesktop.zbus.Error: The name is not activatable
    # which falls back to Gtk::FileLauncher, the port's original stand-in.
    def show_screenshot(uri)
      Thread.new do
        Ashpd::OpenUri.open(uri, false, false)
      rescue StandardError => error
        warn("screenshot portal unavailable (#{error.message}), falling back to FileLauncher")
        GLib::Idle.add do
          Gtk::FileLauncher.new(Gio::File.new_for_uri(uri))
                           .open_containing_folder(application.active_window, nil) { |_s, _r| }
          false
        end
      end
    end
end
