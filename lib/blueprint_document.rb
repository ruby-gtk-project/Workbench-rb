# frozen_string_literal: true

require_relative 'document'
require_relative 'lsp_document'

# BlueprintDocument is the UI panel's Blueprint document, ported from
# upstream's src/langs/blueprint/BlueprintDocument.js: on top of the usual
# language-server setup, it is the one document PanelUI asks to convert
# between syntaxes, through blueprint-compiler's own `textDocument/x-
# blueprint-compile` and `x-blueprint/decompile` methods.
class BlueprintDocument < Document
  include LspDocument

  def initialize(session:, code_view:, language:)
    super
    start_lsp_client
  end

  # Upstream's update(): push the buffer's current text to the server before
  # asking it anything that depends on it.
  def update
    lsp_client&.did_change
    self
  end

  # Upstream's compile(): the document the panel's dropdown holds is always
  # this one's own buffer, so `text` (PanelUI passes it only to make the
  # dependency explicit at the call site) is not a second source to compile —
  # it is pushed with #update and then compiled by the server from the live
  # document, same as upstream's no-argument compile().
  def compile(_text = nil)
    update
    lsp_client&.request('textDocument/x-blueprint-compile', textDocument: { uri: uri })&.fetch(:xml, nil)
  rescue Lsp::LspError, IOError, Errno::EPIPE => error
    warn("blueprint compile failed: #{error.message}")
    nil
  end

  def decompile(text)
    lsp_client&.request('x-blueprint/decompile', text: text)&.fetch(:blp, nil)
  rescue Lsp::LspError, IOError, Errno::EPIPE => error
    warn("blueprint decompile failed: #{error.message}")
    nil
  end
end
