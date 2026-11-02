# frozen_string_literal: true

# Xml is the XML the port reads, rewrites and prints, ported from upstream's
# src/langs/xml/xml.js and the vendored parser it wraps, src/lib/ltx.js.
#
# Upstream does not use a full XML implementation: it ships ltx, a small
# tokenizer and element tree, because the previewer has to take a GTK Builder
# definition apart — find the buildable to preview, rename its id, lift a
# template's children into an object — and print it back out. The port keeps
# that shape: a tokenizer that reports start, end and text events, an Element
# tree built on top of it, and `format`, which is upstream's printer with its
# indentation rules unchanged.
#
# REXML would do the same job but is a bundled gem the app's runtime closure
# does not carry, and a GTK Builder file needs none of what it adds.
module Xml
  class ParseError < StandardError; end

  ESCAPES = {
    '&' => '&amp;',
    '<' => '&lt;',
    '>' => '&gt;',
    '"' => '&quot;',
    "'" => '&apos;',
  }.freeze

  UNESCAPES = {
    'amp'  => '&',
    'lt'   => '<',
    'gt'   => '>',
    'quot' => '"',
    'apos' => "'",
  }.freeze

  DECLARATION = '<?xml version="1.0" encoding="UTF-8"?>'

  def self.escape(value) = value.to_s.gsub(/[&<>"']/) { |char| ESCAPES[char] }

  # Text content needs neither quote escaped, which is what upstream's
  # escapeXMLText does.
  def self.escape_text(value) = value.to_s.gsub(/[&<>]/) { |char| ESCAPES[char] }

  def self.unescape(value)
    value.to_s.gsub(/&(#x?[0-9a-fA-F]+|\w+);/) do
      Regexp.last_match(1).then do |entity|
        if entity.start_with?('#x', '#X')
          entity[2..].to_i(16).chr(Encoding::UTF_8)
        elsif entity.start_with?('#')
          entity[1..].to_i.chr(Encoding::UTF_8)
        else
          UNESCAPES.fetch(entity, "&#{entity};")
        end
      end
    end
  end

  # One element of the tree. `attrs` is a plain string-keyed hash, as it is in
  # ltx, so the previewer can read and write `attrs['class']` and
  # `attrs['id']` directly.
  class Element
    def initialize(name, attrs = {}, children = [])
      @name = name
      @attrs = attrs.transform_keys(&:to_s)
      @children = []
      children.each { |child| cnode(child) }
    end

    attr_reader :name, :attrs, :children
    attr_accessor :parent

    def elements = children.grep(Element)

    def get_child(name) = elements.find { |child| child.name == name }

    def get_children(name) = elements.select { |child| child.name == name }

    # ltx's cnode: append a child and adopt it.
    def cnode(child)
      if child.is_a?(Element)
        child.parent = self
      end
      @children << child
      child
    end

    def remove(child)
      @children.delete(child)
      if child.is_a?(Element)
        child.parent = nil
      end
      child
    end

    def text = children.grep(String).join

    def to_s
      (+'<').tap do |out|
        out << name
        attrs.each { |key, value| out << %( #{key}="#{Xml.escape(value)}") }
        if children.empty?
          out << '/>'
        else
          out << '>'
          children.each do |child|
            out << (child.is_a?(Element) ? child.to_s : Xml.escape_text(child))
          end
          out << "</#{name}>"
        end
      end
    end
  end

  # Upstream's createElement.
  def self.element(name, attrs = {}, children = []) = Element.new(name, attrs, Array(children))

  # The tokenizer. It reports the three events upstream's printer listens for:
  # `start_element(name, attrs)`, `end_element(name, self_closing)` and
  # `text(string)`. Comments, processing instructions and doctypes are skipped,
  # and CDATA is reported as text, as ltx does.
  class Scanner
    def initialize(source)
      @source = source.to_s
    end

    def scan(&_block)
      position = 0
      while position < @source.length
        @source.index('<', position).then do |opening|
          if opening.nil?
            emit_text(@source[position..], &_block)
            position = @source.length
          else
            if opening > position
              emit_text(@source[position...opening], &_block)
            end
            position = scan_markup(opening, &_block)
          end
        end
      end
      self
    end

    private

      def emit_text(raw, &block)
        unless raw.nil? || raw.empty?
          block.call(:text, Xml.unescape(raw), nil)
        end
      end

      def scan_markup(opening, &block)
        if @source[opening, 4] == '<!--'
          skip_to(opening, '-->')
        elsif @source[opening, 9] == '<![CDATA['
          index_or_fail(opening + 9, ']]>').then do |close|
            block.call(:text, @source[(opening + 9)...close], nil)
            close + 3
          end
        elsif @source[opening, 2] == '<?'
          skip_to(opening, '?>')
        elsif @source[opening, 2] == '<!'
          skip_to(opening, '>')
        else
          scan_tag(opening, &block)
        end
      end

      def skip_to(opening, terminator)
        index_or_fail(opening, terminator) + terminator.length
      end

      def index_or_fail(from, terminator)
        @source.index(terminator, from) ||
          raise(ParseError, "unterminated #{terminator.inspect}")
      end

      # The end of a tag has to be found past any quoted attribute value, so
      # a `>` inside an attribute does not end the tag early.
      def tag_end(opening)
        position = opening + 1
        quote = nil
        found = nil
        while found.nil? && position < @source.length
          @source[position].then do |char|
            if quote
              if char == quote
                quote = nil
              end
            elsif ['"', "'"].include?(char)
              quote = char
            elsif char == '>'
              found = position
            end
          end
          position += 1
        end
        found || raise(ParseError, 'unterminated tag')
      end

      def scan_tag(opening, &block)
        tag_end(opening).then do |closing|
          @source[(opening + 1)...closing].then do |body|
            if body.start_with?('/')
              block.call(:end_element, body[1..].strip, false)
            elsif body.end_with?('/')
              parse_tag(body[0..-2]).then do |(name, attrs)|
                block.call(:start_element, name, attrs)
                block.call(:end_element, name, true)
              end
            else
              parse_tag(body).then do |(name, attrs)|
                block.call(:start_element, name, attrs)
              end
            end
          end
          closing + 1
        end
      end

      ATTRIBUTE = /([^\s=\/>]+)\s*(?:=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'>]+)))?/

      def parse_tag(body)
        body.strip.then do |stripped|
          stripped.split(/\s/, 2).then do |(name, rest)|
            [name, parse_attributes(rest)]
          end
        end
      end

      def parse_attributes(rest)
        {}.tap do |attrs|
          rest.to_s.scan(ATTRIBUTE) do |key, double, single, bare|
            attrs[key] = Xml.unescape(double || single || bare || '')
          end
        end
      end
  end

  # Builds the tree. An empty or malformed document raises, which is what the
  # previewer and the XML document both treat as "nothing to show yet".
  def self.parse(source)
    stack = []
    root = nil

    Scanner.new(source).scan do |event, first, second|
      case event
      when :start_element
        Element.new(first, second).then do |element|
          stack.last&.cnode(element)
          root ||= element
          stack << element
        end
      when :end_element
        if stack.empty?
          raise(ParseError, 'unexpected closing tag')
        end
        unless stack.last.name == first
          raise(ParseError, "expected </#{stack.last.name}>")
        end

        stack.pop
      when :text
        stack.last&.cnode(first)
      end
    end

    unless stack.empty?
      raise(ParseError, 'unclosed elements')
    end
    if root.nil?
      raise(ParseError, 'no root element')
    end

    root
  end

  # Upstream's format(): the same algorithm as blueprint-compiler's
  # xml_emitter.py, so a document round-trips between the two syntaxes without
  # the diff being all whitespace. Whitespace-only text is dropped, and a tag
  # whose content was only whitespace closes on its own line.
  def self.format(source, indent = 2)
    (indent.is_a?(Integer) ? ' ' * indent : indent).then do |padding|
      level = 0
      current_tag = nil
      needs_newline = false
      out = +DECLARATION

      Scanner.new(source).scan do |event, first, second|
        case event
        when :start_element
          # A nested element has to close its parent's opening tag. Upstream
          # relies on the whitespace between the two tags to do this, which
          # leaves a minified document unclosed, so the port closes it here.
          if current_tag
            out << '>'
          end
          current_tag = first
          out << "\n" << (padding * level)
          out << "<#{first}"
          second.each { |key, value| out << %( #{key}="#{escape(value)}") }
          level += 1
          needs_newline = false
        when :end_element
          if current_tag && first != current_tag
            raise(ParseError, 'Invalid XML document')
          end

          level -= 1
          if needs_newline
            out << "\n" << (padding * level)
          end

          if second
            out << '/>'
          else
            if current_tag
              out << '>'
            end
            out << "</#{first}>"
          end

          current_tag = nil
          needs_newline = true
        when :text
          if current_tag
            out << '>'
            current_tag = nil
          end
          first.strip.then do |stripped|
            unless stripped.empty?
              out << escape_text(stripped)
              needs_newline = false
            end
          end
        end
      end

      unless level.zero?
        raise(ParseError, 'Invalid XML document')
      end

      out
    end
  end
end
