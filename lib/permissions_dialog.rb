# frozen_string_literal: true

require 'adwaita'

require_relative 'flatpak'

# PermissionsDialog explains the `flatpak override` command needed to grant
# Workbench extra sandbox access, ported from upstream's
# src/Permissions/Permissions.blp and src/Permissions/Permissions.js.
#
# It only applies when Workbench itself is running under Flatpak, so every
# check here goes through `Flatpak.info` and comes back falsy outside the
# sandbox. `needs_additional_permissions?(demo)` is upstream's gate: a demo
# without `flatpak-finish-args` never needs the dialog, and one that has them
# needs it only when the sandbox is missing network, pulseaudio or the device
# permission it asks for.
class PermissionsDialog
  PERMISSIONS_DOCS_URI = 'https://docs.flatpak.org/en/latest/sandbox-permissions.html'

  class << self
    # Whether the current Flatpak sandbox has a device override for input
    # devices (gamepads etc), falling back to granting every device.
    def device = Flatpak.device_input_override_available? ? 'input' : 'all'

    # Whether the sandbox already grants network access.
    def network_permission? = Array(Flatpak.info&.get_string_list('Context', 'shared')).include?('network')

    def missing_permissions?
      info = Flatpak.info
      return false unless info

      shared = Array(info.get_string_list('Context', 'shared'))
      sockets = Array(info.get_string_list('Context', 'sockets'))
      devices = Array(info.get_string_list('Context', 'devices'))
      !shared.include?('network') || !sockets.include?('pulseaudio') || !devices.include?(device)
    end

    # `demo` is a parsed demo manifest hash; upstream's key is
    # `flatpak-finish-args`.
    def needs_additional_permissions?(demo)
      demo['flatpak-finish-args'] && missing_permissions?
    end
  end

  def initialize(window)
    @window = window
  end

  attr_reader :window

  def install_action
    window.add_action(action_permissions)
  end

  def build
    dialog.tap do |d|
      d.child = toolbar_view
      label_command.label = command_text
      action_row_device.title = "--input=#{self.class.device}"
      button_info.signal_connect('clicked') do
        Gtk::UriLauncher.new(PERMISSIONS_DOCS_URI).launch(window, nil) { |_source, _result| }
      end
    end
  end

  private

    def action_permissions
      @action_permissions ||= Gio::SimpleAction.new('permissions').tap do |action|
        action.signal_connect('activate') { build.present(window) }
      end
    end

    def command_text
      "flatpak override --user --share=network --socket=pulseaudio --device=#{self.class.device} #{Flatpak.id}"
    end

    def dialog
      @dialog ||= Adwaita::Dialog.new.tap do |d|
        d.content_height = 750
        d.content_width = 600
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
        c.maximum_size = 520
        c.tightening_threshold = 400
        c.margin_start = 12
        c.margin_end = 12
        c.margin_bottom = 24
        c.child = content
      end
    end

    def content
      @content ||= Gtk::Box.new(:vertical, 24).tap do |box|
        box.halign = :fill
        box.append(illustration_box)
        box.append(heading_label)
        box.append(explanation_label)
        box.append(label_command)
        box.append(what_it_does_box)
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
        picture.margin_bottom = 24
      end
    end

    def heading_label
      @heading_label ||= Gtk::Label.new('Permissions Needed').tap do |label|
        label.add_css_class('title-1')
      end
    end

    def explanation_label
      @explanation_label ||= Gtk::Label.new(
        'Workbench needs additional permissions. Please run the following command in a terminal and ' \
        'restart Workbench.',
      ).tap do |label|
        label.wrap = true
        label.justify = :center
      end
    end

    def label_command
      @label_command ||= Gtk::Label.new.tap do |label|
        label.use_markup = true
        label.wrap = true
        label.wrap_mode = :word_char
        label.selectable = true
        label.xalign = 0
        label.add_css_class('command_snippet')
      end
    end

    def what_it_does_box
      @what_it_does_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.append(what_it_does_header)
        box.append(permissions_list)
      end
    end

    def what_it_does_header
      @what_it_does_header ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.margin_bottom = 6
        box.append(what_it_does_label)
        box.append(button_info)
      end
    end

    def what_it_does_label
      @what_it_does_label ||= Gtk::Label.new('What it does').tap do |label|
        label.halign = :start
        label.hexpand = true
        label.add_css_class('heading')
      end
    end

    def button_info
      @button_info ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'dialog-information-symbolic'
        button.add_css_class('flat')
      end
    end

    def permissions_list
      @permissions_list ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class('boxed-list')
        list.append(row_user)
        list.append(row_network)
        list.append(row_pulseaudio)
        list.append(action_row_device)
      end
    end

    def row_user
      @row_user ||= Adwaita::ActionRow.new.tap do |row|
        row.title = '--user'
        row.subtitle = 'Grant for your account only'
        row.add_css_class('property')
      end
    end

    def row_network
      @row_network ||= Adwaita::ActionRow.new.tap do |row|
        row.title = '--share-network'
        row.subtitle = 'Network access'
        row.add_css_class('property')
      end
    end

    def row_pulseaudio
      @row_pulseaudio ||= Adwaita::ActionRow.new.tap do |row|
        row.title = '--socket=pulseaudio'
        row.subtitle = 'Record and play audio'
        row.add_css_class('property')
      end
    end

    def action_row_device
      @action_row_device ||= Adwaita::ActionRow.new.tap do |row|
        row.subtitle = 'Access to input device such as gamepads'
        row.add_css_class('property')
      end
    end
end
