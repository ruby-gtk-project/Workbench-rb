# frozen_string_literal: true

require_relative 'document'
require_relative 'lsp_document'

# ValaDocument is the code panel's Vala document, ported from upstream's
# src/langs/vala/ValaDocument.js.
#
# Upstream's `setup()` does two things before starting vala-language-server:
# gates on `isValaAvailable()`, a check on the Vala GNOME extension row in the
# Extensions dialog, and copies a `workbench.vala` API stub — the
# declarations for the widgets Workbench previews — into the session
# directory so the language server (and upstream's Vala *compiler*) can
# resolve them. The gate is dropped the way every language here drops it: try
# to start, log if the binary is missing. The API stub is not copied, because
# nothing reads it: there is no Vala compiler on this port's run path at all
# (src/langs/vala/Compiler.js is unported — see Window#run), so a user who
# writes Vala referencing a Workbench widget gets no completions or
# diagnostics for it from the language server, and Run never compiles the
# document regardless.
class ValaDocument < Document
  include LspDocument

  def initialize(session:, code_view:, language:)
    super
    start_lsp_client
  end
end
