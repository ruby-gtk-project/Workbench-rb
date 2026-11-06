# frozen_string_literal: true

require_relative 'document'
require_relative 'lsp_document'

# CssDocument is the style panel's document, ported from upstream's
# src/langs/css/CssDocument.js: a thin subclass whose entire job upstream is
# starting GTKCssLanguageServer and formatting through it, both of which
# lib/lsp_document.rb holds the shape for.
class CssDocument < Document
  include LspDocument

  def initialize(session:, code_view:, language:)
    super
    start_lsp_client
  end
end
