# frozen_string_literal: true

# Drives a window on a throwaway session: opens it, edits the interface, and
# reports what the preview, the documents and the console ended up holding.
#
#   nix develop --command xvfb-run -a ruby test/drive_window.rb
#
# Nothing here asserts; the point is to see the real widgets react on a machine
# with no display, which is how the port is checked by hand.

require 'fileutils'
require 'tmpdir'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

Dir.mktmpdir('workbench-drive').then do |home|
  ENV['XDG_DATA_HOME'] = File.join(home, 'data')
  ENV['XDG_CONFIG_HOME'] = File.join(home, 'config')

  require 'workbench'

  INTERFACE = <<~XML
    <?xml version="1.0" encoding="UTF-8"?>
    <interface>
      <object class="GtkBox" id="root">
        <property name="orientation">vertical</property>
        <child>
          <object class="GtkLabel">
            <property name="label">Hello from the drive script</property>
          </object>
        </child>
      </object>
    </interface>
  XML

  STYLESHEET = "label { font-weight: bold; }\n"

  Session.create.then do |session|
    File.write(session.file('main.ui'), INTERFACE)
    File.write(session.file('main.css'), STYLESHEET)

    Gtk::Application.new('org.rubygtkproject.Workbench.Drive', :default_flags).then do |app|
      app.signal_connect('startup') do
        Adwaita.init
        Style.install
      end

      app.signal_connect('activate') do
        Actions.new(application: app).then do |actions|
          actions.build
          actions.open_session(session).then do |window|
            GLib::Timeout.add(800) do
              puts "title:          #{window.window.title}"
              puts "panels:         code=#{window.panel_code.panel.visible?} " \
                   "style=#{window.panel_style.panel.visible?} " \
                   "ui=#{window.panel_ui.panel.visible?} " \
                   "preview=#{window.panel_preview.panel.visible?}"
              puts "code language:  #{window.panel_code.language}"
              puts "ui document:    #{window.documents['xml'].buffer.text.lines.size} lines"
              puts "preview:        #{window.panel_preview.output.child.class}"
              puts "preview state:  #{window.panel_preview.stack.visible_child_name}"

              window.code_views['xml'].replace_text(
                '<?xml version="1.0" encoding="UTF-8"?><interface>' \
                '<object class="GtkButton" id="b">' \
                '<property name="label">Edited</property></object></interface>',
              )

              GLib::Timeout.add(300) do
                puts "after edit:     #{window.panel_preview.output.child.class}"
                puts "saved to disk:  #{File.read(session.file('main.ui')).include?('GtkButton')}"
                window.run
                puts "after run:      #{window.panel_preview.output.child.class}"
                session.delete
                app.quit
                GLib::Source::REMOVE
              end

              GLib::Source::REMOVE
            end
          end
        end
      end

      app.run([])
    end
  end

  FileUtils.rm_rf(home)
end
