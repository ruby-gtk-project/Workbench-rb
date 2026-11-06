# frozen_string_literal: true

require 'open3'
require 'json'
require 'timeout'

require_relative 'lsp'
require_relative 'workbench/rb/version'

# LspClient is a JSON-RPC client over stdio for one spawned language server
# process, ported from upstream's src/lsp/LSPClient.js.
#
# Upstream's client is asynchronous throughout: GJS subprocess pipes read with
# promises, an EventEmitter mixin (`input`/`output`/`exit`/
# `notification::<method>`/`result::<id>`) so #request can be awaited while
# other notifications keep arriving, and callers chain `.catch(console.error)`
# onto every call. This port's callers are already synchronous top to bottom —
# `Document#format`, `Previewer#update` — so #request simply writes the
# message and blocks on this process's stdout until the matching response
# comes back, discarding or dispatching whatever else arrives while it waits.
# Lost in the simplification: concurrent in-flight requests, and the `input`/
# `output`/`exit` events upstream logs with when `quiet: false`.
class LspClient
  HEADER_PATTERN = /\AContent-Length: (\d+)\s*\z/i

  # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#clientCapabilities
  CAPABILITIES = {
    textDocument: {
      publishDiagnostics: {},
      completion:         {},
    },
  }.freeze

  CLIENT_INFO = {
    name:    'Workbench',
    version: Workbench::Rb::Version::VERSION,
  }.freeze

  REQUEST_TIMEOUT = 10

  def initialize(argv, root_uri:, language_id:, env: {})
    @argv = Array(argv)
    @root_uri = root_uri
    @language_id = language_id
    @env = env
    @version = 0
    @id = 0
    @ready = false
    @notification_callbacks = Hash.new { |hash, key| hash[key] = [] }
    @server_capabilities = nil
  end

  attr_accessor :buffer, :uri
  attr_reader :server_capabilities

  def ready? = @ready

  # Upstream's start(): spawn, initialize, didOpen.
  def start
    spawn_process
    initialize_server
    did_open
    @ready = true
    self
  end

  def stop
    unless @stdin&.closed?
      @stdin&.close
    end
    unless @stdout&.closed?
      @stdout&.close
    end
    if @wait_thread&.alive?
      Process.kill('TERM', @wait_thread.pid)
      @wait_thread.join(1)
    end
    @ready = false
    self
  rescue Errno::ESRCH
    self
  end

  def on_notification(method, &block)
    @notification_callbacks[method] << block
    block
  end

  def notify(method, params = {})
    send_message(method: method, params: params)
    drain_notifications
    self
  end

  def request(method, params = {})
    send_message(id: next_id, method: method, params: params).then do |id|
      await_response(id)
    end
  end

  def did_change
    @version += 1
    notify(
      'textDocument/didChange',
      textDocument:   { uri: uri, version: @version },
      contentChanges: [{ text: buffer.text }],
    )
  end

  private

    def spawn_process
      @stdin, @stdout, _stderr, @wait_thread = Open3.popen3(@env, *@argv)
      @stdin.sync = true
    end

    def initialize_server
      request(
        'initialize',
        processId:    Process.pid,
        clientInfo:   CLIENT_INFO,
        capabilities: CAPABILITIES,
        rootUri:      @root_uri,
        locale:       'en',
      ).then do |result|
        @server_capabilities = result[:capabilities]
        notify('initialized', {})
        result
      end
    end

    def did_open
      notify(
        'textDocument/didOpen',
        textDocument: {
          uri:        uri,
          languageId: @language_id,
          version:    @version,
          text:       buffer.text,
        },
      )
    end

    def next_id
      @id += 1
    end

    def send_message(message)
      message.merge(jsonrpc: '2.0').to_json.then do |body|
        @stdin.write("Content-Length: #{body.bytesize}\r\n\r\n#{body}")
      end
      message[:id]
    end

    # Blocks on this process's stdout until the response for `id` arrives,
    # dispatching every notification seen along the way to whoever
    # registered for it — upstream's `_onmessage`, folded into the wait.
    def await_response(id)
      Timeout.timeout(REQUEST_TIMEOUT, Lsp::LspError.new(message: "#{@language_id} language server timed out")) do
        loop do
          message = read_message
          if message[:id] == id
            break (message[:error] ? raise_error(message[:error]) : message[:result])
          elsif message[:method]
            dispatch(message)
          end
        end
      end
    end

    # Upstream's #notify has nothing to wait for, but a diagnostics push can
    # already be sitting on the pipe by the time the caller moves on, so
    # whatever is readable right now is drained without blocking for more.
    def drain_notifications
      while @stdout && !@stdout.closed? && IO.select(
        [@stdout],
        nil,
        nil,
        0,
      )
        message = read_message
        unless message
          break
        end

        if message[:method]
          dispatch(message)
        end
      end
    end

    def dispatch(message)
      @notification_callbacks[message[:method]].each { |callback| callback.call(message[:params]) }
    end

    def raise_error(error)
      raise Lsp::LspError.new(message: error[:message], code: error[:code], data: error[:data])
    end

    def read_message
      read_headers.then do |headers|
        headers['Content-Length'].then do |length|
          length && JSON.parse(@stdout.read(length.to_i), symbolize_names: true)
        end
      end
    end

    def read_headers
      {}.tap do |headers|
        loop do
          line = @stdout.gets&.chomp
          if line.nil? || line.empty?
            break
          end

          line.match(HEADER_PATTERN).then do |match|
            if match
              headers['Content-Length'] = match[1]
            end
          end
        end
      end
    end
end
