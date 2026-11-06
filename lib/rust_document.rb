# frozen_string_literal: true

require_relative 'document'
require_relative 'lsp_document'

# RustDocument is the code panel's Rust document, ported from upstream's
# src/langs/rust/RustDocument.js.
#
# Upstream gates starting rust-analyzer behind `isRustAvailable()`, a check on
# the Rust GNOME extension from the unported Extensions system; dropped here
# the way every language here drops it (try to start, log if missing).
# `setupRustProject` and `installRustLibraries`, the Cargo project
# scaffolding, belong to the unported src/langs/rust/Compiler.js.
class RustDocument < Document
  include LspDocument

  def initialize(session:, code_view:, language:)
    super
    start_lsp_client
  end
end
