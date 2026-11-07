# frozen_string_literal: true

require 'adwaita'

require_relative 'language'
require_relative 'settings'

# EntryRow is one demo's row in the Library window's list, ported from
# upstream's src/Library/EntryRow.js and src/Library/EntryRow.blp.
#
# `demo` is a parsed demo manifest hash (the same shape Library.rb reads out
# of the installed demo corpus's index.json): "name", "description" and
# "languages" (an array of Language ids) are the keys this row reads.
#
# Upstream fires a "triggered" GObject signal with either `null` (the row
# itself was activated) or the Language the clicked language pill names.
# The port has no GObject signal registry of its own, so the row takes the
# callback directly — `on_triggered` is called with `nil` on activation and
# with a Language on a pill click, exactly as upstream's handler receives it.
class EntryRow < Adwaita::ActionRow
  def initialize(demo, &on_triggered)
    super()
    @demo = demo
    @on_triggered = on_triggered
    build
  end

  attr_reader :demo

  def build
    self.activatable = true
    self.title = ''
    add_prefix(contents_box)
    add_suffix(next_image)
    signal_connect('activated') { @on_triggered&.call(nil) }
  end

  private

    def contents_box = @contents_box ||= Gtk::Box.new(:horizontal, 0).tap { |box| box.append(labels_box) }

    def labels_box
      @labels_box ||= Gtk::Box.new(:vertical, 3).tap do |box|
        box.margin_top = 6
        box.margin_bottom = 6
        box.append(title_label)
        box.append(description_label)
        box.append(languages_box)
      end
    end

    def title_label
      @title_label ||= Gtk::Label.new(demo['name']).tap do |label|
        label.xalign = 0
        label.wrap = true
        label.wrap_mode = :word_char
      end
    end

    def description_label
      @description_label ||= Gtk::Label.new(demo['description']).tap do |label|
        label.add_css_class('dim-label')
        label.add_css_class('caption')
        label.xalign = 0
        label.wrap = true
        label.wrap_mode = :word_char
      end
    end

    def languages_box
      @languages_box ||= Gtk::Box.new(:horizontal, 3).tap do |box|
        box.margin_top = 3
        Array(demo['languages']).each do |id|
          next if id == 'typescript' && !Settings.app.get_boolean('typescript')

          language = Language[id]
          box.append(language_tag(language)) if language
        end
      end
    end

    def language_tag(language)
      Gtk::Button.new.tap do |button|
        button.label = language.name
        button.valign = :center
        button.add_css_class('pill')
        button.add_css_class('small')
        button.signal_connect('clicked') { @on_triggered&.call(language) }
      end
    end

    def next_image
      @next_image ||= Gtk::Image.new(icon_name: 'go-next-symbolic').tap do |image|
        image.margin_start = 6
        image.hexpand = true
        image.halign = :end
      end
    end
end
