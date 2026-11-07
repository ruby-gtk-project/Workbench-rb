# frozen_string_literal: true

require 'adwaita'

require_relative 'settings'
require_relative 'flatpak'
require_relative 'extension_row'

# ExtensionsDialog explains the `flatpak install` commands needed for the
# optional Rust, Vala and TypeScript SDK extensions, ported from upstream's
# src/Extensions/Extensions.js and src/Extensions/Extensions.blp.
#
# Upstream reads the running Flatpak's own runtime version out of its
# `/.flatpak-info` to pick the extension branch (`"25.08"` either way, since
# upstream's own FIXME comment never finished reading it from the manifest);
# this port keeps that same constant rather than inventing a real manifest
# read upstream itself does not do. Availability is upstream's own check: a
# `/usr/lib/sdk/<extension>` directory existing inside the sandbox.
class ExtensionsDialog
  FREEDESKTOP_VERSION = '25.08'
  LLVM = 'llvm21'
  NODE = 'node24'

  def initialize(window)
    @window = window
  end

  attr_reader :window

  def install_action
    window.add_action(action_extensions)
  end

  def self.rust_available?
    return @rust_available if defined?(@rust_available)

    @rust_available = Gio::File.new_for_path('/usr/lib/sdk/rust-stable').query_exists(nil) &&
      Gio::File.new_for_path("/usr/lib/sdk/#{LLVM}").query_exists(nil)
  end

  def self.vala_available?
    return @vala_available if defined?(@vala_available)

    @vala_available = Gio::File.new_for_path('/usr/lib/sdk/vala').query_exists(nil)
  end

  def self.typescript_enabled? = Settings.app.get_boolean('typescript')

  def self.typescript_available?
    return @typescript_available if defined?(@typescript_available)

    @typescript_available = typescript_enabled? &&
      Gio::File.new_for_path('/usr/lib/sdk/typescript').query_exists(nil) &&
      Gio::File.new_for_path("/usr/lib/sdk/#{NODE}").query_exists(nil)
  end

  def build
    dialog.tap do
      extension_rust.available = self.class.rust_available?
      extension_rust.command =
        "flatpak install flathub org.freedesktop.Sdk.Extension.rust-stable//#{FREEDESKTOP_VERSION} " \
        "org.freedesktop.Sdk.Extension.#{LLVM}//#{FREEDESKTOP_VERSION}"

      extension_vala.available = self.class.vala_available?
      extension_vala.command =
        "flatpak install flathub org.freedesktop.Sdk.Extension.vala//#{FREEDESKTOP_VERSION}"

      extension_typescript.available = self.class.typescript_available?
      extension_typescript.command =
        "flatpak install flathub org.freedesktop.Sdk.Extension.#{NODE}//#{FREEDESKTOP_VERSION} " \
        "org.freedesktop.Sdk.Extension.typescript//#{FREEDESKTOP_VERSION}"
      extension_typescript.visible = self.class.typescript_enabled?

      all_set = [extension_rust, extension_vala, extension_typescript].all?(&:available)
      all_set_hint.visible = all_set
      restart_hint.visible = !all_set
    end
  end

  private

    def action_extensions
      @action_extensions ||= Gio::SimpleAction.new('extensions').tap do |action|
        action.signal_connect('activate') { build.present(window) }
      end
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |d|
        d.content_height = 750
        d.content_width = 600
        d.title = 'Extensions'
        d.child = toolbar_view
      end
    end

    def toolbar_view
      @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
        view.add_top_bar(Adwaita::HeaderBar.new)
        view.content = scrolled_window
      end
    end

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |scrolled|
        scrolled.hscrollbar_policy = :never
        scrolled.child = clamp
      end
    end

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |c|
        c.maximum_size = 600
        c.tightening_threshold = 400
        c.margin_start = 14
        c.margin_end = 14
        c.margin_top = 30
        c.margin_bottom = 30
        c.child = content
      end
    end

    def content
      @content ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.halign = :fill
        box.append(illustration_box)
        box.append(list_box)
        box.append(restart_hint)
        box.append(all_set_hint)
      end
    end

    def illustration_box
      @illustration_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.halign = :center
        box.append(picture_illustration)
      end
    end

    def picture_illustration
      @picture_illustration ||= Gtk::Picture.new.tap do |picture|
        picture.can_shrink = false
        picture.margin_bottom = 30
      end
    end

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class('boxed-list')
        list.append(ExtensionRow.new(title: 'JavaScript', available: true))
        list.append(ExtensionRow.new(title: 'Python', available: true))
        list.append(extension_rust)
        list.append(extension_vala)
        list.append(extension_typescript)
      end
    end

    def extension_rust = @extension_rust ||= ExtensionRow.new(title: 'Rust')
    def extension_vala = @extension_vala ||= ExtensionRow.new(title: 'Vala')
    def extension_typescript = @extension_typescript ||= ExtensionRow.new(title: 'TypeScript')

    def restart_hint
      @restart_hint ||= Gtk::Label.new(
        "To apply changes, restart Workbench once\nthe commands have completed",
      ).tap do |label|
        label.visible = false
        label.margin_top = 30
        label.justify = :center
        label.wrap = true
        label.add_css_class('dim-label')
      end
    end

    def all_set_hint
      @all_set_hint ||= Gtk::Label.new('You’re all set!').tap do |label|
        label.margin_top = 30
        label.justify = :center
        label.wrap = true
        label.add_css_class('dim-label')
      end
    end
end
