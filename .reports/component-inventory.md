# Workbench — upstream component inventory

Survey of `origin/main` (the GJS implementation) against `lib/` on `ruby`.
Read with the `component-identification` skill: a component is a widget plus
its CSS classes, its signals, the actions it installs and the file that owns
it. Upstream splits almost every component across a `.blp` and a `.js`; the
component is the pair, and the port collapses the pair into one `lib/*.rb`.

Upstream is a GJS app bundled by `gjspack` (no GResource manifest for the app
itself), with ten blueprint files, one C widget in `src/libworkbench/`, two
Vala previewer processes, and two git submodules that carry real UI and real
data (`troll/`, `demos/`).

House shape, from the pilot port at `gnome-contacts-rb`: one upstream source
file maps to one flat `lib/<thing>.rb` holding one top-level class, opening
with `# frozen_string_literal: true` then `require 'adwaita'`, each class
carrying a comment naming the upstream file it came from. Only the application
object lives under `lib/workbench/`.

## The map

`component-scan.sh` over an export of `origin/main`'s `src/` and `data/`
(submodules absent, so `troll/` and `demos/` contribute nothing):

| | upstream | `ruby` |
|---|---:|---:|
| widget occurrences | 2569 | 143 |
| distinct widget types | 117 | 49 |
| distinct CSS classes | 172 | 14 |
| distinct signals | 177 | 30 |
| distinct action names | 133 | 22 |

That is a measure of how much app is left, not an inventory — act on the
per-component sections below.

## Status

Re-checked against `lib/` at `f3be425`. The first porting pass
(`d878d16`, "Port the window, panels, previewer, documents and app actions")
landed twenty-five files and roughly 4,700 lines, so the scaffold line this
section used to carry is gone: the app now opens a real window with four
panels, an editor, a console, a previewer and the app menu.

**Ported (24 files + the application object):** `lib/workbench/application.rb`,
`actions.rb`, `about_dialog.rb`, `shortcuts_window.rb`, `window.rb`,
`app_menu.rb`, `theme_selector.rb`, `panel_code.rb`, `panel_style.rb`,
`panel_ui.rb`, `panel_preview.rb`, `previewer.rb`, `internal_previewer.rb`,
`devtools.rb`, `term_console.rb`, `code_view.rb`, `code_find.rb`,
`save_project_dialog.rb`, `blueprint_experimental_dialog.rb`, `settings.rb`,
`session.rb`, `document.rb`, `language.rb`, `style.rb`, plus `xml.rb` and
`xml_document.rb` for the UI panel's XML path.

**Not ported at all — five user-facing units and their rows:** the Library
window and its demo rows, the Extensions dialog and its rows, the Permissions
dialog, the diagnostic hover provider, and the windowed preview window from
`src/libworkbench`. Behind them: the out-of-process previewer (External +
D-Bus + the two Vala programs), the LSP client, and seven of the eight
language documents (only `xml_document.rb` exists, so there is no formatting,
no compiling, no diagnostics and no language server for JavaScript,
TypeScript, Vala, Rust, Python, Blueprint or CSS).

**Ported with a known substitution**, because the dev shell has neither
GtkSourceView nor Vte bindings: `code_view.rb` is a `Gtk::TextView` where
upstream has a `GtkSource.View` (no syntax highlighting, no style schemes, no
completion), `code_find.rb` searches the buffer itself instead of using
`GtkSource.SearchContext`, `term_console.rb` is a read-only text view rather
than a `Vte.Terminal` tailing a log, `shortcuts_window.rb` is an
`Adw.ShortcutsDialog` rather than the deprecated `Gtk.ShortcutsWindow`, and
`internal_previewer.rb` cannot install a custom `Gtk.BuilderScope`, so a
`<signal>` in a previewed definition is not connected. Each of those is a
parity gap recorded in the file's own header comment, not an omission to
rediscover.

## Declarative roots — the unit list

Only two of upstream's blueprint roots are `template`s; the rest are top-level
named objects destructured by `troll`'s `build()` helper, plus three
`menu` models and one `Adw.AlertDialog` that lives beside the window.

| Blueprint | Root | Kind |
|---|---|---|
| `src/window.blp` | `Adw.ApplicationWindow window` | named root |
| `src/window.blp` | `Adw.Dialog dialog_blueprint_experimental` | named root |
| `src/window.blp` | `Adw.AlertDialog alert_dialog_save_project` | named root |
| `src/window.blp` | `Button button_location` | named root (re-parented at runtime) |
| `src/window.blp` | `menu menu_app`, `menu preview_menu`, `menu menu_console` | menu models |
| `src/shortcutsWindow.blp` | `ShortcutsWindow window` | named root |
| `src/Library/Library.blp` | `Adw.Window window` | named root |
| `src/Library/EntryRow.blp` | `template $EntryRow : Adw.ActionRow` | template |
| `src/Extensions/Extensions.blp` | `Adw.Dialog dialog` | named root |
| `src/Extensions/Extension.blp` | `template $Extension : Gtk.ListBoxRow` | template |
| `src/Permissions/Permissions.blp` | `Adw.Dialog dialog` | named root |
| `src/widgets/CodeView.blp` | `template $CodeView : Gtk.Widget` | template |
| `src/widgets/CodeFind.blp` | `template $CodeFind : Gtk.Revealer` | template |
| `src/libworkbench/workbench-preview-window.blp` | `template $WorkbenchPreviewWindow : Adw.Window` | template (C) |

## Components, in the order a user meets them

### `src/application.js` — the application object

`Adw.Application` with `HANDLES_OPEN`, `resource_base_path`
`/re/sonny/Workbench`. Registers nineteen custom symbolic icons into the icon
theme's `resource_path`, narrows `search_path` to `/usr/share/icons` and
`/app/share/icons`, follows `color-scheme` from GSettings into
`Adw.StyleManager`, spawns the `biome` LSP server on `startup` and kills it on
`shutdown`, restores saved sessions, and on first run opens the `Welcome`
demo maximized. `open` with hint `project` opens a project window.

