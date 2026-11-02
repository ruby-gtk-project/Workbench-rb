# frozen_string_literal: true

require 'gtk4'

# Style carries the application stylesheet, ported from upstream's
# src/style.css. Upstream ships the file as a GResource and loads it in
# src/application.js; the port keeps the rules inline so the stylesheet travels
# with the code and needs no resource bundle.
#
# The rules are upstream's, unchanged: the `prefers-color-scheme` media query
# and the `var(--…)` Adwaita colour tokens are both understood by the GTK CSS
# parser the port builds against.
class Style
  CSS = <<~CSS
    .view-toggler image {
      margin-right: 6px;
    }

    .hoverdisplay {
      padding: 8px;
      border-radius: 10px;
    }

    .panel_header {
      padding-left: 12px;
      padding-right: 12px;
    }

    .command_snippet {
      color: var(--view-fg-color);
      background: var(--view-bg-color);
      font-family: monospace;
      border-radius: 6px;
      padding: 6px;
      border: 1px solid var(--border-color);
    }

    /*
     * From Builder's stylesheet, used to style the language tags for the demo
     * entries in the Library.
     */
    button.pill.small {
      font-size: 0.83333em;
      border-radius: 99px;
      margin: 0;
      padding: 1px 12px;
    }

    #panel_code,
    #panel_style,
    #panel_ui {
      border-right: solid 1px var(--border-color);
      background-color: #fcfcfc;
    }

    /* Prevent dev banner on second toolbar */
    #panel_code > revealer,
    #panel_style > revealer,
    #panel_ui > revealer,
    #panel_preview > revealer,
    #panel_devtools > revealer {
      background-image: none;
    }

    #toolbar_devtools {
      background-color: #fcfcfc;
    }

    @media (prefers-color-scheme: dark) {
      #panel_code,
      #panel_style,
      #panel_ui {
        background-color: #262626;
      }

      #toolbar_devtools {
        background-color: #262626;
      }
    }
  CSS

  # Installs the stylesheet on the display, at the same priority upstream uses.
  def self.install(display = Gdk::Display.default)
    new.install(display)
  end

  def install(display)
    display.then do |target|
      if target
        Gtk::StyleContext.add_provider_for_display(
          target,
          provider,
          Gtk::StyleProvider::PRIORITY_APPLICATION,
        )
      end
    end
    self
  end

  def provider
    @provider ||= Gtk::CssProvider.new.tap do |css|
      css.load_from_data(CSS)
    end
  end
end
