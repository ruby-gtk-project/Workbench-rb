# frozen_string_literal: true

require_relative 'document'
require_relative 'xml'

# XmlDocument is the GTK Builder document of a session, ported from upstream's
# src/langs/xml/XmlDocument.js.
#
# It is the one language whose formatting needs no language server: upstream
# formats it with its own printer, src/langs/xml/xml.js, at an indent of two
# spaces. That printer is ported in lib/xml.rb, so this document is the same
# two lines it is upstream — format the buffer, replace the text without
# restoring cursor state, as `replaceText(code, false)` does.
class XmlDocument < Document
  INDENT = 2

  def format
    formatted(buffer.text).then do |code|
      if code
        code_view.replace_text(code, false)
      end
    end
    self
  end

  # A buffer that is not well-formed XML is left alone: the previewer already
  # reports the parse error, and overwriting text the user is still typing
  # would lose it.
  def formatted(text)
    Xml.format(text, INDENT)
  rescue Xml::ParseError
    nil
  end
end