→ `lib/workbench/application.rb` — **ported.** Stylesheet, colour scheme, actions and session reopening are there; the icon registration, the `biome` LSP spawn, `HANDLES_OPEN`, and the first-run Welcome demo are not.

### `src/actions.js` — application actions and accelerators

No widgets; eight actions and the accelerators that reach them. Everything in
`menu_app` outside the window's own scope fires from here.

| Action | Parameter | Accel | Does |
|---|---|---|---|
| `app.quit` | — | `<Control>Q` | quits |
| `app.about` | — | — | presents the About dialog |
| `app.open_uri` | `s` | — | `Gtk.UriLauncher` on the target |
| `app.platform_tools` | `s` | — | spawns `adwaita-1-demo` / `gtk4-demo` / `gtk4-widget-factory`, whitelisted |
| `app.color-scheme` | from GSettings | — | the theme switcher's radio state |
| `app.new` | — | `<Control>N` | new session window |
| `app.open` | `s` | `<Control>O` (as `app.open('project')`) | `Gtk.FileDialog.select_folder` |
| `app.show-screenshot` | `s` | — | opens the screenshot's folder via the XDG portal |
| `app.library` | — | `<Control><Shift>O` | installed in `Library.js` |
| `app.shortcuts` | — | `<Control>question` | installed in `shortcutsWindow.js` |

→ `lib/actions.rb` — **ported.** All eight actions, with the portal calls replaced by `Gtk::FileLauncher`.

### `src/about.js` — About dialog

`Adw.AboutDialog`: application name, developer, copyright, GPL-3.0-only,
website, `issue_url`, five developers, three designers, three artists, a
`Contributors` credit section of thirty names, and a `debug_info` block built
at runtime from `pkg.version`, `GLib.get_os_info`, the GJS / Adw / GTK / GLib
versions, the Flatpak version out of `.flatpak-info` and `valac --version`.

→ `lib/about_dialog.rb` — **ported.**

### `src/shortcutsWindow.blp` + `src/shortcutsWindow.js` — keyboard shortcuts

One `Gtk.ShortcutsWindow`, `hide-on-close`, one section, three groups,
twenty-one shortcuts. Built lazily on first `app.shortcuts` activation and
re-presented as transient for the active window thereafter.

| Group | Shortcuts |
|---|---|
| Application | Run Code `<Control>Return`, Format `<Control><Shift>Return`, New Project `<Control>N`, Open Project `<Control>O`, Open Library `<Control><Shift>O`, Inspector `<Control><Shift>I`, Close Window `<Control>W`, Reveal in Files `<Control>M`, Keyboard Shortcuts `<Control>question`, Quit `<Control>Q` |
| Editor | Cut, Copy, Paste, Find `<Control>F`, Undo, Show code suggestions `<Control>space`, Redo |
| Console | Toggle Console `<Control><Shift>K`, Copy `<Control><Shift>C`, Select All `<Control><Shift>A`, Clear `<Control>K` |

Note `Gtk.ShortcutsWindow` is deprecated in GTK 4.18; the port should decide
between it and `Adw.ShortcutsDialog` (the pilot port used the latter).

→ `lib/shortcuts_window.rb` — **ported**, as an `Adw.ShortcutsDialog`: `Gtk::ShortcutsWindow` cannot be constructed from Ruby. Same three groups, same twenty-one accelerators.

### `src/window.blp` + `src/window.js` — the main window

1920×1200 `Adw.ApplicationWindow`, `.devel` class on the devel build, titled
`Workbench — <session name>`, window geometry persisted through
`troll`'s `persistWindowState` into the session schema.

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (devel build only) | `close-request` → `onCloseSession`, returns `true` | holds `win.*` actions |
| `Adw.ToolbarView` | 1 | — | — | `top-bar-style: raised` |
| `Gtk.HeaderBar` | 1 | — | — | |
| `Gtk.Button button_library` | 1 | — | `action-name: app.library` | `Adw.ButtonContent`, tooltip names Ctrl+Shift+O |
| `Gtk.ToggleButton` | 4 | `flat`, `view-toggler` | bound to `show-code` / `show-style` / `show-ui` / `show-preview`; each `bind_property("active" → panel "visible")` | Code, Style, UI, Preview; each an `Image` + mnemonic `Label` in a `Box` |
| `Gtk.MenuButton button_menu` | 1 | — | `menu-model: menu_app`, `primary: true` | popover gets a `ThemeSelector` child under the `themeswitcher` custom slot |
| `Gtk.Button button_run` | 1 | `suggested-action` | `action-name: win.run` | desensitised while running |
| `Adw.ToastOverlay toast_overlay` | 1 | — | — | present but never used |
| `Gtk.Paned paned` | 1 | — | `notify::position` (after) drives collapse/uncollapse | vertical; panels over devtools |
| `Gtk.Box panel_placeholder` | 1 | `#placeholder` | visibility recomputed on any settings change | 512px `re.sonny.Workbench-placeholder-symbolic` when all four panels are hidden |

Window-scope actions installed here: `win.run` (`<Control>Return`),
`win.format` (`<Control><Shift>Return`), `win.close` (`<Control>W`),
`win.reveal` (`<Control>M`), plus `win.safe-mode` and `win.auto-preview` as
GSettings actions. `win.console`, `win.clear`, `win.console_copy`,
`win.console_select_all` come from Devtools/TermConsole;
`win.extensions` and `win.permissions` from their dialogs.

`window.js` also owns the eight `Document` objects (one per language), the run
pipeline (format → compile → preview, with per-language branches that bounce to
the Extensions dialog when Vala/Rust/TypeScript are unavailable and to the
Permissions dialog when Rust needs the network), and
`gtk-application-prefer-dark-theme` mirroring into
`~/.config/gtk-4.0/settings.ini` for the Platform Tools.

