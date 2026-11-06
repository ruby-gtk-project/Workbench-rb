# Component inventory — Workbench

Survey of upstream `origin/main` against the `ruby` branch's `lib/`, for
full-parity planning. No app code was written for this step.

Legend for **Exists**: Yes = a `lib/*.rb` file already ports this unit;
Partial = some of the unit is covered by an existing file but part of it is
not; No = nothing in `lib/` covers it yet.

## Main window and its dialogs/menus

`src/window.blp` is one file that declares five top-level named objects (not
one template): the main window, two dialogs and two menus (a third menu,
`menu_console`, is consumed by `TermConsole`). Upstream splits the *behaviour*
for these across `src/window.js`, `src/PanelUI.js` and `src/TermConsole.js`.

| Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/window.blp` (`Adw.ApplicationWindow window`), `src/window.js` | `lib/window.rb` | window | Yes |
| `src/window.blp` (`menu menu_app`) | `lib/app_menu.rb` | menu | Yes |
| `src/window.blp` (`Adw.Dialog dialog_blueprint_experimental`), handler in `src/PanelUI.js` | `lib/blueprint_experimental_dialog.rb` | dialog | Yes |
| `src/window.blp` (`Adw.AlertDialog alert_dialog_save_project`, `Button button_location`) | `lib/save_project_dialog.rb` | dialog | Yes |
| `src/window.blp` (`Adw.ToolbarView panel_preview`, `menu preview_menu`), binding in `src/window.js` | `lib/panel_preview.rb` | panel | Yes |
| `src/window.blp` (`menu menu_console`), `src/TermConsole.js` | `lib/term_console.rb` | panel + menu | Yes |
| `src/actions.js` (`app.quit`, `app.about`, `app.open-uri`, `app.platform-tools`, `app.color-scheme`/`safe-mode`/`auto-preview` (commented out upstream), `app.new-project`, `app.open-file`, `app.show-screenshot`) | `lib/actions.rb` | actions | Yes |
| `src/application.js` | `lib/workbench/application.rb` | app class | Yes |
| `src/about.js` (`Adw.AboutDialog`, code-built, no `.blp`) | `lib/about_dialog.rb` | dialog | Yes |
| `src/shortcutsWindow.blp` (`ShortcutsWindow window`), `src/shortcutsWindow.js` | `lib/shortcuts_window.rb` | shortcuts window | Yes |
| `data/app.gschema.xml` (both schemas) | `lib/settings.rb` | settings | Yes |

## Panels (UI / CSS / Code / Preview)

| Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/PanelUI.js` | `lib/panel_ui.rb` | panel | Yes |
| `src/PanelStyle.js` | `lib/panel_style.rb` | panel | Yes |
| `src/PanelCode.js` | `lib/panel_code.rb` | panel | Yes |
| `src/Devtools.js` | `lib/devtools.rb` | panel region | Yes |
| `src/widgets/CodeView.blp` (`template $CodeView: Gtk.Widget`), `src/widgets/CodeView.js` | `lib/code_view.rb` | widget | Yes |
| `src/widgets/CodeFind.blp` (`template $CodeFind: Revealer`), `src/widgets/CodeFind.js` | `lib/code_find.rb` | widget | Yes |
| `src/Document.js` | `lib/document.rb` | model | Yes |
| `src/sessions.js` | `lib/session.rb` | model | Yes |
| `src/langs/xml/XmlDocument.js` | `lib/xml_document.rb` | document | Yes |
| `src/langs/xml/xml.js` | `lib/xml.rb` | support | Yes |
| `src/common.js` (`languages` table, `getLanguage`) | `lib/language.rb` | data table | Yes |
| `src/style.css` | `lib/style.rb` | stylesheet carrier | Yes |
| `troll/src/widgets/ThemeSelector.js` (vendored, so it produces no upstream-repo rows of its own) | `lib/theme_selector.rb` | widget | Yes |

