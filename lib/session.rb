# frozen_string_literal: true

require 'fileutils'
require 'gtk4'

require_relative 'settings'
require_relative 'language'

# Session is a directory holding one Workbench project, ported from upstream's
# src/sessions.js.
#
# A session lives either under the data directory, in which case it is a
# scratch session Workbench owns and may delete, or anywhere else on disk, in
# which case it is a project the user saved and Workbench only remembers in the
# `recent-projects` application setting.
#
# Upstream loads a session's `icons/` directory by compiling it into a
# GResource with glib-compile-resources and registering the result. The port
# adds the directory to the icon theme's search path instead: the same icon
# names resolve, with no compiler to shell out to and no resource to unregister.
class Session
  class << self
    def data_dir
      File.join(
        ENV['XDG_DATA_HOME'] || File.join(Dir.home, '.local', 'share'),
        'Workbench',
      )
    end

    def sessions_dir = File.join(data_dir, 'sessions')

    # Upstream's getSessions(): every directory under sessions_dir, plus every
    # still-existing path in `recent-projects`. A recorded project that has
    # gone away is dropped from the setting.
    def all(settings: Settings.app)
      {}.tap do |files|
        FileUtils.mkdir_p(sessions_dir)
        Dir.children(sessions_dir).sort.each do |name|
          File.join(sessions_dir, name).then do |path|
            if File.directory?(path) && !name.start_with?('.')
              files[path] = path
            end
          end
        end

        settings.get_strv('recent-projects').each do |path|
          if File.directory?(path)
            files[path] = path
          else
            remove_from_recent_projects(path, settings: settings)
          end
        end
      end.keys.map { |path| new(path) }
    end

    # Upstream's createSession(): a directory named for the current time.
    def create
      File.join(sessions_dir, now_for_filename).then do |path|
        FileUtils.mkdir_p(path)
        new(path)
      end
    end

    # Upstream's createSessionFromDemo(): copy the demo's directory into a new
    # session, then record which panels the demo wants shown and which code
    # language it is written in.
    def create_from_demo(directory, name:, panels:, settings: Settings.app)
      create.tap do |session|
        FileUtils.cp_r(File.join(directory, '.'), session.directory)
        session.settings.delay
        session.settings.set_string('name', name)
        session.settings.set_boolean('show-code', panels.include?('code'))
        session.settings.set_boolean('show-style', panels.include?('style'))
        session.settings.set_boolean('show-ui', panels.include?('ui'))
        session.settings.set_boolean('show-preview', panels.include?('preview'))
        session.settings.set_int('code-language', settings.get_int('recent-code-language'))
        session.settings.apply
        session.create_session_files
      end
    end

    def add_to_recent_projects(path, settings: Settings.app)
      settings.set_strv('recent-projects', settings.get_strv('recent-projects') | [path])
    end

    def remove_from_recent_projects(path, settings: Settings.app)
      settings.set_strv('recent-projects', settings.get_strv('recent-projects') - [path])
    end

    # Upstream's getNowForFilename().
    def now_for_filename = Time.now.strftime('%Y-%m-%d %H-%M-%S')
  end

  # The README every session and saved project carries, copied verbatim from
  # upstream's src/project-readme.md.
  README = <<~MARKDOWN
    This is a Workbench project.

    To open and run this; [install Workbench from Flathub](https://flathub.org/apps/re.sonny.Workbench) and open this project folder with it.

    ## Icons

    You can embed icons into your project by adding them to the [`./icons`](./icons/) subfolder.

    Then you can reference them by name in UI. For example

    ```
    # Given a file icons/moon-symbolic.svg
    Gtk.Image {
      icon-name: "moon-symbolic";
    }
    ```

    Press "Run" if your icon is not detected yet.

    Please refer to Workbench Library entry "Using Icons" for more information.
  MARKDOWN

  def initialize(directory)
    @directory = File.expand_path(directory)
    @id = format('%016x', rand(1 << 64))
    @icons_loaded = false
  end

  attr_reader :directory, :id

  def settings = @settings ||= Settings.for_session(directory)

  def file(name) = File.join(directory, name)

  # The file a language's document is stored in.
  def file_for(language) = file(language.default_file)

  def icons_dir = file('icons')

  def load = load_icons

  def unload = unload_icons

  def load_icons
    icon_theme.then do |theme|
      if theme && File.directory?(icons_dir) && !@icons_loaded
        theme.add_search_path(icons_dir)
        @icons_loaded = true
      end
    end
    self
  end

  def unload_icons
    # Gtk::IconTheme has no remove_search_path; the paths are rewritten without
    # this session's, which is how the next session's icons take over.
    icon_theme.then do |theme|
      if theme && @icons_loaded
        theme.search_path = theme.search_path - [icons_dir]
        @icons_loaded = false
      end
    end
    self
  end

  def name
    settings.get_string('name').then do |stored|
      stored.empty? ? File.basename(directory) : stored
    end
  end

  # A session the user saved lives outside the sessions directory.
  def project? = File.dirname(directory) != File.expand_path(self.class.sessions_dir)

  def code_language = Language.by_index(settings.get_int('code-language'))

  def ui_language = Language[settings.get_string('user-interface-language')]

  def delete = FileUtils.rm_rf(directory)

  # Upstream's saveSessionAsProject(): the session's contents move to the
  # chosen directory under the chosen name, and the scratch session goes away.
  def save_as_project(destination)
    settings.set_string('name', File.basename(destination))
    FileUtils.mkdir_p(destination)
    FileUtils.cp_r(File.join(directory, '.'), destination)
    self.class.new(destination).tap do |project|
      project.create_session_files
      delete
    end
  end

  # Upstream's createSessionFiles(): an icons directory and a README.
  def create_session_files
    FileUtils.mkdir_p(icons_dir)
    File.write(file('README.md'), README)
    self
  end

  private

    def icon_theme
      Gdk::Display.default.then do |display|
        display && Gtk::IconTheme.get_for_display(display)
      end
    end
end
