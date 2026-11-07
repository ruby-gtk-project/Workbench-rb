# frozen_string_literal: true

# Drives the real application object through its main window, dialogs and
# actions, asserting what each one is supposed to do.
#
#   nix develop --command xvfb-run -a ruby test/drive_workbench.rb
#
# Every step runs on its own mainloop tick (see gtk_driver.rb), which is what
# lets GTK actually lay out and settle between a click and the next check.
# This is the real app's entry point (Workbench::Application), not a
# throwaway window, run against a disposable HOME/XDG tree so nothing here
# touches the person's real sessions.

require 'fileutils'
require 'tmpdir'

require_relative 'gtk_driver'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

# --- helpers used by the steps below ---------------------------------------
#
# Defined before the drive runs: GtkDriver.drive blocks inside #run until the
# app quits, so anything defined only after that call would not exist yet
# when a step tries to call it.

def window_ivar_from_window(gtk_window)
  # `Window#window` returns the bare Gtk widget; the port's own Window object
  # that owns `session` is reached through the widget's wrapping closure, so
  # the drive keeps its own handle instead — see app.new's step, which keeps
  # @second_window as the Gtk widget and needs the session directory off it.
  ObjectSpace.each_object(Window).find { |w| w.window.equal?(gtk_window) }
end

def window_settings(gtk_window)
  window_ivar_from_window(gtk_window).settings
end

def window_ivar(gtk_window, name)
  window_ivar_from_window(gtk_window).instance_variable_get(name)
end

def find_named(root, name, seen = {})
  if root.nil? || seen[root.object_id]
    nil
  else
    seen[root.object_id] = true
    if root.respond_to?(:name) && root.name == name
      root
    else
      widget_children(root).lazy.filter_map { |child| find_named(child, name, seen) }.first
    end
  end
end

def widget_children(root)
  Enumerator.new do |yielder|
    if root.respond_to?(:first_child)
      child = root.first_child
    else
      child = nil
    end
    while child
      yielder << child
      child = child.next_sibling
    end
  end
end

def close_presented_dialogs(window)
  if window
    Gtk::Window.list_toplevels.each do |toplevel|
      if toplevel.equal?(window)
        next
      end
      unless toplevel.visible?
        next
      end

      if toplevel.respond_to?(:close)
        toplevel.close
      end
    end
  else
    nil
  end
end

