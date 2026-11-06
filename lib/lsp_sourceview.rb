# frozen_string_literal: true

# LspSourceview applies a language server's text edits to a GTK text buffer,
# ported from upstream's src/lsp/sourceview.js (only `applyTextEdits`; its
# `getItersAtRange` is already ported as CodeView's private `iters_at_range`,
# which this port's diagnostics use instead).
#
# Upstream stages a start/end Gtk.TextMark per edit before applying any of
# them, because deleting or inserting text shifts every later offset in the
# buffer; marks move with the text around them, so the positions stay correct
# edit to edit. A formatter that "doesn't support diff" and returns one edit
# spanning the whole document — Biome, the GTK CSS language server, the
# Blueprint compiler — needs none of that, but a real diff with several edits
# does, so the staging is kept rather than dropped for the common case.
module LspSourceview
  def self.apply_text_edits(text_edits, buffer)
    if text_edits && !text_edits.empty?
      buffer.begin_user_action
      marks = text_edits.map { |text_edit| prepare(text_edit, buffer) }
      text_edits.zip(marks).each { |text_edit, mark| apply(text_edit, mark, buffer) }
      buffer.end_user_action
    end
  end

  def self.prepare(text_edit, buffer)
    range = text_edit[:range]
    start_iter = buffer.get_iter_at(line: range[:start][:line], offset: range[:start][:character])
    end_iter = buffer.get_iter_at(line: range[:end][:line], offset: range[:end][:character])
    [buffer.create_mark(nil, start_iter, true), buffer.create_mark(nil, end_iter, false)]
  end

  def self.apply(text_edit, mark, buffer)
    begin_mark, end_mark = mark
    buffer.delete(buffer.get_iter_at(mark: begin_mark), buffer.get_iter_at(mark: end_mark))
    buffer.insert(buffer.get_iter_at(mark: begin_mark), text_edit[:newText])
    buffer.delete_mark(begin_mark)
    buffer.delete_mark(end_mark)
  end
end