### Not yet ported in this group
| Upstream file(s) | Kind | Notes |
|---|---|---|
| `src/langs/blueprint/BlueprintDocument.js`, `blueprint.js` | document | Blueprint-language document support; not the `dialog_blueprint_experimental` warning (that's already ported, see above) |
| `src/langs/css/CssDocument.js`, `css.js`, `prettier.js` | document | CSS-language document support beyond `PanelStyle` |
| `src/langs/javascript/*.js` | document | JS-language document + Biome-backed formatting |
| `src/langs/python/*.js` | document | Python-language document support |
| `src/langs/rust/*.js` | document | Rust-language document support |
| `src/langs/typescript/*.js` | document | TypeScript-language document support |
| `src/langs/vala/*.js` | document | Vala-language document support |
| `src/WorkbenchHoverProvider.js`, `src/lsp/LSP.js`, `src/lsp/LSPClient.js`, `src/lsp/sourceview.js` | behaviour | Language-server integration (hover, diagnostics) for `CodeView` |

## Previewer

| Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/Previewer/Previewer.js` | `lib/previewer.rb` | orchestrator | Yes |
| `src/Previewer/Internal.js` | `lib/internal_previewer.rb` | previewer backend | Yes |
| `src/Previewer/External.js`, `src/Previewer/DBusPreviewer.js`, `src/Previewer/previewer.xml` | — | previewer backend | **No** — spawns an out-of-process previewer over D-Bus; no widgets of its own but is user-facing behaviour (external window toggle) |
| `src/libworkbench/workbench-preview-window.blp` (`template $WorkbenchPreviewWindow: Adw.Window`), `workbench-preview-window.c/.h` | — | window | **No** — the separate top-level preview window; distinct from `PanelPreview`'s inline state |
| `src/Previewer/crasher.vala`, `previewer.vala` | — | previewer backend (Vala) | **No** (backend process, not a widget, but gates whether "external preview" works at all) |
| `src/libworkbench/workbench-completion-provider.c/.h`, `workbench-completion-request.c/.h` | — | completion provider | **No** — GtkSourceView completion plumbing backing `CodeView` |

## Library

| Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/Library/Library.blp` (`Adw.Window window`), `src/Library/Library.js` | — | window | **No** |
| `src/Library/EntryRow.blp` (`template $EntryRow: Adw.ActionRow`), `src/Library/EntryRow.js` | — | row | **No** |
| `demos/` (the catalogue the Library lists/searches) | — | data | **No** — needs its own survey; large tree, not scanned row-by-row here |

## Extensions dialog

| Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/Extensions/Extensions.blp` (`Adw.Dialog dialog`), `src/Extensions/Extensions.js` | — | dialog | **No** |
| `src/Extensions/Extension.blp` (`template $Extension: ListBoxRow`), `src/Extensions/Extension.js` | — | row (repeated: 3 known installs — JavaScript, Python, (Rust/Vala) — static list in the `.blp`, verify full count when ported) | **No** |

## Permissions dialog

| Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/Permissions/Permissions.blp` (`Adw.Dialog dialog`), `src/Permissions/Permissions.js`, `src/flatpak.js` | — | dialog | **No** — 4 static `Adw.ActionRow`s plus one (`action_row_device`) whose title/subtitle is set conditionally in JS depending on `isDeviceInputOverrideAvailable()` |

## Non-UI infrastructure (out of scope for the widget inventory, noted for completeness)

| Upstream file | Why it's not a component |
|---|---|
| `src/overrides.js` | GObject class-registration shim for demo code, not a widget |
| `src/flatpak.js` | reads `/.flatpak-info`; consumed by `About` and `Permissions`, no widgets of its own |
| `src/log_handler.js`, `src/util.js`, `src/common.js` (besides the `languages` table) | plumbing |
| `src/init.js`, `src/main.js`, `src/bin.js` | process entry points |
| `src/cli/**` | separate `workbench-cli` tool, not the GUI app |
| `build-aux/**`, `.github/**`, `Makefile`, `meson.build` | build system |

## GSettings / GResource / metadata

| Upstream file | → port | Exists |
|---|---|---|
| `data/app.gschema.xml` | `lib/settings.rb` | Yes |
| `data/app.metainfo.xml` | — | **No** — AppStream metadata (not a widget, but part of full parity for packaging/About) |
| `data/app.desktop`, `data/app.service` | — | **No** — desktop launcher / D-Bus activation files |
| `src/libworkbench/re.sonny.Workbench.libworkbench.gresource.xml` | — | n/a — GResource manifest for the C `libworkbench` helper library (preview window + completion provider), not itself a component |

## Translations

Upstream `origin/main` ships **no `po/` directory** — there is no translation
catalogue to port yet. Nothing to inventory here.

## Summary

- Ported (`Yes`) in `lib/`: main window, its two dialogs, its three menus,
  all four panels (UI/Style/Code/Devtools), CodeView, CodeFind, Document,
  Session, XmlDocument/Xml, Language table, Style, ThemeSelector, Previewer +
  InternalPreviewer, ShortcutsWindow, AboutDialog, Settings, Actions,
  Application.
- Not yet ported: **Library window + EntryRow**, **Extensions dialog +
  Extension row**, **Permissions dialog**, the **external/D-Bus previewer**
  path (`External.js`, `DBusPreviewer.js`, the separate
  `WorkbenchPreviewWindow`, the Vala previewer backends), the GtkSourceView
  **completion provider** (C), and all seven **per-language document**
  modules (blueprint/css/javascript/python/rust/typescript/vala) beyond what
  `PanelCode`/`PanelStyle`/`PanelUI` already cover, plus the LSP/hover
  integration that backs them.
- `demos/` (the Library's catalogue content) still needs its own pass before
  the Library window can be ported meaningfully.