→ `lib/window.rb` — **ported** (473 lines): the toolbar view, the four togglers, the placeholder, the paned, the window-scope actions and the run pipeline. The per-language branches that divert to Extensions and Permissions have nowhere to go yet, and the `gtk-4.0/settings.ini` mirroring for Platform Tools is absent.

### `src/window.blp` `menu menu_app` — the main menu

Six sections, two submenus, one custom slot. Items: the `themeswitcher`
custom slot; New Project, Open Project…; a **Bookmarks** submenu with a
*Learn* section of eight `app.open_uri` links (Biblioteca, Developer
Documentation, HIG, gjs.guide, Vala wiki, gtk-rs, PyGObject, blueprint-compiler)
and a *Get Help* section of two (Discourse, Matrix); a **Platform Tools**
submenu of three; Extensions; Permissions; Reveal in Files; Keyboard
Shortcuts; About Workbench.

→ `lib/app_menu.rb` — **ported**, including the `themeswitcher` slot, the Bookmarks submenu and the Platform Tools submenu.

### `src/window.blp` `menu preview_menu` — preview options

Two check items, `win.auto-preview` (Auto-Update) and `win.safe-mode` (Safe
Mode), hung off a flat `Gtk.MenuButton` labelled "Preview" in the preview
panel header.

→ folded into `lib/panel_preview.rb` — **ported.**

### `src/window.blp` `menu menu_console` — console context menu

Three items: Copy (`win.console_copy`), Select All
(`win.console_select_all`), Clear (`win.clear`), shown by a
`Gtk.PopoverMenu` with `has-arrow: false`, pointed at the click position by a
`Gtk.GestureClick` on button 3.

→ folded into `lib/term_console.rb` — **ported**, against a text view rather than a terminal.

### `src/PanelCode.js` + `src/window.blp` `panel_code` — the Code panel

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView panel_code` | 1 | `#panel_code` (1px right border, `#fcfcfc` / `#262626`) | — | |
| `Gtk.CenterBox` | 1 | `toolbar`, `panel_header` | — | 46px tall |
| `Gtk.Label` | 1 | `dim-label` | — | `<b>Code</b>`, markup |
| `Gtk.Separator` | 2 | `spacer` (first only) | — | |
| `Gtk.DropDown dropdown_code_lang` | 1 | flattened at runtime by `makeDropdownFlat` | `notify::selected-item` → `switchLanguage`; bound to `code-language` | model filled with JavaScript, Vala, Rust, Python, and TypeScript only when the `typescript` key is on |
| `Gtk.Stack stack_code` | 1 | — | — | five `$CodeView` pages, one per language |

Switching language also mirrors the choice into the global
`recent-code-language`, resets the previewer to internal, and scaffolds the
per-language project files (`setupJavascriptProject`, `setupRustProject`,
`setupTypeScriptProject`).

→ `lib/panel_code.rb` — **ported.** The dropdown, the stack and the language switch are there; the per-language project scaffolding is not.

### `src/PanelStyle.js` + `src/window.blp` `panel_style` — the Style panel

`Adw.ToolbarView` (`#panel_style`), a `toolbar panel_header` `Gtk.CenterBox`
with a `dim-label` `<b>Style CSS</b>`, a `Gtk.Separator`, and one `$CodeView`
with `language_id: 'css'`. `PanelStyle.js` is only the two-way binding
between `show-style`, the toggler's `active` and the panel's `visible`.

→ `lib/panel_style.rb` — **ported.**

### `src/PanelUI.js` + `src/window.blp` `panel_ui` — the UI panel

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView panel_ui` | 1 | `#panel_ui` | — | |
| `Gtk.CenterBox` | 1 | `toolbar`, `panel_header` | — | |
| `Gtk.Label` | 1 | `dim-label` | — | `<b>UI</b>` |
| `Gtk.DropDown dropdown_ui_lang` | 1 | flattened at runtime | `notify::selected` → convert and switch | Blueprint / XML; a failed conversion reverts the selection |
| `Gtk.Button button_ui_experimental_blueprint` | 1 | — | `clicked` → presents `dialog_blueprint_experimental` | `applications-science-symbolic`, visible only in Blueprint mode |
| `Gtk.Stack stack_ui` | 1 | — | — | `blueprint` and `xml` pages, each a `$CodeView` |

Emits its own `updated` signal (GJS `imports.signals`) carrying the compiled
XML, which the previewer listens to. Conversion routes through the Blueprint
LSP and forces the console open; a blueprint LSP error is logged through
`logBlueprintError`.

→ `lib/panel_ui.rb` — **ported** for the XML side. Blueprint conversion needs the Blueprint LSP, which is not ported, so only the `xml` page is live.

### `src/Previewer/Previewer.js` + `src/window.blp` `panel_preview` — the Preview panel

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView panel_preview` | 1 | `#panel_preview` | — | |
| `Gtk.MenuButton` | 1 | `flat` | `menu-model: preview_menu` | labelled "Preview" |
| `Gtk.DropDown dropdown_preview_align` | 1 | flattened at runtime | `notify::selected` → `setPreviewAlign`; bound to `preview-align` | Fill / Center; hidden unless the previewed XML is a template |
| `Gtk.Button button_screenshot` | 1 | — | `clicked` → screenshot | custom icon, carries an `accessibility { label }` |
| `Gtk.Stack stack_preview` | 1 | — | — | three pages: `inline`, `open_window`, `close_window` |
| `Gtk.ScrolledWindow` + `Gtk.Viewport output` | 1 | `background` | — | the in-process preview target, `halign`/`valign` follow the align dropdown |
| `Adw.StatusPage` | 2 | — | — | **empty/explanatory states**: "Windowed Preview" / "This interface can only be previewed as a separate window.\nWe recommend using “Always on Top”." with `re.sonny.Workbench-multitasking-windows-symbolic` |
| `Gtk.Button button_open_preview_window` | 1 | `pill`, `suggested-action` | `clicked` → `current.open()` | "Show Preview Window" |
| `Gtk.Button button_close_preview_window` | 1 | `pill` | `clicked` → `current.close()` | "Close Preview Window" |

