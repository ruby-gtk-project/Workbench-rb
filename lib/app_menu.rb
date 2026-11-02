# frozen_string_literal: true

require 'gio2'

# AppMenu is the primary menu behind the header bar's hamburger button, ported
# from the `menu menu_app` definition in upstream's src/window.blp.
#
# The first section is the custom item the theme selector is slotted into; the
# popover that shows this model has to call `add_child(widget,
# "themeswitcher")` for it to appear, which lib/window.rb does.
class AppMenu
  THEME_SWITCHER = 'themeswitcher'

  BOOKMARKS_LEARN = {
    'API References'             => 'https://apps.gnome.org/Biblioteca/',
    'Developer Documentation'    => 'https://developer.gnome.org/documentation/index.html',
    'Human Interface Guidelines' => 'https://developer.gnome.org/hig/',
    'JavaScript'                 => 'https://gjs.guide',
    'Vala'                       => 'https://wiki.gnome.org/Projects/Vala',
    'Rust'                       => 'https://gtk-rs.org',
    'Python'                     => 'https://pygobject.readthedocs.io',
    'Blueprint'                  => 'https://gnome.pages.gitlab.gnome.org/blueprint-compiler',
  }.freeze

  BOOKMARKS_HELP = {
    'Discourse' => 'https://discourse.gnome.org/c/platform/5',
    'Matrix'    => 'https://matrix.to/#/#workbench:gnome.org',
  }.freeze

  PLATFORM_TOOLS = {
    'Adwaita Demo'       => 'adwaita-1-demo',
    'GTK Demo'           => 'gtk4-demo',
    'GTK Widget Factory' => 'gtk4-widget-factory',
  }.freeze

  def model
    @model ||= Gio::Menu.new.tap do |menu|
      menu.append_section(nil, theme_section)
      menu.append_section(nil, projects_section)
      menu.append_item(item('Extensions', 'win.extensions'))
      menu.append_item(item('Permissions', 'win.permissions'))
      menu.append_section(nil, reveal_section)
      menu.append_section(nil, help_section)
    end
  end

  private

    def theme_section
      Gio::Menu.new.tap do |section|
        section.append_item(custom_item(THEME_SWITCHER))
      end
    end

    def projects_section
      Gio::Menu.new.tap do |section|
        section.append_item(item('New Project', 'app.new'))
        section.append_item(item('Open Project…', 'app.open', 'project'))
        section.append_submenu('Bookmarks', bookmarks_menu)
        section.append_submenu('Platform Tools', platform_tools_menu)
      end
    end

    def bookmarks_menu
      Gio::Menu.new.tap do |menu|
        menu.append_section('Learn', uri_section(BOOKMARKS_LEARN))
        menu.append_section('Get Help', uri_section(BOOKMARKS_HELP))
      end
    end

    def uri_section(entries)
      Gio::Menu.new.tap do |section|
        entries.each { |label, uri| section.append_item(item(label, 'app.open_uri', uri)) }
      end
    end

    def platform_tools_menu
      Gio::Menu.new.tap do |menu|
        PLATFORM_TOOLS.each do |label, tool|
          menu.append_item(item(label, 'app.platform_tools', tool))
        end
      end
    end

    def reveal_section
      Gio::Menu.new.tap do |section|
        section.append_item(item('Reveal in Files', 'win.reveal'))
      end
    end

    def help_section
      Gio::Menu.new.tap do |section|
        section.append_item(item('Keyboard Shortcuts', 'app.shortcuts'))
        section.append_item(item('About Workbench', 'app.about'))
      end
    end

    def item(label, action, target = nil)
      Gio::MenuItem.new(label).tap do |menu_item|
        if target
          menu_item.set_action_and_target_value(action, GLib::Variant.new(target))
        else
          menu_item.set_detailed_action(action)
        end
      end
    end

    # A `custom` attribute leaves a slot a widget can be added into.
    def custom_item(name)
      Gio::MenuItem.new.tap do |menu_item|
        menu_item.set_attribute_value('custom', GLib::Variant.new(name))
      end
    end
end
