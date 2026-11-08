# frozen_string_literal: true

require 'fileutils'

require 'adwaita'
require 'libshumate'

require_relative 'session'
require_relative 'xml'
require_relative 'panel_preview'
require_relative 'internal_previewer'

# Previewer is the pipeline between the UI panel and the preview, ported from
# upstream's src/Previewer/Previewer.js.
#
# Each time the UI panel republishes its XML, or the stylesheet changes, the
# definition is taken apart to find the one object worth previewing, that
# object's id is rewritten so the preview can be found again, the definition is
# checked for the shapes that would abort the process rather than raise, and
# what survives is built and handed to the previewer in use.
#
# Upstream can run that last step out of process, in a Vala, Rust or Python
# previewer, which is how it previews code written in those languages.
# lib/external_previewer.rb and lib/dbus_previewer.rb are unported, so this
# port has no out-of-process previewer at all: a demo whose preview widget is
# defined in Vala, Rust or Python source (rather than the UI panel's XML)
# cannot be previewed here, and `use_internal` is left with nothing to switch
# to or from.
#
# Upstream's safe mode runs each candidate definition through a throwaway
# `workbench-crasher` process first, so a definition that segfaults GTK takes
# the helper down instead of Workbench. That helper (src/Previewer/crasher.vala)
# is unported, so the session's `safe-mode` toggle is stored and shown in the
# UI but changes nothing: a crashing preview definition takes this whole
# process down with it, exactly as if safe mode were always off.
#
# Upstream's previewer.vala registers GObject types up front (`ensure_types`)
# so a demo's `<object class="ShumateSimpleMap">` resolves through
# Gtk::Builder even though nothing in Workbench itself ever instantiates one
# directly; `ensure_types` below does the same with the libshumate GI binding,
# and 'Shumate' is added to NAMESPACES so `object_class` can find it.
class Previewer
  # The namespaces a GTK Builder class name can be in, longest prefix first so
  # `Gtk` is matched before `G`.
  NAMESPACES = {
    'Graphene' => 'Graphene',
    'Pango'    => 'Pango',
    'Shumate'  => 'Shumate',
    'Gtk'      => 'Gtk',
    'Adw'      => 'Adwaita',
    'Gdk'      => 'Gdk',
    'Gsk'      => 'Gsk',
    'Gio'      => 'Gio',
    'G'        => 'GLib',
  }.freeze

  EMPTY_INTERFACE = '<?xml version="1.0" encoding="UTF-8"?><interface><object class="GtkBox"/></interface>'

  TARGET_ID_PREFIX = 'workbench_'

  FILL = 0
  CENTER = 1

  def initialize(panel:, xml_source:, css_view:, term_console:, settings:, session:)
    @panel = panel
    @xml_source = xml_source
    @css_view = css_view
    @term_console = term_console
    @settings = settings
    @session = session
    @current = nil
    @xml_handler = nil
    @css_handler = nil
  end

  attr_reader :panel, :xml_source, :css_view, :term_console, :settings, :session

  def build
    ensure_types

    panel.tap do |preview|
      settings.bind('preview-align', preview.dropdown_align, 'selected')
      preview.dropdown_align.signal_connect('notify::selected') { apply_align }
      apply_align

      preview.button_open_window.signal_connect('clicked') do
        open
        preview.show(PanelPreview::CLOSE_WINDOW)
      end

      preview.button_close_window.signal_connect('clicked') do
        close
        preview.show(PanelPreview::OPEN_WINDOW)
      end

      preview.button_screenshot.signal_connect('clicked') { screenshot }

      settings.on_change('auto-preview') do |value|
        if value
          update
        end
      end

      use_internal
      start
    end
  end

  def internal
    @internal ||= InternalPreviewer.new(
      panel:            panel,
      session:          session,
      on_window_change: method(:on_window_change),
    )
  end

  def current = @current

  def use_internal
    unless @current == internal
      @current&.stop
      @current = internal
      @current.start
    end
    update(true)
  end

  def open = current&.open

  def close = current&.close

  def open_inspector = current&.open_inspector

  # While started, the previewer follows the UI panel and the stylesheet.
  def start
    stop
    @xml_handler = xml_source.on_updated { update }
    @css_handler = css_view.on_changed { update }
    self
  end

  def stop
    if @xml_handler
      xml_source.off_updated(@xml_handler)
    end
    if @css_handler
      css_view.off_changed(@css_handler)
    end
    @xml_handler = nil
    @css_handler = nil
    self
  end

  # The whole pipeline. `force` is what a run, a language switch or a freshly
  # loaded session uses to redraw even when auto-update is off.
  def update(force = false)
    if force || settings.get_boolean('auto-preview')
      source.then do |text|
        tree_for(text).then do |tree|
          if tree
            build_and_preview(tree)
          end
        end
      end
    end
    self
  end

  def screenshot
    screenshot_path.then do |path|
      if current.screenshot(path: path)
        Gdk::Display.default.clipboard.set(Gdk::Texture.new(path: path))
        term_console.log("Screenshot captured: #{path}")
      end
    end
  end

  # Upstream's isPreviewable: an instantiable widget that is not a dialog.
  def self.previewable?(class_name)
    object_class(class_name).then do |klass|
      !klass.nil? &&
        klass.ancestors.include?(Gtk::Widget) &&
        !klass.ancestors.include?(Adwaita::Dialog) &&
        !klass.gtype.abstract?
    end
  end

  # Upstream's getObjectClass, by way of the namespace prefixes a GTK Builder
  # class name carries.
  def self.object_class(class_name)
    NAMESPACES.find { |prefix, _| class_name.start_with?(prefix) }.then do |(prefix, namespace)|
      if prefix && Object.const_defined?(namespace)
        class_name.delete_prefix(prefix).then do |name|
          module_for(namespace).then do |mod|
            if !name.empty? && mod.const_defined?(name)
              mod.const_get(name)
            end
          end
        end
      end
    end
  end

  def self.module_for(namespace) = Object.const_get(namespace)

  private

    # Upstream's Previewer#ensure_types (previewer.vala): registers the GI
    # types a previewed definition can reference but nothing in Workbench
    # itself constructs, so Gtk::Builder can still find them by class name.
    def ensure_types
      Shumate::SimpleMap.gtype
    end

    def source
      xml_source.xml.to_s.strip.then do |text|
        text.empty? ? EMPTY_INTERFACE : text
      end
    end

    def tree_for(text)
      Xml.parse(text)
    rescue Xml::ParseError
      nil
    end

    def build_and_preview(tree)
      target_buildable(tree).then do |target|
        if target[:target_id]
          assert_buildable(tree).then do |complaint|
            if complaint
              term_console.log(complaint)
            else
              preview(target)
            end
          end
        end
      end
    end

    def preview(target)
      builder_for(target[:text]).then do |builder|
        builder&.get_object(target[:target_id]).then do |object|
          if object
            apply_template_align(target[:template])
            current.update_xml(object)
            css_view.clear_diagnostics
            current.update_css(css_view.text)
          end
        end
      end
    end

    def builder_for(text)
      Gtk::Builder.new.tap { |builder| builder.add_from_string(text) }
    rescue GLib::Error => error
      term_console.log(error.message)
      nil
    end

    # Upstream's targetBuildable: a template's children are lifted into an
    # object of the class the template extends, since the template's own class
    # does not exist outside the previewed code; otherwise the first
    # previewable object in the document is used, with its id remembered so it
    # can be exposed under its original name.
    def target_buildable(tree)
      template_target(tree) || previewable_target(tree) || {}
    end

    def template_target(tree)
      tree.get_child('template').then do |template|
        if template && self.class.previewable?(template.attrs['parent'].to_s)
          target_id.then do |id|
            Xml.element('object', 'class' => template.attrs['parent'], 'id' => id).tap do |element|
              template.children.each { |child| element.cnode(child) }
              tree.remove(template)
              tree.cnode(element)
            end
            { target_id: id, text: tree.to_s, original_id: nil, template: true }
          end
        end
      end
    end

    def previewable_target(tree)
      tree.get_children('object').find do |child|
        child.attrs['class'] && self.class.previewable?(child.attrs['class'])
      end.then do |child|
        if child
          child.attrs['id'].then do |original_id|
            target_id.then do |id|
              child.attrs['id'] = id
              { target_id: id, text: tree.to_s, original_id: original_id, template: nil }
            end
          end
        end
      end
    end

    def target_id = "#{TARGET_ID_PREFIX}#{format('%016x', rand(1 << 64))}"

    # Upstream's assertBuildable, as a complaint to log rather than an
    # exception: the shapes below abort the GTK process instead of raising, so
    # the definition must not reach Gtk::Builder at all.
    def assert_buildable(tree)
      tree.get_children('object').filter_map { |object| complaint_for(object, true) }.first
    end

    def complaint_for(object, root)
      self.class.object_class(object.attrs['class'].to_s).then do |klass|
        (klass && object_complaint(object, klass, root)).then do |complaint|
          complaint || children_complaint(object)
        end
      end
    end

    def object_complaint(object, klass, root)
      if klass.gtype.abstract?
        "#{klass.gtype.name} is an abstract type. It cannot be instantiated."
      elsif !klass.ancestors.include?(Gtk::Buildable) && !object.get_children('child').empty?
        "#{klass.gtype.name} is not a GtkBuildable. It cannot have children."
      elsif !root && klass.ancestors.include?(Gtk::Root)
        "#{klass.gtype.name} is a GtkRoot. " \
          'GtkRoot objects can only be used at the top-level.'
      elsif !root && klass.ancestors.include?(Adwaita::Dialog)
        "#{klass.gtype.name} is a AdwDialog. " \
          'AdwDialog objects can only be used at the top-level.'
      elsif klass.ancestors.include?(Adwaita::Window) && property(object, 'titlebar')
        "#{klass.gtype.name} does not support the titlebar property."
      elsif klass.ancestors.include?(Adwaita::Window) && property(object, 'child')
        "#{klass.gtype.name} does not support the child property."
      elsif klass == Gtk::StackPage && child_property(object).nil?
        "#{klass.gtype.name} is missing a child widget."
      end
    end

    def children_complaint(object)
      nested_objects(object).filter_map { |nested| complaint_for(nested, false) }.first
    end

    def nested_objects(object)
      (object.get_children('property') + object.get_children('child'))
        .flat_map { |element| element.get_children('object') }
    end

    def property(object, name)
      object.get_children('property').find { |element| element.attrs['name'] == name }
    end

    def child_property(object) = property(object, 'child')&.get_child('object')

    # Upstream shows the alignment dropdown only for a template, whose
    # children are laid out by the template's own parent and so benefit from
    # being centred.
    def apply_template_align(template)
      unless panel.dropdown_align.visible?
        if template
          panel.dropdown_align.selected = CENTER
        else
          panel.dropdown_align.selected = FILL
        end
      end
      panel.dropdown_align.visible = !template.nil?
    end

    def apply_align
      (panel.dropdown_align.selected == CENTER ? :center : :fill).then do |alignment|
        panel.output.halign = alignment
        panel.output.valign = alignment
      end
    end

    def on_window_change(open)
      panel.show(open ? PanelPreview::CLOSE_WINDOW : PanelPreview::OPEN_WINDOW)
    end

    def screenshot_path
      File.join(Session.data_dir, 'screenshots').then do |directory|
        FileUtils.mkdir_p(directory)
        File.join(directory, "#{Session.now_for_filename}.png")
      end
    end
end
