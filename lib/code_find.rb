# frozen_string_literal: true

require 'gtk4'

# CodeFind is the find bar that slides up from the bottom of a CodeView,
# ported from upstream's src/widgets/CodeFind.blp and src/widgets/CodeFind.js.
#
# Upstream drives the search with GtkSource.SearchSettings and
# GtkSource.SearchContext. The GtkSourceView bindings are not available to the
# port, so the same behaviour — case-insensitive, wrapping, highlighted
# matches, "<n> of <count>" in the info label — is computed over the text
# buffer directly, and matches are highlighted with a text tag.
#
# Upstream's entry is a Box with `css-name: "entry"` holding a Gtk.Text and the
# info label; `css-name` is construct-only and unavailable from Ruby, so the
# port uses a Gtk::Entry with a find icon and puts the info label beside it.
class CodeFind
  HIGHLIGHT_TAG = 'search-match'

  def initialize(text_view)
    @text_view = text_view
    @matches = []
    @previous_search_term = ''
  end

  attr_reader :text_view

  def build
    revealer.tap do |rev|
      rev.child = box

      box.tap do |b|
        b.append(separator)
        b.append(toolbar)

        toolbar.tap do |bar|
          bar.append(entry)
          bar.append(label_info)
          bar.append(navigation)
          bar.append(button_close)

          entry.tap do |e|
            e.signal_connect('notify::text') { update_search }
            e.signal_connect('activate') { search(forward: true) }
          end

          navigation.tap do |nav|
            nav.append(button_previous)
            nav.append(button_next)

            button_previous.signal_connect('clicked') { search(forward: false) }
            button_next.signal_connect('clicked') { search(forward: true) }
          end

          button_close.signal_connect('clicked') { end_search(grab_focus: true) }
        end
      end

      rev.signal_connect('notify::reveal-child') do |this|
        unless this.reveal_child?
          text_view.grab_focus
        end
      end

      text_view.add_controller(text_view_key_controller)
      text_view_key_controller.signal_connect('key-pressed') do |_c, keyval, _code, state|
        on_text_view_key(keyval, state)
      end

      rev.add_controller(key_controller)
      key_controller.signal_connect('key-pressed') do |_c, keyval, _code, state|
        on_key(keyval, state)
      end

      buffer.tag_table.add(highlight_tag)
      buffer.signal_connect('mark-set') do |_b, _iter, mark|
        if %w[insert selection_bound].include?(mark.name)
          update_info
        end
      end
      buffer.signal_connect('changed') do
        if revealer.reveal_child?
          update_search
        end
      end
    end
  end

  # Ctrl+F from the editor: seed the term with the selection, or with whatever
  # was searched for last, then reveal and focus the entry.
  def open
    selected_text.then do |selection|
      if selection.empty?
        entry.text = @previous_search_term
      else
        entry.text = selection
      end
    end
    revealer.reveal_child = true
    entry.grab_focus
    entry.select_region(0, -1)
  end

  def close = end_search(grab_focus: true)

  def revealer
    @revealer ||= Gtk::Revealer.new.tap do |rev|
      rev.transition_type = :slide_up
      rev.reveal_child = false
      rev.vexpand = false
    end
  end

  private

    def buffer = text_view.buffer

    def box = @box ||= Gtk::Box.new(:vertical, 0)

    def separator = @separator ||= Gtk::Separator.new(:horizontal)

    def toolbar
      @toolbar ||= Gtk::Box.new(:horizontal, 6).tap do |bar|
        bar.add_css_class('toolbar')
        bar.halign = :center
      end
    end

    def entry
      @entry ||= Gtk::Entry.new.tap do |e|
        e.primary_icon_name = 'edit-find-symbolic'
        e.width_chars = 10
        e.max_width_chars = 20
        e.valign = :center
      end
    end

    def label_info
      @label_info ||= Gtk::Label.new('').tap do |label|
        label.xalign = 1
        label.opacity = 0.5
        label.valign = :center
        label.width_chars = 12
      end
    end

    def navigation
      @navigation ||= Gtk::Box.new(:horizontal, 0).tap do |nav|
        nav.valign = :center
        nav.add_css_class('linked')
      end
    end

    def button_previous
      @button_previous ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'go-up-symbolic'
        button.tooltip_text = 'Move to previous match (Ctrl+Shift+G)'
        button.sensitive = false
      end
    end

    def button_next
      @button_next ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'go-down-symbolic'
        button.tooltip_text = 'Move to next match (Ctrl+G)'
        button.sensitive = false
      end
    end

    def button_close
      @button_close ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'window-close-symbolic'
        button.tooltip_text = 'Close Search'
        button.valign = :center
        button.add_css_class('circular')
        button.add_css_class('flat')
      end
    end

    def highlight_tag
      @highlight_tag ||= Gtk::TextTag.new(HIGHLIGHT_TAG).tap do |tag|
        tag.background = '#f8e45c'
      end
    end

    def key_controller = @key_controller ||= Gtk::EventControllerKey.new

    def text_view_key_controller
      @text_view_key_controller ||= Gtk::EventControllerKey.new
    end

    def control?(state) = state.control_mask?
    def shift?(state) = state.shift_mask?

    # Ctrl+F opens the bar, Escape closes it, Ctrl+G and Ctrl+Shift+G step
    # through matches without leaving the editor.
    def on_text_view_key(keyval, state)
      if control?(state) && [Gdk::Keyval::KEY_f, Gdk::Keyval::KEY_F].include?(keyval)
        open
        true
      elsif revealer.reveal_child? && keyval == Gdk::Keyval::KEY_Escape
        end_search(grab_focus: false)
        true
      elsif revealer.reveal_child? && control?(state) &&
            [Gdk::Keyval::KEY_g, Gdk::Keyval::KEY_G].include?(keyval)
        search(forward: !shift?(state))
        true
      else
        false
      end
    end

    def on_key(keyval, state)
      if control?(state) && [Gdk::Keyval::KEY_g, Gdk::Keyval::KEY_G].include?(keyval)
        search(forward: !shift?(state))
        true
      elsif shift?(state) && keyval == Gdk::Keyval::KEY_Return
        search(forward: false)
        true
      elsif keyval == Gdk::Keyval::KEY_Escape
        end_search(grab_focus: true)
        true
      else
        false
      end
    end

    def end_search(grab_focus:)
      revealer.reveal_child = false
      @previous_search_term = entry.text
      entry.text = ''
      if grab_focus
        text_view.grab_focus
      end
    end

    # Gtk::TextBuffer#selection_bounds answers nil when nothing is selected,
    # and the pair of iters when something is.
    def selected_text
      buffer.selection_bounds.then do |bounds|
        bounds ? buffer.get_text(bounds[0], bounds[1], true) : ''
      end
    end

    # The matches are recomputed whenever the term or the text changes, which
    # is what GtkSource.SearchContext does behind its occurrences-count.
    def update_search
      @matches = find_matches(entry.text)
      clear_highlight
      highlight_matches
      button_previous.sensitive = !@matches.empty?
      button_next.sensitive = !@matches.empty?
      update_info
    end

    def find_matches(term)
      [].tap do |matches|
        term.downcase.then do |needle|
          unless needle.empty?
            buffer.text.downcase.then do |haystack|
              offset = 0
              while (found = haystack.index(needle, offset))
                matches << [found, found + needle.length]
                offset = found + 1
              end
            end
          end
        end
      end
    end

    def clear_highlight
      buffer.remove_tag(highlight_tag, buffer.start_iter, buffer.end_iter)
    end

    def highlight_matches
      @matches.each do |(from, to)|
        buffer.apply_tag(
          highlight_tag,
          buffer.get_iter_at(offset: from),
          buffer.get_iter_at(offset: to),
        )
      end
    end

    # Forward starts from the end of the selection, backward from its start,
    # and both wrap around, as upstream's wrap_around setting asks.
    def search(forward:)
      if @matches.empty?
        @matches = find_matches(entry.text)
      end
      unless @matches.empty?
        cursor_bounds.then do |bounds|
          if forward
            @matches.find { |(start, _)| start >= bounds[1] } || @matches.first
          else
            @matches.reverse.find { |(_, finish)| finish <= bounds[0] } || @matches.last
          end.then { |match| select_occurrence(match) }
        end
      end
    end

    def cursor_bounds
      buffer.selection_bounds.then do |bounds|
        if bounds
          [bounds[0].offset, bounds[1].offset]
        else
          [buffer.cursor_position, buffer.cursor_position]
        end
      end
    end

    def select_occurrence(match)
      buffer.select_range(
        buffer.get_iter_at(offset: match[0]),
        buffer.get_iter_at(offset: match[1]),
      )
      text_view.scroll_mark_onscreen(buffer.get_mark('insert'))
      update_info
    end

    def update_info
      if entry.text.empty? || @matches.empty?
        label_info.label = ''
      else
        current_match_index.then do |index|
          if index
            label_info.label = "#{index + 1} of #{@matches.size}"
          else
            label_info.label = "#{@matches.size} occurences"
          end
        end
      end
    end

    def current_match_index
      buffer.selection_bounds.then do |bounds|
        if bounds
          @matches.index([bounds[0].offset, bounds[1].offset])
        end
      end
    end
end
