# frozen_string_literal: true

require 'adwaita'

require_relative 'panel_preview'

# InternalPreviewer previews an interface in this process, ported from
# upstream's src/Previewer/Internal.js.
#
# A definition whose previewable object is an ordinary widget is placed in the
# preview panel's viewport. One whose object is a Gtk.Root — a window — cannot
# be placed inside another window, so it is presented as a window of its own
# and the panel offers to open and close it instead.
#
# The session's stylesheet is scoped to the preview before it is installed, so
# a rule written for `window` or `button` styles the preview and not the rest
# of Workbench. Upstream scopes it with postcss, which it already depends on;
# the port rewrites the selector of each top-level rule, which is the same
# transformation. Rules nested inside an at-rule such as `@media` are left
# alone, as they are upstream.
#
# What is missing next to upstream is the custom Gtk.BuilderScope: upstream
# installs one so that a `<signal>` in a previewed definition resolves to a
# logging handler instead of failing to resolve. Gtk::BuilderScope cannot be
# implemented from Ruby, so a previewed signal is simply not connected and GTK
# logs that it could not find the handler.
class InternalPreviewer
  def initialize(panel:, session:, on_window_change:)
    @panel = panel
    @session = session
    @on_window_change = on_window_change
    @object_root = nil
    @css_provider = nil
  end

  attr_reader :panel, :session

  # The viewport's name is what the scoped stylesheet is keyed on: the
  # preview is its child, so a selector nested under it reaches the preview
  # and nothing else. Upstream names the scrolled window around it instead.
  def start(_language = nil)
    panel.output.name = scope_name
    self
  end

  def open
    @object_root.then do |root|
      if root
        root.present
        @on_window_change.call(true)
      end
    end
    self
  end

  def close
    @object_root&.close
    self
  end

  def stop
    close
    remove_css_provider
    @object_root&.destroy
    @object_root = nil
    self
  end

  # Upstream's updateXML: place the object, or present it as a window.
  def update_xml(object_preview)
    if object_preview.is_a?(Gtk::Root)
      update_root(object_preview)
    else
      update_non_root(object_preview)
    end
  end

  def update_css(css)
    remove_css_provider
    css.to_s.then do |style|
      # Upstream's workaround for a stylesheet that is still being typed and
      # ends in a bare `#`, which the GTK CSS parser rejects noisily.
      unless style.strip.empty? || style.match?(/#\s*\z/)
        install_css_provider(scope_stylesheet(style, css_scope_name))
      end
    end
    self
  end

  def open_inspector = Gtk::Window.set_interactive_debugging(true)

  def close_inspector = Gtk::Window.set_interactive_debugging(false)

  # Upstream's screenshot(): render the preview to a texture and write it out.
  # A widget that has not been allocated yet produces no render node, which is
  # the `false` upstream reports so the caller can skip the clipboard and the
  # notification.
  def screenshot(path:)
    (@object_root || panel.output).then do |widget|
      Gtk::Snapshot.new.then do |snapshot|
        Gtk::WidgetPaintable.new(widget).snapshot(
          snapshot,
          widget.width,
          widget.height,
        )
        snapshot.to_node.then do |node|
          if node && widget.native
            widget.native.renderer.render_texture(
              node,
              Graphene::Rect.new.init(
                0,
                0,
                widget.width,
                widget.height,
              ),
            ).save_to_png(path)
            true
          else
            false
          end
        end
      end
    end
  end

  private

    def scope_name = "workbench_output-#{session.id}"

    def css_scope_name = scope_name

    def update_root(object_preview)
      panel.show(PanelPreview::CLOSE_WINDOW)
      # Upstream copies the new window's properties onto the one already open
      # when the two are the same type, to avoid the window flickering. The
      # port takes its other path — destroy and replace — for every re-run.
      @object_root&.destroy
      set_object_root(object_preview)
      object_preview.name = scope_name
      @object_root
    end

    def update_non_root(object_preview)
      @object_root&.destroy
      @object_root = nil
      panel.show(PanelPreview::INLINE)
      panel.output.child = object_preview
      object_preview
    end

    def set_object_root(object)
      @object_root = object
      object.signal_connect('close-request') do
        @object_root = nil
        @on_window_change.call(false)
        false
      end
      object.present
      @on_window_change.call(true)
      object
    end

    def install_css_provider(style)
      @css_provider = Gtk::CssProvider.new.tap do |provider|
        provider.load_from_data(style)
        Gtk::StyleContext.add_provider_for_display(
          panel.output.display,
          provider,
          Gtk::StyleProvider::PRIORITY_APPLICATION,
        )
      end
    end

    def remove_css_provider
      if @css_provider
        Gtk::StyleContext.remove_provider_for_display(
          panel.output.display,
          @css_provider,
        )
        @css_provider = nil
      end
    end

    # Upstream's scopeStylesheet: `window` becomes the preview's own id, a
    # pseudo-selector is left alone, and anything else is nested under the id.
    def scope_stylesheet(style, id)
      (+'').tap do |out|
        position = 0
        while (brace = style.index('{', position))
          closing_brace(style, brace).then do |closing|
            out << scope_selector(style[position...brace], id)
            out << style[brace..closing]
            position = closing + 1
          end
        end
        out << style[position..].to_s
      end
    end

    def scope_selector(selector, id)
      selector.strip.then do |stripped|
        if stripped.start_with?('@')
          "\n#{stripped}"
        else
          stripped.split(',').map { |one| scope_one(one.strip, id) }.join(', ').then do |scoped|
            "\n#{scoped}"
          end
        end
      end
    end

    def scope_one(selector, id)
      if selector == 'window'
        "##{id}"
      elsif selector.start_with?(':')
        selector
      else
        "##{id} #{selector}"
      end
    end

    def closing_brace(style, opening)
      depth = 0
      position = opening
      found = nil
      while found.nil? && position < style.length
        if style[position] == '{'
          depth += 1
        end
        if style[position] == '}'
          depth -= 1
          if depth.zero?
            found = position
          end
        end
        position += 1
      end
      found || (style.length - 1)
    end
end
