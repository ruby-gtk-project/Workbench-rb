# frozen_string_literal: true

# Language is the table upstream keeps in src/common.js as `languages`, with
# the lookup helper `getLanguage` beside it.
#
# Each entry describes one of the languages a session can hold: which panel it
# belongs to, the file it lives in inside the session directory, the extensions
# and mime types that identify it, the language server upstream starts for it,
# and the formatting options it is formatted with. `index` is the position in
# the code panel's language dropdown, and is absent for the languages that
# belong to the UI and style panels.
class Language
  FORMATTING_OPTIONS = {
    insert_spaces:            true,
    trim_trailing_whitespace: true,
    insert_final_newline:     true,
    trim_final_newlines:      true,
  }.freeze

  ATTRIBUTES = %i[
    id name panel extensions types default_file index language_server
    formatting_options
  ].freeze

  attr_reader(*ATTRIBUTES)

  def initialize(**attributes)
    ATTRIBUTES.each do |name|
      instance_variable_set(:"@#{name}", attributes[name])
    end
    @extensions = Array(@extensions).freeze
    @types = Array(@types).freeze
    @language_server = Array(@language_server).freeze
    @formatting_options = (@formatting_options || {}).freeze
    freeze
  end

  # The code panel's dropdown lists these by name, in `index` order.
  def code_panel? = panel == 'code'

  ALL = [
    new(
      id:                 'blueprint',
      name:               'Blueprint',
      panel:              'ui',
      extensions:         ['.blp'],
      types:              [],
      default_file:       'main.blp',
      language_server:    %w[blueprint-compiler lsp],
      formatting_options: FORMATTING_OPTIONS.merge(tab_size: 2),
    ),
    new(
      id:           'xml',
      name:         'GTK Builder',
      panel:        'ui',
      extensions:   ['.ui'],
      types:        ['application/x-gtk-builder'],
      default_file: 'main.ui',
    ),
    new(
      id:                 'javascript',
      name:               'JavaScript',
      panel:              'code',
      extensions:         %w[.js .mjs],
      types:              ['text/javascript', 'application/javascript'],
      default_file:       'main.js',
      index:              0,
      language_server:    %w[biome lsp-proxy],
      formatting_options: FORMATTING_OPTIONS.merge(tab_size: 2),
    ),
    new(
      id:                 'css',
      name:               'CSS',
      panel:              'style',
      extensions:         ['.css'],
      types:              ['text/css'],
      default_file:       'main.css',
      language_server:    %w[gtkcsslanguageserver],
      formatting_options: FORMATTING_OPTIONS.merge(tab_size: 2),
    ),
    new(
      id:                 'vala',
      name:               'Vala',
      panel:              'code',
      extensions:         ['.vala'],
      types:              ['text/x-vala'],
      default_file:       'main.vala',
      index:              1,
      language_server:    %w[vala-language-server],
      formatting_options: FORMATTING_OPTIONS.merge(tab_size: 4),
    ),
    new(
      id:                 'rust',
      name:               'Rust',
      panel:              'code',
      extensions:         ['.rs'],
      types:              ['text/x-rust'],
      default_file:       'code.rs',
      index:              2,
      language_server:    %w[rust-analyzer],
      formatting_options: FORMATTING_OPTIONS.merge(tab_size: 4),
    ),
    new(
      id:                 'python',
      name:               'Python',
      panel:              'code',
      extensions:         ['.py'],
      types:              ['text/x-python'],
      default_file:       'main.py',
      index:              3,
      language_server:    %w[pylsp -v],
      formatting_options: FORMATTING_OPTIONS.merge(tab_size: 4),
    ),
    new(
      id:                 'typescript',
      name:               'TypeScript',
      panel:              'code',
      extensions:         %w[.ts .mts],
      types:              [],
      default_file:       'main.ts',
      index:              4,
      language_server:    ['typescript-language-server', '--stdio'],
      formatting_options: FORMATTING_OPTIONS.merge(tab_size: 2),
    ),
  ].freeze

  # Upstream's getLanguage(id) — case-insensitive on the id.
  def self.[](id)
    ALL.find { |language| language.id.casecmp?(id.to_s) }
  end

  def self.by_index(index)
    ALL.find { |language| language.code_panel? && language.index == index }
  end

  # The UI panel's dropdown lists these two, in this order.
  def self.ui = [self['blueprint'], self['xml']].freeze

  def self.code = ALL.select(&:code_panel?).sort_by(&:index).freeze
end
