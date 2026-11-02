# frozen_string_literal: true

require 'adwaita'

# ShortcutsWindow lists every accelerator the app binds, ported from upstream's
# src/shortcutsWindow.blp and src/shortcutsWindow.js.
#
# Upstream builds a Gtk.ShortcutsWindow with one section and three groups:
# Application, Editor and Console. Gtk::ShortcutsWindow cannot be constructed
# through the Ruby bindings — `GtkWindow is not subtype of GtkShortcutsWindow`
# — and the widget is deprecated in favour of Adw.ShortcutsDialog, so the port
# uses that: upstream's three groups become three Adw.ShortcutsSections, with
# the same titles, items and accelerators in the same order.
#
# Like upstream, the window is built once and reused, and `app.shortcuts` is
# the action that presents it.
class ShortcutsWindow
  ACTION = 'shortcuts'
  ACCELERATORS = ['<Control>question'].freeze

  SECTIONS = {
    'Application' => [
      ['Run Code', '<Control>Return'],
      ['Format', '<Control><Shift>Return'],
      ['New Project', '<Control>N'],
      ['Open Project', '<Control>O'],
      ['Open Library', '<Control><Shift>O'],
      ['Inspector', '<Control><Shift>I'],
      ['Close Window', '<Control>W'],
      ['Reveal in Files', '<Control>M'],
      ['Keyboard Shortcuts', '<Control>question'],
      ['Quit', '<Control>Q'],
    ],
    'Editor'      => [
      ['Cut', '<Control>X'],
      ['Copy', '<Control>C'],
      ['Paste', '<Control>V'],
      ['Find', '<Control>F'],
      ['Undo', '<Control>Z'],
      ['Show code suggestions', '<Control>space'],
      ['Redo', '<Control><Shift>Z'],
    ],
    'Console'     => [
      ['Toggle Console', '<Control><Shift>K'],
      ['Copy', '<Control><Shift>C'],
      ['Select All', '<Control><Shift>A'],
      ['Clear', '<Control>K'],
    ],
  }.freeze

  def initialize(application)
    @application = application
  end

  attr_reader :application

  def build
    application.tap do |app|
      app.add_action(action)
      app.set_accels_for_action("app.#{ACTION}", ACCELERATORS)

      action.signal_connect('activate') { present }
    end
  end

  def present = dialog.present(application.active_window)

  def dialog
    @dialog ||= Adwaita::ShortcutsDialog.new.tap do |shortcuts|
      shortcuts.title = 'Keyboard Shortcuts'
      SECTIONS.each { |title, items| shortcuts.add(section(title, items)) }
    end
  end

  private

    def action = @action ||= Gio::SimpleAction.new(ACTION)

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |shortcuts_section|
        shortcuts_section.title = title
        items.each { |label, accelerator| shortcuts_section.add(item(label, accelerator)) }
      end
    end

    # Positional, not keyword, arguments — the signatures the bindings
    # advertise are `title:` and `accelerator:`, but only positional works.
    def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
end
