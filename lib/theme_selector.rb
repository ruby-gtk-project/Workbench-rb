# frozen_string_literal: true

require 'adwaita'

# ThemeSelector is the row of three theme buttons at the top of the primary
# menu, ported from troll/src/widgets/ThemeSelector.js.
#
# troll is a git submodule and its sources are not in this repository, so the
# widget is written from what the rest of upstream requires of it: the
# `color-scheme` key of data/app.gschema.xml is an integer holding an
# Adw.ColorScheme value, src/actions.js exposes it as the stateful application
# action `app.color-scheme`, and src/window.blp slots the widget into the
# `themeswitcher` custom item of the primary menu. The three choices are the
# ones that key can hold: follow the system, force light, force dark.
class ThemeSelector
  FOLLOW = 0  # Adw.ColorScheme.DEFAULT
  LIGHT = 1   # Adw.ColorScheme.FORCE_LIGHT
  DARK = 4    # Adw.ColorScheme.FORCE_DARK

  SCHEMES = {
    FOLLOW => :default,
    LIGHT  => :force_light,
    DARK   => :force_dark,
  }.freeze

  def initialize(settings)
    @settings = settings
  end

  attr_reader :settings

  def build
    box.tap do |b|
      b.append(button_follow)
      b.append(button_light)
      b.append(button_dark)

      buttons.each do |value, button|
        unless button == button_follow
          button.group = button_follow
        end
        button.signal_connect('toggled') do |this|
          if this.active?
            apply(value)
          end
        end
      end

      settings.on_change('color-scheme') { |value| select(value.to_i) }
      select(settings.get_int('color-scheme'))
    end
  end

  # Applies the stored scheme without touching the buttons, so the application
  # starts in the theme the user last chose.
  def apply_stored = apply(settings.get_int('color-scheme'))

  def box
    @box ||= Gtk::Box.new(:horizontal, 12).tap do |b|
      b.halign = :center
      b.margin_top = 6
      b.margin_bottom = 6
      b.margin_start = 12
      b.margin_end = 12
    end
  end

  private

    def buttons
      @buttons ||= {
        FOLLOW => button_follow,
        LIGHT  => button_light,
        DARK   => button_dark,
      }
    end

    def button_follow = @button_follow ||= theme_button('System', 'display-brightness-symbolic')
    def button_light = @button_light ||= theme_button('Light', 'weather-clear-symbolic')
    def button_dark = @button_dark ||= theme_button('Dark', 'weather-clear-night-symbolic')

    def theme_button(tooltip, icon_name)
      Gtk::CheckButton.new.tap do |button|
        button.tooltip_text = tooltip
        button.child = Gtk::Image.new(icon_name: icon_name)
        button.add_css_class('theme-selector')
      end
    end

    def select(value)
      buttons.fetch(value, button_follow).then do |button|
        unless button.active?
          button.active = true
        end
      end
    end

    def apply(value)
      settings.set_int('color-scheme', value)
      Adwaita::StyleManager.default.color_scheme = SCHEMES.fetch(value, :default)
    end
end
