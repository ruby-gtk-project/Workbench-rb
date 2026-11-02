# frozen_string_literal: true

require 'adwaita'

require_relative 'workbench/rb/version'

# AboutDialog is the About window, ported from upstream's src/about.js.
#
# The credits are upstream's, unchanged. The debug info block is the same
# shape: the app and its version, the host OS, then the versions of the
# runtime and the libraries it is built against. Upstream reports GJS, Adw,
# GTK, GLib, Flatpak and Vala; the port reports the Ruby runtime and the
# library versions the bindings expose, and the Flatpak and Vala lines are
# absent because the port is neither sandboxed nor compiled.
class AboutDialog
  APPLICATION_ID = 'org.rubygtkproject.Workbench'

  DEVELOPERS = [
    'Sonny Piers https://sonny.re',
    'Lorenz Wildberg https://gitlab.gnome.org/lwildberg',
    'Andy Holmes https://gitlab.gnome.org/andyholmes',
    'Julian Hofer https://julianhofer.eu/',
    'Marco Köpcke https://github.com/theCapypara',
  ].freeze

  DESIGNERS = [
    'Sonny Piers https://sonny.re',
    'Tobias Bernard <tbernard@gnome.org>',
    'Brage Fuglseth https://bragefuglseth.dev',
  ].freeze

  ARTISTS = [
    'Tobias Bernard <tbernard@gnome.org>',
    'Jakub Steiner https://jimmac.eu',
    'Brage Fuglseth https://bragefuglseth.dev',
  ].freeze

  CONTRIBUTORS = [
    'Akshay Warrier https://github.com/AkshayWarrier',
    'Ben Foote http://www.bengineeri.ng',
    'Brage Fuglseth https://bragefuglseth.dev',
    'Hari Rana (TheEvilSkeleton) https://theevilskeleton.gitlab.io',
    'Sriyansh Shivam https://linktr.ee/sonic_here',
    'Angelo Verlain https://www.vixalien.com',
    'bazylevnik0 https://github.com/bazylevnik0',
    'Felipe Kinoshita https://mastodon.social/@fkinoshita',
    'Karol Lademan https://github.com/karl0d',
    'Nasah Kuma https://www.mantohnasah.com/',
    'Jose Hunter https://github.com/halfmexican/',
    'Akunne Pascal https://github.com/Kodecheff',
    'JCWasmx86 https://github.com/JCWasmx86',
    'Alex (PaladinDev) https://github.com/SpikedPaladin',
    'Diego Iván M.E https://github.com/Diego-Ivan',
    'Rasmus Thomsen <oss@cogitri.dev>',
    'Marvin W https://github.com/mar-v-in',
    'Saad Khan https://github.com/saadulkh',
    'Adeel Ahmed Qureshi https://github.com/itsAdee',
    'Muhammad Bilal https://github.com/mbilal234',
    'Onkar https://github.com/onkarrai06',
    'Sabrina Meindlhumer https://github.com/m-sabrina',
    'Urtsi Santsi <urtsi.santsi@proton.me>',
    'Roland Lötscher https://github.com/rolandlo',
    'Gregor Niehl https://fosstodon.org/@gregorni',
    'Jamie Gravendeel https://jamie.garden',
    'Bharat Tyagi https://github.com/BharatAtbrat',
    'Jan Fooken https://git.janvhs.com',
    'Vladimir Vaskov https://github.com/Rirusha',
    'Nokse https://github.com/Nokse22',
  ].freeze

  def initialize(application)
    @application = application
  end

  attr_reader :application

  def build
    dialog.tap do |about|
      about.add_credit_section('Contributors', CONTRIBUTORS)
    end
  end

  def present = build.present(application.active_window)

  def dialog
    @dialog ||= Adwaita::AboutDialog.new.tap do |about|
      about.application_name = 'Workbench'
      about.developer_name = 'Sonny Piers'
      about.copyright = '© 2022 Sonny Piers'
      about.license_type = :gpl_3_0_only
      about.version = Workbench::Rb::VERSION
      about.website = 'https://workbench.sonny.re'
      about.application_icon = APPLICATION_ID
      about.issue_url = 'https://workbench.sonny.re/feedback'
      about.debug_info = debug_info
      about.developers = DEVELOPERS
      about.designers = DESIGNERS
      about.artists = ARTISTS
    end
  end

  def debug_info
    [
      "Workbench #{Workbench::Rb::VERSION}",
      os_info,
      '',
      "Ruby #{RUBY_VERSION}",
      "Adw #{adwaita_version}",
      "GTK #{Gtk::Version::STRING}",
      "GLib #{GLib::Version::STRING}",
    ].join("\n")
  end

  private

    def adwaita_version
      [Adwaita::MAJOR_VERSION, Adwaita::MINOR_VERSION, Adwaita::MICRO_VERSION].join('.')
    end

    # Upstream reads ID and VERSION_ID out of GLib.get_os_info.
    def os_info
      [GLib.get_os_info('ID'), GLib.get_os_info('VERSION_ID')].compact.join(' ').strip
    end
end
