# frozen_string_literal: true

require_relative 'document'
require_relative 'lsp_document'

# PythonDocument is the code panel's Python document, ported from upstream's
# src/langs/python/PythonDocument.js: starting pylsp and, once it is up,
# telling it to run ruff as its formatter — upstream's `PYTHON_LSP_CONFIG`
# from src/common.js.
#
# Upstream points `ruff.executable` and `ruff.config` at paths under
# `pkg.prefix`/`pkg.pkgdatadir` — the Flatpak/meson install tree this gem has
# no equivalent of — so this port leaves pylsp to find `ruff` on PATH and use
# ruff's own default configuration instead of a bundled one.
class PythonDocument < Document
  include LspDocument

  PYLSP_CONFIG = {
    pylsp: {
      configurationSources: ['ruff'],
      plugins:              {
        ruff: {
          enabled:       true,
          formatEnabled: true,
        },
      },
    },
  }.freeze

  def initialize(session:, code_view:, language:)
    super
    start_lsp_client
    configure_ruff
  end

  private

    def configure_ruff
      lsp_client&.request('workspace/didChangeConfiguration', settings: PYLSP_CONFIG)
    rescue Lsp::LspError, IOError, Errno::EPIPE => error
      warn("python language server configuration failed: #{error.message}")
    end
end
