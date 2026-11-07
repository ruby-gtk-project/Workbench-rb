# frozen_string_literal: true

require 'glib2'

# LogHandler installs a `GLib::Log.set_handler` for each domain upstream
# filters, ported from upstream's src/log_handler.js.
#
# Upstream hooks `GLib.log_set_handler` per-domain (structured logging in Gjs
# makes a single global writer func unreliable) and prints every message it
# does not know to suppress, prefixed with the domain and a colour-coded
# level name. `GLib::Log.set_handler` is the same call in the Ruby bindings.
# A handler that recognises one of the known noisy messages returns without
# printing it; everything else is formatted and printed exactly as upstream
# does.
module LogHandler
  DOMAINS = %w[Gdk Adwaita GVFS Workbench].freeze

  LEVELS =
    GLib::Log::FLAG_FATAL |
    GLib::Log::FLAG_RECURSION |
    GLib::Log::LEVEL_CRITICAL |
    GLib::Log::LEVEL_DEBUG |
    GLib::Log::LEVEL_ERROR |
    GLib::Log::LEVEL_INFO |
    GLib::Log::LEVEL_MESSAGE |
    GLib::Log::LEVEL_WARNING

  # [domain, level, message] triples that upstream's handler swallows
  # outright instead of printing.
  SILENCED = [
    ['Gdk', GLib::Log::LEVEL_CRITICAL,
     "gdk_scroll_event_get_direction: assertion 'GDK_IS_EVENT_TYPE (event, GDK_SCROLL)' failed"],
    ['Gdk', GLib::Log::LEVEL_CRITICAL,
     "gdk_scroll_event_get_direction: assertion 'GDK_IS_EVENT (event)' failed"],
    ['Gtk', GLib::Log::LEVEL_CRITICAL,
     "Unable to connect to the accessibility bus at 'unix:path=/run/flatpak/at-spi-bus': " \
     'Could not connect: No such file or directory'],
    ['Adwaita', GLib::Log::LEVEL_WARNING,
     'Using GtkSettings:gtk-application-prefer-dark-theme with libadwaita is unsupported. ' \
     'Please use AdwStyleManager:color-scheme instead.'],
    ['GVFS', GLib::Log::LEVEL_WARNING,
     'The peer-to-peer connection failed: Error when getting information for file ' \
     '“/run/user/1000/gvfsd”: No such file or directory. Falling back to the session bus. ' \
     'Your application is probably missing --filesystem=xdg-run/gvfsd privileges.'],
  ].freeze

  LEVEL_NAMES = {
    GLib::Log::FLAG_RECURSION => "\e[1;31mRecursion\e[0m",
    GLib::Log::FLAG_FATAL => "\e[1;31mFatal\e[0m",
    GLib::Log::LEVEL_CRITICAL => "\e[1;35mCritical\e[0m",
    GLib::Log::LEVEL_ERROR => "\e[1;31mError\e[0m",
    GLib::Log::LEVEL_WARNING => "\e[1;33mWarning\e[0m",
  }.freeze

  class << self
    def install
      DOMAINS.each { |domain| GLib::Log.set_handler(domain, LEVELS) { |d, level, message| handle(d, level, message) } }
    end

    private

    def handle(domain, level, message)
      return if SILENCED.any? { |d, l, m| d == domain && l == level && m == message }

      print(format_message(domain, level, message))
    end

    def format_message(domain, level, message)
      prefix = domain == 'Gjs' ? '' : "#{domain}-"
      level_name = LEVEL_NAMES[level]
      "\n#{prefix}#{level_name ? "#{level_name}: " : ''}#{message}\n"
    end
  end
end
