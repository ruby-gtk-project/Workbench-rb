# frozen_string_literal: true

require 'adwaita'

require_relative 'language'
require_relative 'blueprint_experimental_dialog'

# PanelUI is the user-interface panel, ported from upstream's src/PanelUI.js
# and the `Adw.ToolbarView panel_ui` definition in src/window.blp.
#
# It is the panel the previewer reads from: whichever of its two documents is
# selected, the panel turns it into GTK Builder XML and notifies its listeners,
# which is how a keystroke in the editor becomes a redrawn preview.
#
# Upstream offers two syntaxes for the same document, Blueprint and XML, and
# converts between them through the blueprint-compiler language server —
# `textDocument/x-blueprint-compile` one way, `x-blueprint/decompile` the
# other. The port has no language-server client yet, so the panel is
# constructed with the documents it can actually drive: the dropdown lists
# those, and `user-interface-language` is held to one of them. Pass a document
# for `blueprint` once lib/lsp_client.rb exists and the second page, the
# conversions and the experimental-syntax button all come back on.
class PanelUI
  def initialize(settings:, button:, application:, term_console:, documents:)
    @settings = settings
    @button = button
    @application = application
    @term_console = term_console
    @documents = documents
    @xml = ''
    @updated_callbacks = []
    @handlers = {}
  end

  attr_reader :settings, :button, :application, :term_console, :documents, :xml

  def languages = Language.ui.select { |language| documents.key?(language.id) }

  # The language the panel is currently showing. A stored language the port
  # cannot drive falls back to the first it can.
  def language
    languages.find { |candidate| candidate.id == settings.get_string('user-interface-language') } ||
      languages.first
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
        box.append(button_experimental)

        button_experimental.signal_connect('clicked') do
          BlueprintExperimentalDialog.new(application.active_window).present
        end
      end

      content.tap do |box|
        box.append(separator)
        box.append(stack)

        stack.tap do |pages|
          languages.each do |candidate|
            pages.add_named(documents.fetch(candidate.id).code_view.build, candidate.id)
          end
        end
      end

      settings.bind('show-ui', button, 'active')
      button.bind_property(
        'active',
        panel,
        'visible',
        :sync_create,
      )

      dropdown.selected = languages.index(language)
      dropdown.signal_connect('notify::selected') { change_language(languages[dropdown.selected]) }

      setup_language
    end
  end

  # Upstream's panel.connect("updated"): the previewer's cue to redraw.
  def on_updated(&block)
    @updated_callbacks << block
    block
  end

  def off_updated(block) = @updated_callbacks.delete(block)

  # While started, each edit of the selected document republishes the XML.
  def start
    stop
    languages.each do |candidate|
      documents.fetch(candidate.id).code_view.then do |code_view|
        @handlers[candidate.id] = code_view.on_changed do
          if candidate == language
            publish(xml_for(candidate))
          end
        end
      end
    end
    self
  end

  def stop
    @handlers.each do |id, handler|
      documents.fetch(id).code_view.off_changed(handler)
    end
    @handlers.clear
    self
  end

  def update
    publish(xml_for(language))
    self
  end

  def panel
    @panel ||= Adwaita::ToolbarView.new.tap do |view|
      view.name = 'panel_ui'
    end
  end

  def dropdown
    @dropdown ||= Gtk::DropDown.new.tap do |drop|
      drop.model = Gtk::StringList.new(languages.map { |candidate| dropdown_label(candidate) })
      drop.tooltip_text = 'Convert and Switch Syntax'
      # Upstream's makeDropdownFlat.
      drop.first_child.add_css_class('flat')
    end
  end

  private

    # The dropdown names the syntaxes, not the languages: "Blueprint" and
    # "XML", as src/window.blp spells them.
    def dropdown_label(candidate) = candidate.id == 'xml' ? 'XML' : candidate.name

    def xml_for(candidate)
      documents.fetch(candidate.id).then do |document|
        candidate.id == 'xml' ? document.buffer.text : document.compile
      end
    end

    def publish(value)
      @xml = value || ''
      @updated_callbacks.each(&:call)
      @xml
    end

    # Upstream converts the document into the syntax being switched to before
    # it switches, so the two pages always hold the same interface, and leaves
    # the dropdown where it was if the conversion fails.
    def change_language(candidate)
      if candidate && candidate != language
        convert(candidate).then do |converted|
          if converted
            settings.set_string('user-interface-language', candidate.id)
            setup_language
          else
            dropdown.selected = languages.index(language)
          end
        end
      end
    end

    def convert(candidate)
      term_console.clear
      settings.set_boolean('show-console', true)
      documents.fetch('blueprint').then do |blueprint|
        if candidate.id == 'xml'
          documents.fetch('xml').code_view.replace_text(blueprint.compile(blueprint.buffer.text))
        else
          blueprint.code_view.replace_text(blueprint.decompile(documents.fetch('xml').buffer.text))
        end
        true
      end
    rescue StandardError => error
      term_console.log(error.message)
      false
    end

    def setup_language
      start
      stack.visible_child_name = language.id
      button_experimental.visible = language.id == 'blueprint'
      self
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
        label.label = '<b>UI</b>'
        label.use_markup = true
        label.add_css_class('dim-label')
      end
    end

    def spacer
      @spacer ||= Gtk::Separator.new(:horizontal).tap do |separator|
        separator.add_css_class('spacer')
      end
    end

    def button_experimental
      @button_experimental ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'applications-science-symbolic'
        button.tooltip_text = 'Information About Blueprint'
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
