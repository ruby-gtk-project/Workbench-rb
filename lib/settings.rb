# frozen_string_literal: true

require 'json'
require 'fileutils'

# Settings holds the keys of upstream's two GSettings schemas,
# data/app.gschema.xml: the application schema (`re.sonny.Workbench`) and the
# per-session schema (`re.sonny.Workbench.Session`).
#
# Upstream reaches them through Gio.Settings — the application schema from the
# system schema directory, the session schema through a keyfile backend rooted
# at `<session>/settings`. A compiled schema has to be installed before the app
# can start, which makes running the port from a checkout awkward, so the same
# keys, defaults and change notifications are backed by a small JSON file: one
# under XDG_CONFIG_HOME for the application schema, and `settings.json` inside
# the session directory for the session schema.
#
# The `enum` key `user-interface-language` keeps upstream's nick/value pairing,
# so `#get_enum` returns the index and `#[]` the nick, as Gio.Settings does.
class Settings
  APP_DEFAULTS = {
    'color-scheme'         => 0,
    'recent-code-language' => 0,
    'recent-projects'      => [],
    'first-run'            => true,
    'typescript'           => false,
  }.freeze

  SESSION_DEFAULTS = {
    'show-code'               => false,
    'show-style'              => false,
    'name'                    => '',
    'show-ui'                 => true,
    'show-preview'            => true,
    'show-console'            => true,
    'code-language'           => 0,
    'user-interface-language' => 'blueprint',
    'preview-align'           => 0,
    'auto-preview'            => true,
    'safe-mode'               => false,
    'edited'                  => false,
    'window-width'            => 0,
    'window-height'           => 0,
    'window-maximized'        => false,
    'window-fullscreened'     => false,
  }.freeze

  # The <enum id="re.sonny.Workbench.UserInterfaceLanguage"> nicks, in value
  # order, so an enum key converts between nick and index.
  ENUMS = {
    'user-interface-language' => %w[blueprint xml],
  }.freeze

  def self.app
    @app ||= new(
      path:     File.join(config_dir, 'settings.json'),
      defaults: APP_DEFAULTS,
    )
  end

  def self.for_session(directory)
    new(
      path:     File.join(directory, 'settings.json'),
      defaults: SESSION_DEFAULTS,
    )
  end

  def self.config_dir
    File.join(
      ENV['XDG_CONFIG_HOME'] || File.join(Dir.home, '.config'),
      'Workbench',
    )
  end

  def initialize(path:, defaults:)
    @path = path
    @defaults = defaults
    @values = defaults.merge(read)
    @listeners = []
    @delayed = nil
  end

  attr_reader :path, :defaults

  def [](key) = @values.fetch(key.to_s, @defaults[key.to_s])

  def []=(key, value)
    key.to_s.then do |name|
      @values[name] = value
      if @delayed
        @delayed << name
      else
        write
        notify(name)
      end
    end
    value
  end

  def get_boolean(key) = self[key] == true
  def get_int(key) = self[key].to_i
  def get_string(key) = self[key].to_s
  def get_strv(key) = Array(self[key]).map(&:to_s)

  def set_boolean(key, value) = self[key] = (value == true)
  def set_int(key, value) = self[key] = value.to_i
  def set_string(key, value) = self[key] = value.to_s
  def set_strv(key, value) = self[key] = Array(value).map(&:to_s)

  # Gio.Settings.get_enum returns the value of the nick currently stored.
  def get_enum(key) = ENUMS.fetch(key.to_s).index(get_string(key)) || 0

  def set_enum(key, index)
    set_string(key, ENUMS.fetch(key.to_s).fetch(index))
  end

  # Upstream's settings.delay()/settings.apply() pair, used when a demo is
  # copied into a new session and a run of keys is written at once.
  def delay = @delayed = []

  def apply
    (@delayed || []).uniq.then do |keys|
      @delayed = nil
      write
      keys.each { |key| notify(key) }
    end
  end

  # Mirrors `settings.connect("changed::<key>")` and `settings.connect("changed")`:
  # a nil key listens to every key.
  def on_change(key = nil, &block)
    @listeners << [key&.to_s, block]
    block
  end

  # Mirrors settings.bind(key, object, property, DEFAULT): the property takes
  # the stored value now, a change to either side updates the other.
  def bind(key, object, property)
    object.set_property(property.to_s.tr('_', '-'), self[key])
    object.signal_connect("notify::#{property.to_s.tr('_', '-')}") do |obj|
      obj.get_property(property.to_s.tr('_', '-')).then do |value|
        unless self[key] == value
          self[key] = value
        end
      end
    end
    on_change(key) do |value|
      unless object.get_property(property.to_s.tr('_', '-')) == value
        object.set_property(property.to_s.tr('_', '-'), value)
      end
    end
  end

  # Upstream's settings.create_action(key) — a stateful action whose state is
  # the boolean key, so a menu item can toggle it.
  def create_action(key)
    Gio::SimpleAction.new(key.to_s, nil, GLib::Variant.new(get_boolean(key))).tap do |action|
      action.signal_connect('activate') do |this, _parameter|
        set_boolean(key, !get_boolean(key))
        this.set_state(GLib::Variant.new(get_boolean(key)))
      end
      on_change(key) { |value| action.set_state(GLib::Variant.new(value == true)) }
    end
  end

  private

    def notify(key)
      @listeners.each do |listened, block|
        if listened.nil? || listened == key
          block.call(self[key])
        end
      end
    end

    def read
      File.exist?(@path) ? JSON.parse(File.read(@path)) : {}
    rescue JSON::ParserError, SystemCallError
      {}
    end

    def write
      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, "#{JSON.pretty_generate(@values)}\n")
    end
end
