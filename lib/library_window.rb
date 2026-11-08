# frozen_string_literal: true

require 'json'
require 'adwaita'

require_relative 'settings'
require_relative 'session'
require_relative 'language'
require_relative 'entry_row'

# LibraryWindow is the "Library" of demos and examples, ported from
# upstream's src/Library/Library.js and src/Library/Library.blp.
#
# Upstream reads its corpus out of `pkg.pkgdatadir/demos/index.json`, a tree
# Meson installs from the separate `demos/` source directory (an un-vendored
# git submodule pointing at workbenchdev/demos.git) at build time. This gem
# has no Meson install step, so `build-aux/vendor_demos.rb` — a Ruby port of
# upstream's own `build-aux/library.js` — does that job ahead of time against
# a checkout of that submodule, and its output is committed at `data/demos`,
# next to the gemspec's own packaged `data/**/*` files. `demos_dir` points
# there. An absent or unparsable index is still read as "no demos" rather
# than an error, exactly as an empty search result renders here, which only
# matters now for a checkout that deleted `data/demos` by hand.
#
# Opening a demo hands off to Window the same way upstream's openDemo does:
# copy the demo into a fresh session, record which panel/language it asks
# for, and present a Window on it. The one piece upstream's openDemo has that
# this port does not reach is permissions pre-flighting
# (needsAdditionalPermissions/showPermissionsDialog) — PermissionsDialog
# exists but is wired to a window that is already open, not to gate opening
# one, so a demo that needs Flatpak permissions it does not have opens
# unconditionally rather than detouring to that dialog first.
class LibraryWindow
  CATEGORIES = [
    ['all', 'Any Category'],
    ['tools', 'Tools'],
    ['network', 'Network'],
    ['controls', 'Controls'],
    ['layout', 'Layout'],
    ['feedback', 'Feedback'],
    ['navigation', 'Navigation'],
    ['user_interface', 'User Interface'],
    ['platform', 'Platform APIs'],
  ].freeze

  BASE_LANGUAGES = [
    ['all', 'Any Language'],
    ['javascript', 'JavaScript'],
    ['python', 'Python'],
    ['rust', 'Rust'],
    ['vala', 'Vala'],
  ].freeze

  def self.demos_dir = File.expand_path('../data/demos', __dir__)

  def self.demos
    @demos ||= begin
      index = File.join(demos_dir, 'index.json')
      File.exist?(index) ? JSON.parse(File.read(index)) : []
    rescue JSON::ParserError, SystemCallError
      []
    end
  end

  def self.demo(name) = demos.find { |demo| demo['name'] == name }

  # `open_session` is called with a Session once a demo has been copied into
  # one — upstream's own Window({ application, session }); the caller (Actions)
  # is what actually knows how to turn that into an open window.
  def initialize(application:, app_settings: Settings.app, &open_session)
    @application = application
    @app_settings = app_settings
    @open_session = open_session
    @last_triggered = nil
  end

  attr_reader :application, :app_settings

  def install_action
    application.add_action(action_library)
    application.set_accels_for_action('app.library', ['<Control><Shift>O'])
  end

  def build
    window.tap do
      reset
    end
  end

  private

    def languages
      @languages ||= app_settings.get_boolean('typescript') ? BASE_LANGUAGES + [%w[typescript TypeScript]] : BASE_LANGUAGES
    end

    def action_library
      @action_library ||= Gio::SimpleAction.new('library').tap do |action|
        action.signal_connect('activate') do
          build.present
          @last_triggered&.grab_focus
        end
      end
    end

    def window
      @window ||= Adwaita::Window.new.tap do |win|
        win.hide_on_close = true
        win.modal = false
        win.title = 'Workbench — Library'
        win.default_height = 700
        win.default_width = 700
        win.application = application
        win.content = toolbar_view
        win.signal_connect('close-request') { false }
      end
    end

    def toolbar_view
      @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
        view.add_top_bar(header_bar)
        view.content = scrolled_window
      end
    end

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.title_widget = Adwaita::WindowTitle.new('Workbench — Library', '')
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
        c.maximum_size = 576
        c.margin_start = 12
        c.margin_end = 12
        c.child = content
      end
    end

    def content
      @content ||= Gtk::Box.new(:vertical, 12).tap do |box|
        box.append(heading_box)
        box.append(listbox)
        box.append(footer_box)
      end
    end

    def heading_box
      @heading_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.append(illustration_box)
        box.append(heading_label)
        box.append(filters_box)
      end
    end

    def illustration_box
      @illustration_box ||= Gtk::Box.new(:horizontal, 0).tap do |box|
        box.halign = :center
        box.vexpand = false
        box.append(picture_illustration)
      end
    end

    def picture_illustration
      @picture_illustration ||= Gtk::Picture.new.tap do |picture|
        picture.can_shrink = false
        picture.margin_bottom = 32
        picture.margin_top = 24
      end
    end

    def heading_label
      @heading_label ||= Gtk::Label.new('Learn, Test, Remix').tap do |label|
        label.add_css_class('title-1')
      end
    end

    def filters_box
      @filters_box ||= Gtk::Box.new(:horizontal, 6).tap do |box|
        box.append(search_entry)
        box.append(dropdown_language)
        box.append(dropdown_category)
      end
    end

    def search_entry
      @search_entry ||= Gtk::SearchEntry.new.tap do |entry|
        entry.search_delay = 100
        entry.placeholder_text = 'Search demos'
        entry.activates_default = true
        entry.hexpand = true
        entry.margin_top = 32
        entry.signal_connect('search-changed') { update_list }
      end
    end

    def dropdown_language
      @dropdown_language ||= Gtk::DropDown.new(
        Gtk::StringList.new(languages.map { |_, name| name }), nil,
      ).tap do |dropdown|
        dropdown.valign = :end
        dropdown.signal_connect('notify::selected') { update_list }
      end
    end

    def dropdown_category
      @dropdown_category ||= Gtk::DropDown.new(
        Gtk::StringList.new(CATEGORIES.map { |_, name| name }), nil,
      ).tap do |dropdown|
        dropdown.valign = :end
        dropdown.signal_connect('notify::selected') { update_list }
      end
    end

    def listbox
      @listbox ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.add_css_class('boxed-list')
        entries.each { |entry| list.append(entry[:row]) }
      end
    end

    def footer_box
      @footer_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.halign = :center
        box.margin_bottom = 24
        box.margin_top = 12
        box.append(results_empty)
        box.append(license_label)
      end
    end

    def results_empty
      @results_empty ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.visible = false
        box.margin_top = 46
        box.margin_bottom = 70
        box.append(Gtk::Label.new('No results').tap { |label| label.add_css_class('title-3') })
        box.append(button_reset)
      end
    end

    def button_reset
      @button_reset ||= Gtk::Button.new.tap do |button|
        button.label = 'Reset filters'
        button.halign = :center
        button.add_css_class('pill')
        button.signal_connect('clicked') { reset }
      end
    end

    def license_label
      @license_label ||= Gtk::Label.new.tap do |label|
        label.use_markup = true
        label.label =
          'All examples are dedicated to the public domain and ' \
          '<b>can be used freely</b> under the terms of ' \
          '<a href="https://creativecommons.org/publicdomain/zero/1.0/">CC0 1.0</a>'
        label.add_css_class('caption')
      end
    end

    # One entry per demo: its manifest hash, the category it belongs to, the
    # Languages it lists, and the row widget filtering shows/hides.
    def entries
      @entries ||= self.class.demos.map do |demo|
        row = EntryRow.new(demo) do |language|
          @last_triggered = row
          open_demo(demo['name'], language)
        end
        @last_triggered = row if demo['name'] == 'Welcome'
        {
          demo:      demo,
          category:  demo['category'],
          languages: Array(demo['languages']),
          row:       row,
        }
      end
    end

    def update_list
      category = CATEGORIES[dropdown_category.selected]&.first || 'all'
      language = languages[dropdown_language.selected]&.first || 'all'
      term = search_entry.text.to_s.downcase
      results_found = false

      entries.each do |entry|
        category_match = category == 'all' || entry[:category] == category
        language_match = language == 'all' || entry[:languages].include?(language)
        search_match = term.empty? ||
          entry[:demo]['name'].to_s.downcase.include?(term) ||
          entry[:demo]['description'].to_s.downcase.include?(term)
        is_match = category_match && language_match && search_match
        entry[:row].visible = is_match
        results_found ||= is_match
      end

      results_empty.visible = !results_found
    end

    def reset
      scrolled_window.vadjustment = nil
      search_entry.text = ''
      dropdown_category.selected = 0
      dropdown_language.selected = 0
      update_list
    end

    def open_demo(demo_name, language)
      demo = self.class.demo(demo_name)
      return unless demo

      session = Session.create_from_demo(
        File.join(self.class.demos_dir, demo['name']),
        name:     demo['name'],
        panels:   Array(demo['panels']),
        settings: app_settings,
      )

      if language
        session.settings.set_int('code-language', language.index) if language.index
        app_settings.set_int('recent-code-language', language.index) if language.index
        session.settings.set_boolean('show-code', true)
      end

      @open_session&.call(session)
    end
end