Behaviour: parses the panel's XML, rewrites the target object or template into
a previewable id, installs a custom `Gtk.BuilderScope` that logs every signal
fired in the preview (Template / Registered / Unregistered), honours
`safe-mode` by crash-testing the XML in a subprocess first, applies the CSS
panel's text as a scoped `Gtk.CssProvider`, and reports CSS parser errors back
into the CSS `CodeView` as diagnostics. The screenshot path writes a PNG under
the data dir, copies a `Gdk.Texture` to the clipboard, and sends a
`Gio.Notification` titled "Workbench Screenshot captured" with a "Show in
Files" button wired to `app.show-screenshot`.

→ `lib/panel_preview.rb` (chrome) and `lib/previewer.rb` (the pipeline) — **both ported.** Missing from the pipeline: safe-mode's crash subprocess, the screenshot path (PNG, clipboard texture, notification) and CSS-parser-error diagnostics fed back into the CSS view.

### `src/Previewer/Internal.js` — in-process previewer

Builds the user's XML in-process, hosts root objects in their own window,
exposes the `globalThis.workbench` API (`window`, `application`, `builder`,
`template`, `resolve`, `preview`, `build`), applies scoped CSS by rewriting
selectors through `postcss`, and opens the GTK Inspector.

→ `lib/internal_previewer.rb` — **ported**, without the logging `Gtk.BuilderScope` and without the GTK Inspector hook.

### `src/Previewer/External.js`, `src/Previewer/DBusPreviewer.js`, `src/Previewer/previewer.vala`, `src/Previewer/crasher.vala`

The out-of-process previewer: a D-Bus proxy (`OpenWindow`, `CloseWindow`,
`UpdateUi`, `UpdateCss`, `Screenshot`, plus `WindowOpen` and `CssParserError`
signals, interface in `src/Previewer/previewer.xml`), the Vala previewer
process that serves it, and `crasher.vala`, the subprocess safe-mode uses to
find out whether a UI definition crashes before it is previewed.

→ `lib/external_previewer.rb`, `lib/dbus_previewer.rb` — **missing.**
`lib/previewer.rb` has only `use_internal`, so preview works for UI and CSS
but not for code written in Vala, Rust or Python. The Vala processes still
have no Ruby counterpart and still need a decision.

### `src/libworkbench/workbench-preview-window.blp` + `.c` — the preview window

`Adw.Window` subclass, 600×800, minimum 360×360, titled "Preview", one
`Adw.ToolbarView` with `top-bar-style: raised` and a bare `Adw.HeaderBar`;
`get_content`/`set_content` proxy the toolbar view. This is the window a
windowed preview appears in.

→ `lib/preview_window.rb` — **missing.** `internal_previewer.rb` presents a root object as a plain window instead, so there is no 600×800 "Preview" window with a header bar.

### `src/Devtools.js` + `src/window.blp` `panel_devtools` — the console pane chrome

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView` | 1 | `#panel_devtools` | — | the Paned's end child |
| `Gtk.CenterBox toolbar_devtools` | 1 | `toolbar`, `panel_header`, `#toolbar_devtools` | — | |
| `Gtk.ToggleButton button_console` | 1 | — | `action-name: win.console`; bound to `show-console`; `notify::active` (after) → `setupPaned` | `C_onsole`, custom terminal icon |
| `Gtk.Button button_inspector` | 1 | — | `clicked` → `previewer.openInspector()` | `find-location-symbolic`, tooltip names Ctrl+Shift+I |
| `Gtk.Button button_clear` | 1 | — | `action-name: win.clear`; `visible` bound to `show-console` | `Cl_ear` |

Owns the collapse arithmetic: dragging the paned below a 50px threshold writes
`show-console: false` and snaps the handle to the toolbar height; toggling the
button restores the remembered position. Installs `win.console`
(`<Control><Shift>K`).

→ `lib/devtools.rb` — **ported**, including the collapse arithmetic. The Inspector button has no previewer hook to call.

### `src/TermConsole.js` + `src/window.blp` `devtools` — the console

`Vte.Terminal terminal` (scrollback 512, input disabled, pixel scroll units,
fallback scrolling off) inside a `Gtk.ScrolledWindow`, tailing
`$XDG_RUNTIME_DIR/$FLATPAK_ID/typescript` via `/bin/tail --follow`. Cursor
hidden with an ANSI escape; `clear()` erases screen and scrollback and resets.
A sixteen-colour Adwaita palette plus fg/bg is recomputed on
`notify::dark`. `Gtk.GestureClick` (button 3) + `Gtk.PopoverMenu` give the
context menu. Installs `win.clear` (`<Control>K`), `win.console_copy`
(`<Control><Shift>C`, enabled only while there is a selection, tracked through
`selection_changed` and `contents_changed`) and `win.console_select_all`
(`<Control><Shift>A`).

→ `lib/term_console.rb` — **ported** as a text view: no Vte, so no `tail --follow`, no scrollback, no sixteen-colour palette.

### `src/widgets/CodeView.blp` + `src/widgets/CodeView.js` — the editor

A `Gtk.Widget` subclass with a vertical `BoxLayout`: a `Gtk.ScrolledWindow`
holding a `GtkSource.View` (monospace, auto-indent, current-line highlight,
indent-on-tab, 2-space indent and tab width, spaces instead of tabs, line
marks, line numbers, smart backspace) over an internal `GtkSource.Completion`
with `select-on-show`, plus a `$CodeFind`. Eight instances exist (JavaScript,
TypeScript, Vala, Rust, Python, Blueprint, XML, CSS), each with its own
`language_id`.

