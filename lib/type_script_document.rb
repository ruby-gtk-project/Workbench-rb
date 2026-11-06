# frozen_string_literal: true

require_relative 'document'
require_relative 'lsp_document'

# TypeScriptDocument is the code panel's TypeScript document, ported from
# upstream's src/langs/typescript/TypeScriptDocument.js.
#
# Upstream's `setup()` gates starting typescript-language-server behind
# `isTypeScriptAvailable()`, a check on the TypeScript GNOME extension from
# the unported Extensions system; this port instead simply tries to start the
# server lib/lsp_document.rb holds the shape for, and logs rather than raises
# when `typescript-language-server` is not on PATH. Not ported:
# `setupTypeScriptProject`, the `tsconfig.json` scaffolding that belongs to
# the unported src/langs/typescript/Compiler.js.
class TypeScriptDocument < Document
  include LspDocument

  def initialize(session:, code_view:, language:)
    super
    start_lsp_client
  end
end
