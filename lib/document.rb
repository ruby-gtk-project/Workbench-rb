# frozen_string_literal: true

require 'fileutils'

require_relative 'language'

# Document binds one CodeView to one file inside the session, ported from
# upstream's src/Document.js.
#
# The file is the language's `default_file` in the session directory. The
# document saves whenever the buffer is modified — which also marks the session
# as edited, so closing it asks whether to keep it — and loads the file into
# the buffer on demand, tolerating a file that is not there yet.
#
# Upstream reads and writes through GtkSource.FileLoader and
# GtkSource.FileSaver, which handle encoding detection and atomic replacement.
# The GtkSourceView bindings are not available to the port, so the file is read
# and written directly, as UTF-8.
class Document
  def initialize(session:, code_view:, language:)
    @session = session
    @code_view = code_view
    @language = language
    @handler = nil
  end

  attr_reader :session, :code_view, :language

  def path = session.file_for(language)

  def uri = "file://#{path}"

  def buffer = code_view.buffer

  def save
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, buffer.text)
    buffer.modified = false
    session.settings.set_boolean('edited', true)
    self
  end

  def load
    if File.exist?(path)
      buffer.text = File.read(path)
    else
      buffer.text = ''
    end
    buffer.modified = false
    self
  end

  # While started, every modification of the buffer is written back.
  def start
    stop
    @handler = buffer.signal_connect('modified-changed') do |this|
      if this.modified?
        save
      end
    end
    self
  end

  def stop
    if @handler
      buffer.signal_handler_disconnect(@handler)
      @handler = nil
    end
    self
  end

  # Upstream's base Document#format does nothing; each language overrides it
  # with a request to its language server.
  def format = self
end