Behaviour: picks the `Adwaita` / `Adwaita-dark` style scheme on
`notify::dark`; emits a single coalesced `changed` from `end-user-action`,
`undo` and `redo`; registers two `Gtk.TextTag`s, `error` (`#e01b24`) and
`warning` (`#ffa348`), both `Pango.Underline.ERROR`, and applies them from LSP
diagnostics; registers a hover provider and an LSP-backed completion provider
whose proposals are filtered by a `Gtk.StringFilter` in PREFIX mode, sorted
(Blueprint has its own comparator), rendered with kind in the BEFORE column, a
strikethrough label and a "Deprecated" AFTER column, and triggered on `.`;
saves and restores cursor line/offset and both scroll positions across text
replacement.

→ `lib/code_view.rb` — **ported** as a `Gtk::TextView`: the coalesced `changed`, the cursor/scroll save-restore and the two diagnostic tags are there; syntax highlighting, the Adwaita style schemes, completion and hover are not, and there is no `GtkSource` to hang them on.

### `src/widgets/CodeFind.blp` + `src/widgets/CodeFind.js` — find bar

`Gtk.Revealer` subclass, `slide_up`, hidden by default.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 | `toolbar` | — | centred |
| `Gtk.Box` | 1 | `css-name: entry` | — | fakes an entry around the text widget |
| `Gtk.Image` | 1 | — | — | `edit-find-symbolic` |
| `Gtk.Text text_search_term` | 1 | — | `notify` → re-search; `activate` → next | 10 chars wide |
| `Gtk.Label label_info` | 1 | — | — | **state text**: `""`, `"<n> of <count>"`, or `"<count> occurences"` [sic] |
| `Gtk.Button button_previous` | 1 | — | `clicked => $onSearchPrevious()` | insensitive until a match exists |
| `Gtk.Button button_next` | 1 | — | `clicked => $onSearchNext()` | insensitive until a match exists |
| `Gtk.Button` | 1 | `circular`, `small` | `clicked => $onClose()` | `window-close-symbolic` |
| `Gtk.EventControllerKey` | 2 | — | `key-pressed` | one on the source view (Ctrl+F opens and seeds from the selection, Escape closes, Ctrl+G / Ctrl+Shift+G step), one on the revealer (Ctrl+G, Shift+Return, Escape) |

Backed by `GtkSource.SearchSettings` (case-insensitive, wrap-around) and a
highlighting `GtkSource.SearchContext`; the counter follows
`notify::occurrences-count` and the buffer's `mark-set`.

→ `lib/code_find.rb` — **ported**, searching the buffer directly instead of through `GtkSource.SearchContext`, and using a `Gtk::Entry` because `css-name` is construct-only.

### `src/WorkbenchHoverProvider.js` — diagnostic hover

A `GtkSource.HoverProvider` that, for diagnostics covering the hovered
position, appends a vertical `Gtk.Box` with CSS `hoverdisplay osd frame` and
one `body` `Gtk.Label` per message.

→ `lib/hover_provider.rb` — **missing**, and blocked: `GtkSource.HoverProvider` has no Ruby binding in this stack.

### `src/Library/Library.blp` + `src/Library/Library.js` — the Library window

`Adw.Window`, 700×700, `hide-on-close`, non-modal, `.devel` on the devel build,
titled "Workbench — Library".

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ToolbarView` + `Adw.HeaderBar` + `Adw.WindowTitle` | 1 | — | — | |
| `Gtk.ScrolledWindow scrolled_window` | 1 | — | — | `hscrollbar-policy: never`; vadjustment nulled on reset |
| `Adw.Clamp` | 1 | — | — | max 576 |
| `Gtk.Picture picture_illustration` | 1 | — | — | `library.svg` |
| `Gtk.Label` | 1 | `title-1` | — | "Learn, Test, Remix" |
| `Gtk.SearchEntry search_entry` | 1 | — | `search-changed` → `updateList` | 100ms delay, "Search demos", activates-default |
| `Gtk.DropDown dropdown_language` | 1 | — | `notify::selected` → `updateList` | Any Language + JavaScript, Python, Rust, Vala, and TypeScript only when enabled |
| `Gtk.DropDown dropdown_category` | 1 | — | `notify::selected` → `updateList` | Any Category, Tools, Network, Controls, Layout, Feedback, Navigation, User Interface, Platform APIs |
| `Gtk.ListBox listbox` | 1 | `boxed-list` | — | **repeater**: one `$EntryRow` per demo from `demos/index.json` |
| `Gtk.Box results_empty` | 1 | — | — | **empty state**, hidden unless the filter matches nothing |
| `Gtk.Label` | 1 | `title-3` | — | "No results" |
| `Gtk.Button button_reset` | 1 | `pill` | `clicked` → `reset` | "Reset filters" |
| `Gtk.Label` | 1 | `caption` | — | CC0 notice, markup, with a link |

Installs `app.library` (`<Control><Shift>O`), which presents the window and
focuses the last-triggered row. Opening a demo creates a session from it, may
force the code panel and language, auto-runs JavaScript demos whose manifest
says `autorun`, and diverts to the Permissions dialog when the demo's
`flatpak-finish-args` need permissions the sandbox lacks.

→ `lib/library_window.rb` — **missing.** `app.library` is declared in the header bar's button but installed nowhere, so the Library button is dead. The largest unported unit.

### `src/Library/EntryRow.blp` + `src/Library/EntryRow.js` — one demo row

`Adw.ActionRow` subclass, activatable, `labelled-by` / `described-by` wired for
accessibility.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | — | custom `triggered` signal; `action_name: demo-row.activate` on its own `Gio.SimpleActionGroup` | prefix box, `go-next-symbolic` suffix |
| `Gtk.Label title_label` | 1 | — | — | demo name, wrapping |
| `Gtk.Label description_label` | 1 | `dim-label`, `caption` | — | demo description |
| `Gtk.Box languages_box` | 1 | — | — | **repeater** |
| `Gtk.Button` | n | `pill`, `small` | `clicked` → `triggered(language)` | one per language the demo supports, TypeScript suppressed when disabled |
| `Gtk.Image` | 1 | — | — | `go-next-symbolic` |

→ `lib/entry_row.rb` — **missing.**

### `src/Extensions/Extensions.blp` + `src/Extensions/Extensions.js` — Extensions dialog

`Adw.Dialog`, 600×750, titled "Extensions": toolbar view, bare header bar,
scrolled window, `Adw.Clamp` (600, tightening 400), an `extensions.svg`
`Gtk.Picture`, and a `boxed-list` `Gtk.ListBox` of five `$Extension` rows —
JavaScript and Python hard-coded available, Rust, Vala and TypeScript probed at
runtime against `/usr/lib/sdk/...`, TypeScript visible only when the
`typescript` key is on. Two mutually exclusive `dim-label` hints:
`all_set_hint` ("You're all set!") and `restart_hint` ("To apply changes,
restart Workbench once the commands have completed"). Installs
`win.extensions`, which the run pipeline activates when an unavailable
language is run.

→ `lib/extensions_dialog.rb` — **missing**, and with it `win.extensions`, which the run pipeline is supposed to activate for an unavailable language.

### `src/Extensions/Extension.blp` + `src/Extensions/Extension.js` — one extension row

`Gtk.ListBoxRow` subclass, not activatable, with `title`, `available` and
`command` properties bound into the template.

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.CenterBox` | 1 | — | — | 55px |
| `Gtk.Label label_title` | 1 | — | — | bound to `title` |
| `Gtk.Image image_available` | 1 | `success` | — | `re.sonny.Workbench-test-pass-symbolic`, visible when `available` |
| `Gtk.Box installation_guide` | 1 | — | — | visible when **not** `available` (inverted binding) |
| `Gtk.Label` | 1 | `dim-label` | — | "Run the following command" |
| `Gtk.Label label_command` | 1 | `command_snippet` | — | selectable, markup, bound to `command` |

