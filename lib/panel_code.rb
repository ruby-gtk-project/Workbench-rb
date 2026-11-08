# frozen_string_literal: true

require 'adwaita'

require_relative 'language'

# PanelCode is the code panel, ported from upstream's src/PanelCode.js and the
# `Adw.ToolbarView panel_code` definition in src/window.blp.
#
# The header carries the panel title and the document dropdown; the body is a
# stack with one editor per code language. The dropdown's selection is the
# session's `code-language` key, and choosing a language both switches the
# stack and records the choice in the application's `recent-code-language`, so
# the next new session opens in the same language.
#
# Upstream also scaffolds the chosen language's project on switch — a
# jsconfig.json for JavaScript, a Cargo.toml for Rust, a tsconfig.json for
# TypeScript — from src/langs/javascript/javascript.js and its siblings. Those
# modules are unported, so switching language here switches the editor and
# resets the previewer but writes no project files: a session's directory
# never gets the per-language scaffolding a real language server or compiler
# would need to resolve imports or build the project, on top of Window#run
# never invoking a compiler at all.
class PanelCode
  def initialize(settings:, app_settings:, button:, previewer:, code_views:, typescript: false)
    @settings = settings
    @app_settings = app_settings
    @button = button
    @previewer = previewer
    @code_views = code_views
    @typescript = typescript
  end

  attr_reader :settings, :app_settings, :button, :previewer, :code_views

  # The languages the dropdown offers: upstream appends TypeScript only when
  # the TypeScript extension is enabled.
  def languages
    Language.code.reject { |language| language.id == 'typescript' && !@typescript }
  end

  def build
    panel.tap do |view|
      view.add_top_bar(header)
      view.content = content

      header.start_widget = header_box

      header_box.tap do |box|
        box.append(title)
        box.append(spacer)
        box.append(dropdown)
      end

      content.tap do |box|
        box.append(separator)
        box.append(stack)

        stack.tap do |pages|
          languages.each do |language|
            pages.add_named(code_views.fetch(language.id).build, language.name)
          end
        end
      end

      settings.bind('show-code', button, 'active')
      button.bind_property(
        'active',
        panel,
        'visible',
        :sync_create,
      )

      settings.bind('code-language', dropdown, 'selected')
      dropdown.signal_connect('notify::selected-item') { switch_language }

      settings.on_change('code-language') do |value|
        app_settings.set_int('recent-code-language', value.to_i)
      end

      switch_language
    end
  end

  # The name of the language currently shown, as upstream's `panel.language`:
  # the dropdown's string, so "JavaScript" rather than "javascript".
  def language = dropdown.selected_item&.string || languages.first.name

  def code_view = code_views.fetch(language.downcase)

  def panel
    @panel ||= Adwaita::ToolbarView.new.tap do |view|
      view.name = 'panel_code'
    end
  end

  def dropdown
    @dropdown ||= Gtk::DropDown.new.tap do |drop|
      drop.model = Gtk::StringList.new(languages.map(&:name))
      drop.tooltip_text = 'Switch Document'
      # https://gitlab.gnome.org/GNOME/libadwaita/-/issues/746 — upstream's
      # makeDropdownFlat, which flattens the dropdown's own toggle button.
      drop.first_child.add_css_class('flat')
    end
  end

  private

    def switch_language
      stack.visible_child_name = language
      previewer.use_internal
    end

    def header
      @header ||= Gtk::CenterBox.new.tap do |box|
        box.add_css_class('toolbar')
        box.add_css_class('panel_header')
        box.height_request = 46
      end
    end

    def header_box = @header_box ||= Gtk::Box.new(:horizontal, 0)

    def title
      @title ||= Gtk::Label.new.tap do |label|
        label.label = '<b>Code</b>'
        label.use_markup = true
        label.add_css_class('dim-label')
      end
    end

    def spacer
      @spacer ||= Gtk::Separator.new(:horizontal).tap do |separator|
        separator.add_css_class('spacer')
      end
    end

    def content = @content ||= Gtk::Box.new(:vertical, 0)

    def separator = @separator ||= Gtk::Separator.new(:horizontal)

    def stack
      @stack ||= Gtk::Stack.new.tap do |pages|
        pages.hexpand = true
      end
    end
end
