# frozen_string_literal: true

require_relative 'document'
require_relative 'lsp_document'

# JavaScriptDocument is the code panel's JavaScript document, ported from
# upstream's src/langs/javascript/JavaScriptDocument.js.
#
# Upstream's own file is nearly all `setup()` — building the LSPClient around
# `language_server: ["biome", "lsp-proxy", "--config-path=..."]` — which this
# port holds once in lib/lsp_document.rb and reaches through `language.id`.
# Not ported: `setupJavascriptProject`, upstream's `jsconfig.json` scaffolding
# for a freshly switched-to JavaScript project, which belongs to the
# src/langs/javascript/Builder.js this port does not have.
class JavaScriptDocument < Document
  include LspDocument

  def initialize(session:, code_view:, language:)
    super
    start_lsp_client
  end
end