→ `lib/extension_row.rb` — **missing.**

### `src/Permissions/Permissions.blp` + `src/Permissions/Permissions.js` — Permissions dialog

`Adw.Dialog`, 600×750: `Adw.Clamp` (520, tightening 400), a
`permissions.svg` picture, a `title-1` "Permissions Needed", an explanatory
wrapped label, a selectable `command_snippet` label carrying the generated
`flatpak override …` command, a `heading` "What it does" row with a flat
`button_info` (`re.sonny.Workbench-external-link-symbolic`) that opens the
Flatpak sandbox-permissions docs, and a `boxed-list` of four `property`
`Adw.ActionRow`s — `--user`, `--share-network`, `--socket=pulseaudio`, and
`--device=input` / `--device=all` (title set at runtime), each with its own
custom symbolic icon. Installs `win.permissions`; the window and the Library
both activate it. **This is an error state**, not a preference page.

→ `lib/permissions_dialog.rb` — **missing**, and with it `win.permissions`.

### `troll/src/widgets/ThemeSelector.js` — theme switcher

Three `Gtk.CheckButton`s (Follow system / Light / Dark) in the main menu's
`themeswitcher` custom slot, driven by `app.color-scheme`, with its own
stylesheet. Lives in the `troll` submodule, so it produces no row in an
upstream scan of `src/` and must not be mistaken for an extra in the port.

→ `lib/theme_selector.rb` — **ported** (102 lines, three check buttons on
`app.color-scheme`), written from the component's description rather than from
the submodule, which is still not checked out (see Blockers).

### `src/style.css` — the app stylesheet

Thirty-nine lines defining `view-toggler` (icon margin), `hoverdisplay`,
`panel_header`, `command_snippet` (monospace, view colours, border),
`button.pill.small` (the Library's language tags, borrowed from Builder), the
`#panel_code` / `#panel_style` / `#panel_ui` right border and `#fcfcfc`
background, `#toolbar_devtools` background, a dev-banner suppression rule on
each panel's revealer, and a `prefers-color-scheme: dark` block swapping the
two backgrounds to `#262626`.

→ `lib/style.rb` — **ported** as a `Gtk::CssProvider` on the display.

### `data/app.gschema.xml` — settings

Two schemas and one enum. App schema `re.sonny.Workbench`:
`color-scheme`, `recent-code-language`, `recent-projects`, `first-run`,
`typescript`. Session schema `re.sonny.Workbench.Session`: `show-code`,
`show-style`, `show-ui`, `show-preview`, `show-console`, `name`,
`code-language`, `user-interface-language` (enum blueprint/xml),
`preview-align`, `auto-preview`, `safe-mode`, `edited`, `window-width`,
`window-height`, `window-maximized`, `window-fullscreened`. Nearly every
widget above is bound to one of these keys, so the port needs them before the
window.

→ `lib/settings.rb` — **ported.** Both schemas' keys exist; check whether a compiled GSettings schema is installed or the port keeps its own store.

### `src/sessions.js`, `src/Document.js`, `src/langs/*`

Not widgets, but the window's behaviour hangs off them: `Session` (per-session
directory, settings instance, demo copying, save-as-project, recent projects,
`edited` flag that decides whether the save dialog appears) and the eight
`Document` subclasses (one per language: load, save, format, LSP client,
diagnostics). The save/discard dialog, the window title, the dirty tracking
and every diagnostic underline come from here.

