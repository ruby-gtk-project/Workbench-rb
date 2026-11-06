# frozen_string_literal: true

require_relative 'lsp_client'
require_relative 'lsp_sourceview'

# LspDocument is the shape every per-language `*_document.rb` builds on top of
# Document: start the language's server over lib/lsp_client.rb, forward its
# diagnostics to the CodeView, and format through a textDocument/formatting
# request applied with lib/lsp_sourceview.rb.
#
# Upstream repeats this setup by hand in each src/langs/*/<language>.js
# `setup()` — construct an LSPClient from common.js's `createLSPClient`,
# connect its diagnostics notification, start it, and connect a second
# `modified-changed` listener for `didChange`. The shape never varies
# between languages (what varies is the language id, the argv and, for vala,
# rust and typescript, a gate on whether the matching GNOME extension is
# installed — that gate belongs to the Extensions system, which is not
# ported, so every language here simply tries to start its server and treats
# a missing executable the way Previewer treats a missing crasher process:
# logged, not fatal), so this port holds the shape once rather than copying it
# into every subclass.
module LspDocument
  LSP_OPTION_NAMES = {
    tab_size:                 'tabSize',
    insert_spaces:            'insertSpaces',
    trim_trailing_whitespace: 'trimTrailingWhitespace',
    insert_final_newline:     'insertFinalNewline',
    trim_final_newlines:      'trimFinalNewlines',
  }.freeze

  attr_reader :lsp_client

  # Upstream's format(): request a full-document edit from the language
  # server and apply it. Every upstream language comment notes its server
  # "doesn't support diff — it just returns one edit" and saves the cursor
  # around applying it; lib/lsp_sourceview.rb already stages every edit
  # through Gtk::TextMarks, which keeps the cursor where the surrounding text
  # puts it regardless of how many edits come back, so none of the per-
  # language cursor save/restore upstream repeats is needed here.
  def format
    if lsp_client&.ready?
      LspSourceview.apply_text_edits(request_formatting, buffer)
    end
    self
  rescue Lsp::LspError, IOError, Errno::EPIPE => error
    warn("#{language.id} format failed: #{error.message}")
    self
  end

  private

    # Called from each subclass's `initialize`, after `super`, matching
    # upstream's `constructor(...args) { super(...args); this.lspc =
    # setup({ document: this }); }`.
    def start_lsp_client
      @lsp_client = LspClient.new(
        language.language_server,
        root_uri:    "file://#{File.dirname(path)}",
        language_id: language.id,
      )
      @lsp_client.buffer = buffer
      @lsp_client.uri = uri
      @lsp_client.on_notification('textDocument/publishDiagnostics') { |params| handle_diagnostics(params) }
      @lsp_client.start
      # Connected now, before Document#start ever connects its own
      # `modified-changed` listener for #save: that listener clears
      # `buffer.modified?` synchronously, and this port's signal handlers (unlike
      # upstream's async save) run to completion before the next one is
      # called, so a `didChange` listener connected after it would never see
      # the buffer as modified. Connecting here, at construction, puts this
      # handler first in line for every emission.
      buffer.signal_connect('modified-changed') do
        if buffer.modified?
          @lsp_client.did_change
        end
      end
      self
    rescue StandardError => error
      warn("#{language.id} language server unavailable: #{error.message}")
      @lsp_client = nil
    end

    def handle_diagnostics(params)
      if params[:uri] == uri
        code_view.handle_diagnostics(params[:diagnostics])
      end
    end

    def request_formatting
      lsp_client.request(
        'textDocument/formatting',
        textDocument: { uri: uri },
        options:      lsp_formatting_options,
      )
    end

    def lsp_formatting_options
      LSP_OPTION_NAMES.filter_map do |key, name|
        if language.formatting_options.key?(key)
          [name, language.formatting_options[key]]
        end
      end.to_h
    end
end
