# frozen_string_literal: true

require 'adwaita'

# SaveProjectDialog asks what to do with an unsaved session when its window is
# closed, ported from the `Adw.AlertDialog alert_dialog_save_project` and
# `Button button_location` definitions in upstream's src/window.blp together
# with `promptSessionClose` in src/window.js.
#
# The three responses are upstream's: cancel, discard, and save — save stays
# insensitive until both a project name and a location have been chosen, which
# is what the name row's notify and the location button's folder chooser each
# re-check. The chosen destination is the named subdirectory of the chosen
# location, as upstream's `location.get_child_for_display_name(name)` is.
class SaveProjectDialog
  CANCEL = 'cancel'
  DISCARD = 'discard'
  SAVE = 'save'

  def initialize(window)
    @window = window
    @location = nil
  end

  attr_reader :window, :location

  def build
    dialog.tap do |d|
      d.extra_child = extra_child

      extra_child.tap do |box|
        box.append(name_list)
        box.append(location_box)

        name_list.append(row_project_name)
        row_project_name.signal_connect('notify::text') { update_save_button }

        location_box.tap do |inner|
          inner.append(location_list)
          inner.append(location_hint)

          location_list.append(row_project_location)
          row_project_location.tap do |row|
            row.add_suffix(button_location)
            row.activatable_widget = button_location
          end

          button_location.signal_connect('clicked') { select_location }
        end
      end
    end
  end

  # Presents the dialog and yields the response and, for a save, the directory
  # the project is to be created in.
  def choose(&block)
    build.choose(window, nil) do |_source, result|
      dialog.choose_finish(result).then do |response|
        block.call(response, destination)
      end
    end
    self
  end

  # `location/<name>` — the project is created in a new subdirectory, which is
  # what the hint under the location row promises.
  def destination
    if location && !row_project_name.text.empty?
      File.join(location, row_project_name.text)
    end
  end

  def dialog
    @dialog ||= Adwaita::AlertDialog.new.tap do |d|
      d.heading = 'Save Project?'
      d.body = 'This session has not been saved. Unsaved sessions will be permanently lost.'
      d.add_response(CANCEL, 'Cancel')
      d.add_response(DISCARD, 'Discard')
      d.add_response(SAVE, 'Save')
      d.set_response_appearance(DISCARD, :destructive)
      d.set_response_appearance(SAVE, :suggested)
      d.set_response_enabled(SAVE, false)
      d.close_response = CANCEL
    end
  end

  private

    def extra_child
      @extra_child ||= Gtk::Box.new(:vertical, 24).tap do |box|
        box.margin_top = 12
      end
    end

    def name_list
      @name_list ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class('boxed-list')
      end
    end

    def row_project_name
      @row_project_name ||= Adwaita::EntryRow.new.tap do |row|
        row.title = 'Project Name'
      end
    end

    def location_box = @location_box ||= Gtk::Box.new(:vertical, 0)

    def location_list
      @location_list ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class('boxed-list')
      end
    end

    def row_project_location
      @row_project_location ||= Adwaita::ActionRow.new.tap do |row|
        row.title = 'Location'
        row.subtitle = 'Select Location'
      end
    end

    def button_location
      @button_location ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'folder-symbolic'
        button.valign = :center
        button.add_css_class('flat')
      end
    end

    def location_hint
      @location_hint ||= Gtk::Label.new('The project will be created in a new subdirectory').tap do |label|
        label.margin_start = 12
        label.margin_top = 12
        label.halign = :start
        label.justify = :left
        label.add_css_class('dim-label')
        label.add_css_class('caption')
      end
    end

    def select_location
      Gtk::FileDialog.new.then do |chooser|
        chooser.select_folder(window, nil) do |_source, result|
          chooser.select_folder_finish(result).then do |folder|
            if folder
              @location = folder.path
              row_project_location.subtitle = File.basename(@location)
              update_save_button
            end
          end
        rescue StandardError
          # The chooser was dismissed; the location is left as it was.
          nil
        end
      end
    end

    def update_save_button
      dialog.set_response_enabled(SAVE, !destination.nil?)
    end
end
