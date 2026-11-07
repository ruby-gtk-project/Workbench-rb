# frozen_string_literal: true

require 'adwaita'

# ExtensionRow is one SDK extension's row in the Extensions dialog, ported
# from upstream's src/Extensions/Extension.js and
# src/Extensions/Extension.blp.
#
# Upstream is a Gtk.ListBoxRow with bindable "title", "available" and
# "command" properties; this port exposes the same three as plain writable
# attributes that push straight into the row's child widgets, since nothing
# else needs to observe them through GObject property bindings.
class ExtensionRow < Gtk::ListBoxRow
  def initialize(title: '', available: false, command: '')
    super()
    self.activatable = false
    self.child = content_box
    self.title = title
    self.available = available
    self.command = command
  end

  def title = @title

  def title=(value)
    @title = value
    label_title.label = value
  end

  def available = @available

  def available=(value)
    @available = value
    image_available.visible = value
    installation_guide.visible = !value
  end

  def command = @command

  def command=(value)
    @command = value
    label_command.label = value
  end

  private

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.append(header_box)
        box.append(installation_guide)
      end
    end

    def header_box
      @header_box ||= Gtk::CenterBox.new.tap do |center|
        center.height_request = 55
        center.valign = :center
        center.halign = :fill
        center.margin_start = 14
        center.margin_end = 14
        center.start_widget = label_title
        center.end_widget = image_available
      end
    end

    def label_title = @label_title ||= Gtk::Label.new

    def image_available
      @image_available ||= Gtk::Image.new(icon_name: 're.sonny.Workbench-test-pass-symbolic').tap do |image|
        image.add_css_class('success')
      end
    end

    def installation_guide
      @installation_guide ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.visible = false
        box.margin_start = 14
        box.margin_end = 14
        box.margin_bottom = 14
        box.append(installation_guide_label)
        box.append(label_command)
      end
    end

    def installation_guide_label
      @installation_guide_label ||= Gtk::Label.new('Run the following command').tap do |label|
        label.wrap = true
        label.xalign = 0
        label.add_css_class('dim-label')
      end
    end

    def label_command
      @label_command ||= Gtk::Label.new.tap do |label|
        label.margin_top = 12
        label.use_markup = true
        label.wrap = true
        label.wrap_mode = :word_char
        label.selectable = true
        label.xalign = 0
        label.add_css_class('command_snippet')
      end
    end
end