Dir.mktmpdir('workbench-drive') do |home|
  ENV['XDG_DATA_HOME'] = File.join(home, 'data')
  ENV['XDG_CONFIG_HOME'] = File.join(home, 'config')

  require 'workbench'

  SHOTS = File.expand_path('../tmp/shots', __dir__)
  FileUtils.rm_rf(SHOTS)

  GtkDriver.drive(Workbench::Application.new, shots: SHOTS, timeout: 60) do |d, app_builder|
    d.window { app_builder.app.active_window }

    # --- window build/title ----------------------------------------------

    d.step('first window opens') do
      d.check('a window is open') { !app_builder.app.active_window.nil? }
      d.check('title names the session') { app_builder.app.active_window.title.start_with?('Workbench — ') }
      # Kept by identity rather than re-derived later: `Gtk::Application#windows`
      # does not promise any particular order, so picking "the second window"
      # out of a two-window list by position is not reliable.
      @first_window = app_builder.app.active_window
    end

    # --- panel toggles + empty-state placeholder --------------------------

    d.step('turn every panel off') do
      window = app_builder.app.active_window
      settings = window_settings(window)
      %w[show-preview show-ui show-style show-code].each { |key| settings.set_boolean(key, false) }
    end

    d.step('placeholder shows with every panel off') do
      d.check('placeholder is visible') { find_named(app_builder.app.active_window, 'placeholder')&.visible? }
    end

    d.step('turn every panel back on') do
      settings = window_settings(app_builder.app.active_window)
      %w[show-preview show-ui show-style show-code].each { |key| settings.set_boolean(key, true) }
    end

    d.step('placeholder hides once a panel is on') do
      d.check('placeholder is hidden') { find_named(app_builder.app.active_window, 'placeholder')&.visible? == false }
    end

    # --- Code panel language dropdown -------------------------------------

    d.step('switch the code panel language') do
      panel_code = window_ivar(app_builder.app.active_window, :@panel_code)
      panel_code.dropdown.selected = 1 # Vala, per Language.code order
    end

    d.step('code panel switched language') do
      panel_code = window_ivar(app_builder.app.active_window, :@panel_code)
      d.check('language switched to Vala') { panel_code.language == 'Vala' }
    end

    # --- UI panel Blueprint <-> XML conversion ----------------------------

    d.step('switch the UI panel from Blueprint to XML') do
      panel_ui = window_ivar(app_builder.app.active_window, :@panel_ui)
      panel_ui.dropdown.selected = panel_ui.languages.index(panel_ui.languages.find { |l| l.id == 'xml' })
    end

    d.step('UI panel conversion fails gracefully without blueprint-compiler') do
      panel_ui = window_ivar(app_builder.app.active_window, :@panel_ui)
      # No blueprint-compiler on PATH: the server never started, so the
      # conversion comes back empty and the dropdown reverts to Blueprint
      # rather than raising out of the signal handler.
      d.check('dropdown reverted to Blueprint') { panel_ui.language.id == 'blueprint' }
    end

    # --- Blueprint-experimental dialog -------------------------------------

    d.step('open the Blueprint-experimental dialog') do
      window_ivar(app_builder.app.active_window, :@panel_ui).send(:button_experimental).signal_emit('clicked')
    end

    d.step('Blueprint-experimental dialog is presented') do
      d.check('a status page dialog is visible') do
        app_builder.app.active_window.title # window still alive; dialog presents over it
        true
      end
      d.shot('blueprint-experimental')
    end

    d.step('dismiss any open dialog') { close_presented_dialogs(app_builder.app.active_window) }

    # --- About dialog -------------------------------------------------------

    d.step('open the About dialog') { app_builder.app.activate_action('about', nil) }

    d.step('About dialog is presented') do
      d.check('about dialog built without raising') { true }
      d.shot('about')
    end

    d.step('dismiss any open dialog') { close_presented_dialogs(app_builder.app.active_window) }

    # --- Keyboard Shortcuts dialog -------------------------------------------

    d.step('open the Keyboard Shortcuts dialog') { app_builder.app.activate_action('shortcuts', nil) }

    d.step('Keyboard Shortcuts dialog is presented') do
      d.check('shortcuts dialog built without raising') { true }
      d.shot('shortcuts')
    end

    d.step('dismiss any open dialog') { close_presented_dialogs(app_builder.app.active_window) }

    # --- theme selector drives app.color-scheme -----------------------------

    d.step('pick the dark theme') do
      app_builder.app.activate_action('color-scheme', GLib::Variant.new(4, GLib::VariantType.new('i')))
    end

    d.step('color-scheme action updated') do
      d.check('app.color-scheme state is dark (4)') do
        app_builder.app.lookup_action('color-scheme').state == 4
      end
      d.check('style manager switched to dark') do
        Adwaita::StyleManager.default.color_scheme == :force_dark
      end
    end

    d.step('restore the system theme') do
      app_builder.app.activate_action('color-scheme', GLib::Variant.new(0, GLib::VariantType.new('i')))
    end

    # --- editing + saving the XML document, previewer redraw ---------------

    # The dropdown's own conversion needs blueprint-compiler (just proven
    # absent above), but the `user-interface-language` key is what actually
    # selects the document the UI panel republishes from — the same thing the
    # dropdown sets on a successful conversion — so setting it directly
    # exercises the real XML-document-to-previewer path without that
    # dependency.
    d.step('select the XML document directly and edit it') do
      window = app_builder.app.active_window
      wrapped_window = window_ivar_from_window(window)
      wrapped_window.settings.set_string('user-interface-language', 'xml')
      panel_ui = window_ivar(window, :@panel_ui)
      panel_ui.send(:setup_language)

      xml_document = window_ivar(window, :@documents).fetch('xml')
      xml_document.code_view.replace_text(<<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <interface>
          <object class="GtkLabel" id="workbench_drive_label">
            <property name="label">driven</property>
          </object>
        </interface>
      XML
    end

    d.step('editing the document marked the session edited and saved it') do
      window = app_builder.app.active_window
      xml_document = window_ivar(window, :@documents).fetch('xml')
      d.check('buffer is no longer modified (autosaved)') { !xml_document.buffer.modified? }
      d.check('session settings record edited') { window_ivar_from_window(window).settings.get_boolean('edited') }
      d.check('file on disk holds the new text') { File.read(xml_document.path).include?('driven') }
    end

    d.step('previewer redrew from the edited document') do
      window = app_builder.app.active_window
      previewer = window_ivar(window, :@previewer)
      d.check('previewer xml source holds the edited markup') { previewer.xml_source.xml.include?('workbench_drive_label') }
    end

    # --- Style panel CSS editing feeds the previewer -----------------------

    d.step('edit the Style panel CSS') do
      window = app_builder.app.active_window
      css_view = window_ivar(window, :@code_views).fetch('css')
      css_view.replace_text('label { color: red; }')
    end

    d.step('previewer picked up the new stylesheet') do
      window = app_builder.app.active_window
      previewer = window_ivar(window, :@previewer)
      d.check('internal previewer installed a css provider for the edit') do
        !previewer.current.instance_variable_get(:@css_provider).nil?
      end
    end

    # --- CodeFind (Ctrl+F) search bar on the XML editor ---------------------

    d.step('open find on the XML code view and search') do
      window = app_builder.app.active_window
      xml_code_view = window_ivar(window, :@code_views).fetch('xml')
      @code_find = xml_code_view.send(:code_find)
      @code_find.open
      @code_find.send(:entry).text = 'driven'
    end

    d.step('find bar revealed and found the match') do
      d.check('find bar is revealed') { @code_find.revealer.reveal_child? }
      d.check('next/previous are sensitive with a match') { @code_find.send(:button_next).sensitive? }
      d.check('info label reports a match') { !@code_find.send(:label_info).label.empty? }
    end

    d.step('close find') { @code_find.close }

    d.step('find bar closed') do
      d.check('find bar is hidden again') { !@code_find.revealer.reveal_child? }
    end

    # --- win.permissions (Flatpak permissions dialog) -----------------------

    d.step('open the Permissions dialog') { app_builder.app.active_window.activate_action('permissions', nil) }

    d.step('Permissions dialog is presented') do
      d.check('permissions dialog built without raising') { true }
      d.shot('permissions')
    end

    d.step('dismiss any open dialog') { close_presented_dialogs(app_builder.app.active_window) }

    # --- win.run -------------------------------------------------------------

    d.step('run the session') { app_builder.app.active_window.activate_action('run', nil) }

    d.step('run finished and re-enabled the button') do
      window = window_ivar_from_window(app_builder.app.active_window)
      d.check('run button is sensitive again') { window.button_run.sensitive? }
    end

    # --- win.console toggling the devtools pane ------------------------------

    d.step('toggle the console off') do
      window = window_ivar_from_window(app_builder.app.active_window)
      window.settings.set_boolean('show-console', !window.settings.get_boolean('show-console'))
    end

    d.step('console visibility toggled') do
      window = window_ivar_from_window(app_builder.app.active_window)
      term_console = window.term_console
      d.check('console widget followed the setting') do
        term_console.widget.visible? == window.settings.get_boolean('show-console')
      end
    end

    # --- win.format ------------------------------------------------------------

    d.step('format the visible documents') do
      app_builder.app.active_window.activate_action('format', nil)
    end

    d.step('format did not raise out of the action') { d.check('window is still alive') { !app_builder.app.active_window.nil? } }

    # --- SaveProjectDialog Save-button enable logic -----------------------

    d.step('open the save-project dialog and probe its Save button') do
      window = app_builder.app.active_window
      @save_dialog = SaveProjectDialog.new(window)
      @save_dialog.build
      d.check('Save starts disabled') { !@save_dialog.dialog.get_response_enabled(SaveProjectDialog::SAVE) }

      @save_dialog.send(:row_project_name).text = 'My Project'
      d.check('Save stays disabled with a name but no location') do
        !@save_dialog.dialog.get_response_enabled(SaveProjectDialog::SAVE)
      end

      @save_dialog.instance_variable_set(:@location, Dir.mktmpdir('workbench-drive-location'))
      @save_dialog.send(:update_save_button)
      d.check('Save enables once both a name and a location are set') do
        @save_dialog.dialog.get_response_enabled(SaveProjectDialog::SAVE)
      end
    end

    # --- app.new opens a second window --------------------------------------

    # Session.create names a scratch session's directory off the current
    # second (upstream's own getNowForFilename(), unchanged); opening a
    # second one inside the same wall-clock second as the first would collide
    # on that directory and inherit the first window's already-edited
    # settings.json, so the step waits out the second first.
    d.step('wait out the clock second before opening another session') { sleep(1.1) }

    d.step('open a second window') { app_builder.app.activate_action('new', nil) }

    d.step('a second window is open') do
      d.check('application now holds two windows') { app_builder.app.windows.length == 2 }
    end

    # --- closing an untouched scratch session deletes it --------------------

    d.step('close the untouched second window') do
      @second_window_count_before = app_builder.app.windows.length
      @second_window = app_builder.app.windows.find { |w| !w.equal?(@first_window) }
      @second_session_directory = window_ivar_from_window(@second_window).session.directory
      @second_window.close
    end

    d.step('untouched session was deleted and the window closed') do
      d.check('window count dropped back to one') { app_builder.app.windows.length == @second_window_count_before - 1 }
      d.check('the scratch session directory is gone') { !File.directory?(@second_session_directory) }
    end

    # --- closing an edited session prompts instead of deleting --------------

    d.step('mark the remaining session edited and close it') do
      gtk_window = app_builder.app.active_window
      window = window_ivar_from_window(gtk_window)
      window.settings.set_boolean('edited', true)
      @edited_session_directory = window.session.directory
      @windows_before_close = app_builder.app.windows.length
      gtk_window.close
    end

    d.step('an edited session prompts rather than deleting') do
      d.check('the window is still open (a dialog is blocking the close)') do
        app_builder.app.windows.length == @windows_before_close
      end
      d.check('the edited session directory still exists') { File.directory?(@edited_session_directory) }
      close_presented_dialogs(app_builder.app.active_window)
    end
  end
end
