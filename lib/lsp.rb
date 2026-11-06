# frozen_string_literal: true

# Lsp holds the small, static pieces of the Language Server Protocol this
# port needs, ported from upstream's src/lsp/LSP.js: the diagnostic severity
# names a response carries as an integer, and the error upstream raises for
# a JSON-RPC error response.
module Lsp
  # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#diagnosticSeverity
  DIAGNOSTIC_SEVERITIES = {
    1 => 'Error',
    2 => 'Warning',
    3 => 'Information',
    4 => 'Hint',
  }.freeze

  # Upstream's LSPError: a JSON-RPC error response, raised with the server's
  # own code and data attached rather than collapsed into a plain message.
  class LspError < StandardError
    def initialize(message:, code: nil, data: nil)
      super(message)
      @code = code
      @data = data
    end

    attr_reader :code, :data
  end

  def self.range_equals(start, finish) = start[:line] == finish[:line] && start[:character] == finish[:character]
end
