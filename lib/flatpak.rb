# frozen_string_literal: true

require 'glib2'

# Flatpak reads the sandbox's `/.flatpak-info` keyfile, ported from upstream's
# src/flatpak.js.
#
# Outside a Flatpak sandbox there is no such file, which upstream treats as
# "not running under Flatpak" rather than an error: `GLib::FileError::NOENT`
# is swallowed and `nil` returned, while any other failure is logged.
module Flatpak
  class << self
    # Loads and memoizes the `/.flatpak-info` keyfile, or `nil` when the app
    # is not running inside a Flatpak sandbox.
    def info
      return @info if defined?(@info)

      @info = begin
        GLib::KeyFile.new.tap { |key_file| key_file.load_from_file('/.flatpak-info', GLib::KeyFile::NONE) }
      rescue GLib::FileError => e
        warn "Flatpak.info: #{e.message}" unless e.code == GLib::FileError::NOENT
        nil
      end
    end

    # The sandboxed application's id, from the `[Application]` section.
    def id = info&.get_string('Application', 'name')

    # Whether this Flatpak runtime is new enough to support per-device input
    # overrides (flatpak/flatpak#5331, released in 1.15.6), comparing
    # dotted version numbers numerically segment by segment.
    def device_input_override_available?(flatpak_version = info&.get_string('Instance', 'flatpak-version'))
      return false unless flatpak_version

      compare_versions(flatpak_version, '1.15.6') >= 0
    end

    private

    def compare_versions(a, b)
      a_parts = a.split('.').map(&:to_i)
      b_parts = b.split('.').map(&:to_i)
      [a_parts.size, b_parts.size].max.times do |i|
        cmp = (a_parts[i] || 0) <=> (b_parts[i] || 0)
        return cmp unless cmp.zero?
      end
      0
    end
  end
end