→ `lib/session.rb` — **ported.** `lib/document.rb` — **ported**, reading and writing the file directly rather than through `GtkSource.FileLoader`/`FileSaver`. `lib/language.rb` — **ported** (upstream's `src/common.js` language table). Per-language documents: only `lib/xml_document.rb` exists; the JavaScript, TypeScript, Vala, Rust, Python, Blueprint and CSS documents, their builders and compilers, are **missing**.

### `src/window.blp` `alert_dialog_save_project` (+ `button_location`) — unsaved-session prompt

`Adw.AlertDialog`, close-response `cancel`, heading "Save Project?", body
"This session has not been saved. Unsaved sessions will be permanently lost.",
three responses: `cancel`, `discard` (destructive), `save` (suggested, starts
disabled). The extra child is two `boxed-list` `Gtk.ListBox`es — an
`Adw.EntryRow row_project_name` ("Project Name") and an `Adw.ActionRow
row_project_location` ("Location" / "Select Location") whose
`activatable-widget` is the separately-declared flat `folder-symbolic`
`button_location`, re-parented into the row's suffix at runtime — plus a
`dim-label caption` note "The project will be created in a new subdirectory".
`save` only enables once both a name and a location exist.

→ `lib/save_project_dialog.rb` — **ported.**

### `src/window.blp` `dialog_blueprint_experimental` — Blueprint warning

`Adw.Dialog`, 368×480, content extended to the top edge, bare
`Adw.HeaderBar`, an `Adw.StatusPage` titled "Blueprint is\nExperimental" with
description "Future versions may have breaking syntax" and the
`re.sonny.Workbench-beaker` icon, and one `suggested-action pill`
"Documentation" button that opens the blueprint-compiler docs.

→ `lib/blueprint_experimental_dialog.rb` — **ported.**

### Icons and packaging

Nineteen custom symbolic SVGs in `src/icons/` registered through the icon
theme's resource path, three app icons plus a source SVG and a PNG under
`data/icons/`, `data/app.desktop` (name, comment, categories, keywords,
`DBusActivatable`), `data/app.metainfo.xml`, `data/app.service`. The port needs
its own icon loading path — there is no GResource bundle to copy, because
upstream's resources are assembled by `gjspack` from the import graph. The
only GResource manifest upstream is
`src/libworkbench/re.sonny.Workbench.libworkbench.gresource.xml`, for the C
preview window's template.

→ no `lib/*.rb`; an `assets/` or `data/` decision for the port — **still undecided.** The port ships no icons, so every custom symbolic (the placeholder, the terminal, the preview, the screenshot icons) falls back to a missing-image icon.

## Summary table

`Present` is as of `f3be425`. `yes` means the file exists and carries the
component; `partial` means it exists with a parity gap named in the section
above; `no` means nothing has been written.

| Upstream file(s) | Port file | Kind | Present |
|---|---|---|:-:|
| `src/application.js` | `lib/workbench/application.rb` | application | partial |
| `src/actions.js` | `lib/actions.rb` | actions | yes |
| `src/about.js` | `lib/about_dialog.rb` | dialog | yes |
| `src/shortcutsWindow.blp` + `.js` | `lib/shortcuts_window.rb` | shortcuts window | yes |
| `src/window.blp` + `src/window.js` | `lib/window.rb` | window | partial |
| `src/window.blp` (`menu_app`) | `lib/app_menu.rb` | menu | yes |
| `src/window.blp` (`alert_dialog_save_project`, `button_location`) | `lib/save_project_dialog.rb` | dialog | yes |
| `src/window.blp` (`dialog_blueprint_experimental`) | `lib/blueprint_experimental_dialog.rb` | dialog | yes |
| `src/PanelCode.js` + `window.blp` | `lib/panel_code.rb` | panel | partial |
| `src/PanelStyle.js` + `window.blp` | `lib/panel_style.rb` | panel | yes |
| `src/PanelUI.js` + `window.blp` | `lib/panel_ui.rb` | panel | partial |
| `src/Previewer/Previewer.js` + `window.blp` (`preview_menu`) | `lib/panel_preview.rb`, `lib/previewer.rb` | panel + pipeline | partial |
| `src/Previewer/Internal.js` | `lib/internal_previewer.rb` | previewer | partial |
| `src/Previewer/External.js` | `lib/external_previewer.rb` | previewer | no |
| `src/Previewer/DBusPreviewer.js` (+ `previewer.xml`) | `lib/dbus_previewer.rb` | D-Bus proxy | no |
| `src/Previewer/previewer.vala`, `crasher.vala` | — (decision needed) | helper processes | no |
| `src/libworkbench/workbench-preview-window.blp` + `.c` | `lib/preview_window.rb` | window | no |
| `src/Devtools.js` + `window.blp` | `lib/devtools.rb` | panel chrome | partial |
| `src/TermConsole.js` + `window.blp` (`menu_console`) | `lib/term_console.rb` | terminal + menu | partial |
| `src/widgets/CodeView.blp` + `.js` | `lib/code_view.rb` | widget | partial |
| `src/widgets/CodeFind.blp` + `.js` | `lib/code_find.rb` | widget | partial |
| `src/WorkbenchHoverProvider.js` | `lib/hover_provider.rb` | hover provider | no |
| `src/Library/Library.blp` + `.js` | `lib/library_window.rb` | window | no |
| `src/Library/EntryRow.blp` + `.js` | `lib/entry_row.rb` | row | no |
| `src/Extensions/Extensions.blp` + `.js` | `lib/extensions_dialog.rb` | dialog | no |
| `src/Extensions/Extension.blp` + `.js` | `lib/extension_row.rb` | row | no |
| `src/Permissions/Permissions.blp` + `.js` | `lib/permissions_dialog.rb` | dialog (error state) | no |
| `troll/src/widgets/ThemeSelector.js` | `lib/theme_selector.rb` | widget | yes |
| `src/style.css` | `lib/style.rb` | stylesheet | yes |
| `data/app.gschema.xml` | `lib/settings.rb` | settings | yes |
| `src/sessions.js` | `lib/session.rb` | model | yes |
| `src/Document.js` | `lib/document.rb` | model | partial |
| `src/common.js` (`languages`, `getLanguage`) | `lib/language.rb` | table | yes |
| `src/langs/xml/XmlDocument.js` | `lib/xml_document.rb` | model | yes |
| `src/langs/xml/xml.js` + `ltx.js` | `lib/xml.rb` | library | yes |
| `src/langs/javascript/*` | `lib/javascript_document.rb` + builder | model | no |
| `src/langs/typescript/*` | `lib/type_script_document.rb` + compiler | model | no |
| `src/langs/vala/*` | `lib/vala_document.rb` + compiler | model | no |
| `src/langs/rust/*` | `lib/rust_document.rb` + compiler | model | no |
| `src/langs/python/*` | `lib/python_document.rb` + builder | model | no |
| `src/langs/blueprint/*` | `lib/blueprint_document.rb` | model | no |
| `src/langs/css/*` | `lib/css_document.rb` | model | no |
| `src/lsp/*` | `lib/lsp*.rb` | LSP client | no |
| `src/icons/*`, `data/icons/*` | an `assets/`/`data/` path | icons | no |

Twenty-six rows are `yes` or `partial`; **seventeen are still `no`**, and five
of those are user-facing units in their own right (Library, EntryRow,
Extensions, Extension, Permissions) plus the hover provider and the preview
window.

### The next units, in order

1. **Library + EntryRow** — the `app.library` button in the header bar is dead
   today, and the Library is how a user meets the app at all. Blocked on the
   `demos` submodule.
2. **Extensions + Extension, Permissions** — the two dialogs the run pipeline
   already wants to divert to, so `lib/window.rb`'s run path is incomplete
   until they exist.
3. **The language documents and the LSP client** — formatting, compiling and
   diagnostics for the seven unported languages. `code_view.rb` already has
   the diagnostic tags with nothing to fill them.
4. **`preview_window.rb`** — a small, unblocked win that replaces the bare
   window `internal_previewer.rb` conjures.
5. **The external previewer** — needs the Vala decision first.

## Blockers

1. **`troll` submodule is not checked out.** It supplies `ThemeSelector` (a
   real component in the main menu), `build()` (the loader every named-root
   blueprint goes through), `persistWindowState` (the window geometry keys),
   `once`/`unstack`, and the version helpers in the About dialog. None of it
   can be read from `origin/main`.
2. **`demos` submodule is not checked out.** `demos/index.json` is the
   Library's entire content — demo names, descriptions, categories, language
   lists, `autorun` and `flatpak-finish-args`. Without it the Library window
   and the first-run `Welcome` bootstrap cannot be ported faithfully.
3. **No translation catalogue upstream.** There is no `po/` directory, no
   `POTFILES`, no `LINGUAS` on `origin/main`; strings are wrapped in
   `gettext`/`_()` and in blueprint `_("…")` but the catalogue is kept
   elsewhere. Translation parity has no upstream artefact to port.
4. **No GtkSourceView or Vte in the port's stack.** Still true at `f3be425`:
   the `Gemfile` carries `gtk4` and `adwaita`, and `flake.nix`'s `gtkStack` has
   neither `gtksourceview` nor `vte`. The first pass **worked around it rather
   than waiting** — `code_view.rb` is a `Gtk::TextView`, `code_find.rb`
   searches the buffer itself, `term_console.rb` is a text view — so the editor
   has no syntax highlighting, no completion and no style schemes, and the
   console does not follow a log. This is now a *standing* parity gap with
   code committed on top of it: growing the stack later means rewriting those
   three files, so decide before the hover provider and the LSP client are
   planned on top of the same absence.
5. **`src/libworkbench` is a C library with no Ruby equivalent.** It provides
   the `GtkSource.CompletionProvider` subclass (`WorkbenchCompletionProvider`,
   `RequestState`) the editor's completion is built on, plus the preview
   window. The completion provider has to be reimplemented in Ruby or dropped.
6. **Flatpak-only logic has no meaning outside the sandbox.** Extensions probes
   `/usr/lib/sdk/*`, Permissions reads `.flatpak-info`, screenshots and
   "Reveal in Files" go through `Xdp`/`XdpGtk4` portals, and the console tails
   `$XDG_RUNTIME_DIR/$FLATPAK_ID/typescript`. The port needs a decided
   behaviour for each when not running under Flatpak.
7. **The out-of-process previewer is two Vala programs and a D-Bus interface.**
   Porting `External.js` alone gives a proxy with nothing on the other end.
8. **No GSettings schema for the port.** Sixteen session keys and five app keys
   are read and bound all over upstream; the port needs a compiled schema and
   an install path before any panel can bind to one.
9. ~~**`Gtk.ShortcutsWindow` is deprecated in GTK 4.18.**~~ **Decided:**
   `lib/shortcuts_window.rb` uses `Adw.ShortcutsDialog`, as the pilot port did.
   `Gtk::ShortcutsWindow` also cannot be constructed through the Ruby bindings
   (`GtkWindow is not subtype of GtkShortcutsWindow`), so there was no choice.
10. **`Gtk.BuilderScope` cannot be implemented from Ruby.** Upstream's internal
   previewer installs one to resolve a previewed definition's `<signal>` to a
   logging handler. The port cannot, so previewed signals are unconnected and
   GTK logs a missing handler. No workaround is known; this is a permanent
   parity gap unless the external previewer carries it.
11. **The port ships no icons.** Upstream registers nineteen custom symbolics
   through its resource path. Nothing in `lib/` does, so those icons render as
   missing-image placeholders today — see the Icons and packaging section.
