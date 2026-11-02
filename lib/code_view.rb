# frozen_string_literal: true

require 'gtk4'
require 'adwaita'

require_relative 'code_find'

# CodeView is the editor every panel is built around, ported from upstream's
# src/widgets/CodeView.blp and src/widgets/CodeView.js: a scrolled text editor
# with the find bar beneath it, a `changed` notification that fires once per
# user action rather than once per keystroke, saved and restored cursor and
# scroll state, and the error/warning underlines a language server's
# diagnostics are drawn with.
#
# Upstream's editor is a GtkSource.View with a GtkSource.Buffer: it brings
# syntax highlighting, the Adwaita style schemes, and the completion and hover
# providers. The GtkSourceView bindings are not available to the port, so the
# editor here is a Gtk::TextView with its monospace, indentation and undo
# settings, and `language_id` is carried for the panels and the diagnostics log
# to name the document by. Completion and hover, which exist only as provider
# interfaces on GtkSource.View, are not part of this class.
class CodeView
  # Upstream's two diagnostic tags, with the colours it parses them from.
  TAG_ERROR = 'error'
  TAG_WARNING = 'warning'
  ERROR_COLOR = '#e01b24'
  WARNING_COLOR = '#ffa348'

  def initialize(language_id:)
    @language_id = language_id
    @changed_callbacks = []
    @diagnostics = []
  end

  attr_reader :language_id, :diagnostics

  def build
    box.tap do |b|
      b.append(scrolled_window)
      b.append(code_find.build)

      scrolled_window.child = text_view

      buffer.tap do |buf|
        # Upstream cannot use "changed": it fires once per inserted character,
        # so a paste would trigger a run of updates. These three fire once per
        # user action instead.
        buf.signal_connect_after('end-user-action') { emit_changed }
        buf.signal_connect_after('undo') { emit_changed }
        buf.signal_connect_after('redo') { emit_changed }
      end
    end
  end

  def widget = box

  def buffer = text_view.buffer

  def text = buffer.text

  # Upstream's CodeView emits a "changed" signal; the port hands out the same
  # notification as a callback, since the class is plain Ruby.
  def on_changed(&block)
    @changed_callbacks << block
    block
  end

  def off_changed(block) = @changed_callbacks.delete(block)

  # Upstream's saveState(): where the cursor is and how far the view is
  # scrolled, so a reformat does not throw the reader back to the top.
  def save_state
    buffer.get_iter_at(offset: buffer.cursor_position).then do |iter|
      {
        line_number:       iter.line,
        line_offset:       iter.line_offset,
        h_scroll_position: scrolled_window.hadjustment.value,
        v_scroll_position: scrolled_window.vadjustment.value,
      }
    end
  end

  def restore_state(state)
    # Restoring on idle, as upstream does: the view has not laid out the new
    # text yet when the state comes back, so the adjustments would clamp.
    GLib::Idle.add(GLib::PRIORITY_DEFAULT_IDLE) do
      scrolled_window.hadjustment.value = state[:h_scroll_position]
      scrolled_window.vadjustment.value = state[:v_scroll_position]
      buffer.place_cursor(
        buffer.get_iter_at(line: state[:line_number], line_offset: state[:line_offset]),
      )
      GLib::Source::REMOVE
    end
    self
  end

  # Upstream's replaceText(): one user action, so one undo step and one
  # `changed` notification.
  def replace_text(text, restore_state = false)
    (text.empty? ? ' ' : text).then do |replacement|
      (restore_state ? save_state : nil).then do |state|
        buffer.begin_user_action
        buffer.delete(buffer.start_iter, buffer.end_iter)
        buffer.insert(buffer.start_iter, replacement)
        buffer.end_user_action

        if state
          self.restore_state(state)
        else
          buffer.place_cursor(buffer.start_iter)
        end
      end
    end
    self
  end

  def clear_diagnostics
    buffer.remove_tag(tag_error, buffer.start_iter, buffer.end_iter)
    buffer.remove_tag(tag_warning, buffer.start_iter, buffer.end_iter)
    @diagnostics = []
    self
  end

  # Upstream's handleDiagnostics(): underline each range and log it. A
  # diagnostic is the language server's shape — a `range` of line/character
  # pairs, a `message` and a `severity`, 1 being an error.
  def handle_diagnostics(diagnostics)
    clear_diagnostics
    @diagnostics = diagnostics
    diagnostics.each do |diagnostic|
      log_diagnostic(diagnostic)
      iters_at_range(diagnostic[:range]).then do |(start_iter, end_iter)|
        buffer.apply_tag(
          diagnostic[:severity] == 1 ? tag_error : tag_warning,
          start_iter,
          end_iter,
        )
      end
    end
    self
  end

  def code_find = @code_find ||= CodeFind.new(text_view)

  def box
    @box ||= Gtk::Box.new(:vertical, 0).tap do |b|
      b.vexpand = true
    end
  end

  def scrolled_window
    @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
      window.vexpand = true
    end
  end

  # The GtkSource.View properties upstream sets in CodeView.blp, as far as
  # Gtk::TextView carries them.
  def text_view
    @text_view ||= Gtk::TextView.new.tap do |view|
      view.monospace = true
      view.left_margin = 6
      view.right_margin = 6
      view.top_margin = 6
      view.bottom_margin = 6
      view.wrap_mode = :none
      view.accepts_tab = true
      view.buffer.enable_undo = true
    end
  end

  private

    # The tags join the buffer's tag table as they are created, so a
    # diagnostic can be applied or cleared before the widget is assembled.
    def tag_error = @tag_error ||= diagnostic_tag(TAG_ERROR, ERROR_COLOR)

    def tag_warning = @tag_warning ||= diagnostic_tag(TAG_WARNING, WARNING_COLOR)

    def diagnostic_tag(name, color)
      Gtk::TextTag.new(name).tap do |tag|
        tag.underline = :error
        tag.underline_rgba = Gdk::RGBA.parse(color)
        buffer.tag_table.add(tag)
      end
    end

    def emit_changed = @changed_callbacks.each(&:call)

    # Upstream's getItersAtRange, from src/lsp/sourceview.js.
    def iters_at_range(range)
      [
        buffer.get_iter_at(
          line:        range[:start][:line],
          line_offset: range[:start][:character],
        ),
        buffer.get_iter_at(
          line:        range[:end][:line],
          line_offset: range[:end][:character],
        ),
      ]
    end

    SEVERITIES = { 1 => 'error', 2 => 'warning', 3 => 'information', 4 => 'hint' }.freeze

    def log_diagnostic(diagnostic)
      diagnostic[:range].then do |range|
        warn(
          "#{language_id}-#{SEVERITIES[diagnostic[:severity]]} " \
          "#{range[:start][:line] + 1}:#{range[:start][:character]} to " \
          "#{range[:end][:line] + 1}:#{range[:end][:character]} #{diagnostic[:message]}",
        )
      end
    end
end
