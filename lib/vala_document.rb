# frozen_string_literal: true

require_relative 'document'
require_relative 'lsp_document'

# ValaDocument is the code panel's Vala document, ported from upstream's
# src/langs/vala/ValaDocument.js.
#
# Upstream's `setup()` does two things before starting vala-language-server:
# gates on `isValaAvailable()`, a check on the Vala GNOME extension from the
# unported Extensions system, and copies a `workbench.vala` API stub — the
# declarations for the widgets Workbench previews — into the session
# directory so the language server (and upstream's Vala *compiler*) can
# resolve them. The gate is dropped the way every language here drops it: try
# to start, log if the binary is missing. The API stub is not copied, because
# nothing reads it without src/langs/vala/Compiler.js, which is not ported —
# `Window#run` already documents that it formats documents and redraws the
# preview but does not execute code.
class ValaDocument < Document
  include LspDocument

  def initialize(session:, code_view:, language:)
    super
    start_lsp_client
  end
end
