# Workbench component inventory

Survey of upstream `origin/main` against the `ruby` branch's `lib/`, for
full-parity porting. No app code was written for this pass.

Legend for **kind**: `window`, `dialog`, `page`/`panel`, `widget` (reusable
component), `row`, `menu`, `action-set`, `service` (non-widget behaviour:
settings, session, previewer backends, LSP plumbing).

## Already ported

| Upstream file(s) | → `lib/*.rb` | Kind | Present |
|---|---|---|---|
| `src/application.js`, `src/main.js`, `src/init.js`, `src/bin.js` | `lib/workbench/application.rb`, `lib/workbench.rb`, `exe/workbench` | application | yes |
| `src/actions.js` | `lib/actions.rb` | action-set | yes — **except** `app.library` (dead: no handler) and the Extensions/Permissions actions route to dialogs below |
| `src/window.js` + `src/window.blp` (`Adw.ApplicationWindow window`, header bar, 4 panels, `panel_devtools`, `Adw.ToolbarView`) | `lib/window.rb` | window | yes, including `button_library`, `button_run`, the 4 `ToggleButton` view togglers, `button_menu`, `menu_console`'s `PopoverMenu`/`GestureClick` |
| `menu menu_app` in `src/window.blp` | `lib/app_menu.rb` | menu | yes, including Bookmarks/Platform Tools submenus; `themeswitcher` custom slot wired to `ThemeSelector` |
| `menu preview_menu` in `src/window.blp` | `lib/panel_preview.rb` (menu build) | menu | yes |
| `menu menu_console` in `src/window.blp` | `lib/window.rb` / `lib/devtools.rb` | menu | yes |
| `Adw.AlertDialog alert_dialog_save_project` in `src/window.blp` | `lib/save_project_dialog.rb` | dialog | yes |
| `Adw.Dialog dialog_blueprint_experimental` in `src/window.blp` | `lib/blueprint_experimental_dialog.rb` | dialog | yes |
| `src/PanelCode.js` + panel_code portion of `src/window.blp` | `lib/panel_code.rb` | panel | yes |
| `src/PanelStyle.js` + panel_style portion | `lib/panel_style.rb` | panel | yes |
| `src/PanelUI.js` + panel_ui portion | `lib/panel_ui.rb` | panel | yes |
| panel_preview portion of `src/window.blp` | `lib/panel_preview.rb` | panel | yes |
| `src/widgets/CodeView.js` + `CodeView.blp` (template `$CodeView`) | `lib/code_view.rb` | widget | yes — hover/completion providers explicitly not ported (see Missing) |
| `src/widgets/CodeFind.js` + `CodeFind.blp` (template `$CodeFind`) | `lib/code_find.rb` | widget | yes |
| `src/Document.js` | `lib/document.rb` | service | yes |
| `src/langs/javascript/JavaScriptDocument.js` | `lib/javascript_document.rb` | service | yes |
| `src/langs/css/CssDocument.js` | `lib/css_document.rb` | service | yes |
| `src/langs/xml/XmlDocument.js`, `src/langs/xml/xml.js`/`ltx.js` | `lib/xml_document.rb`, `lib/xml.rb` | service | yes |
| `src/langs/python/PythonDocument.js` | `lib/python_document.rb` | service | yes |
| `src/langs/rust/RustDocument.js` | `lib/rust_document.rb` | service | yes |
| `src/langs/typescript/TypeScriptDocument.js` | `lib/type_script_document.rb` | service | yes |
| `src/langs/vala/ValaDocument.js` | `lib/vala_document.rb` | service | yes |
| `src/langs/blueprint/BlueprintDocument.js` | `lib/blueprint_document.rb` | service | yes |
| `src/common.js` (language table) | `lib/language.rb` | service | yes |
| `src/Devtools.js` + `panel_devtools`/`toolbar_devtools` in `src/window.blp` | `lib/devtools.rb` | panel | yes |
| `src/TermConsole.js` | `lib/term_console.rb` | widget | yes (Vte.Terminal replaced with a read-only Gtk.TextView — bindings gap, documented) |
| `src/log_handler.js` | `lib/log_handler.rb` | service | yes |
| `src/flatpak.js` | `lib/flatpak.rb` | service | yes |
| `src/sessions.js` | `lib/session.rb` | service | yes |
| settings keys of `data/app.gschema.xml` | `lib/settings.rb` | service | yes (JSON-backed, not real GSettings — documented) |
| `src/shortcutsWindow.js` + `shortcutsWindow.blp` | `lib/shortcuts_window.rb` | dialog | yes (`Adw.ShortcutsDialog` substituted for the deprecated/unbindable `Gtk.ShortcutsWindow` — documented) |
| `src/about.js` | `lib/about_dialog.rb` | dialog | yes |
| `troll/src/widgets/ThemeSelector.js` (submodule, not checked out) | `lib/theme_selector.rb` | widget | yes, reconstructed from its call sites (documented) |
| `src/style.css` | `lib/style.rb` | service | yes (CSS inlined as a Ruby constant instead of a GResource) |
| `src/Previewer/Previewer.js` | `lib/previewer.rb` | service | yes — internal path only |
| `src/Previewer/Internal.js` | `lib/internal_previewer.rb` | service | yes |
| `src/Permissions/Permissions.js` + `Permissions.blp` | `lib/permissions_dialog.rb` | dialog | yes |
| `src/lsp/LSP.js` | `lib/lsp.rb` | service | yes |
| `src/lsp/LSPClient.js` | `lib/lsp_client.rb` | service | yes |
| `src/lsp/sourceview.js` (`applyTextEdits` only) | `lib/lsp_sourceview.rb` | service | yes |
| LSP wiring used by `CodeView` | `lib/lsp_document.rb` | service | yes |

## Missing — not yet ported

| Upstream file(s) | Should become | Kind | Present | Notes |
|---|---|---|---|---|
| `src/Library/Library.js` + `Library.blp` (`Adw.Window window`: header bar, search entry, language/category `DropDown`s, demo `ListBox`, empty-state box, reset button) | `lib/library.rb` | window | **no** | `app.library` action and `button_library` in `lib/window.rb` both reference it; currently dead-ends. Pulls in `demos_dir`, `getLanguage`, `createSessionFromDemo` from `src/sessions.js`/`src/util.js`. |
| `src/Library/EntryRow.js` + `EntryRow.blp` (template `$EntryRow: Adw.ActionRow`, title/description labels, per-language badges box, suffix chevron) | `lib/entry_row.rb` (or folded into `library.rb`) | row | **no** | One repeater per demo in the library's `ListBox`. |
| `src/Extensions/Extensions.js` + `Extensions.blp` (`Adw.Dialog dialog`: illustration, `ListBox` of 5 `$Extension` rows, restart/all-set hint labels) | `lib/extensions_dialog.rb` | dialog | **no** | `win.extensions` in `lib/app_menu.rb` / `src/window.blp`'s `menu_app` has no handler yet. Also owns `isTypeScriptEnabled`, which gates the TypeScript panel/tab and the `typescript` GSettings key already modeled in `lib/settings.rb`. |
| `src/Extensions/Extension.js` + `Extension.blp` (template `$Extension: ListBoxRow`: title label, availability image, collapsible install-guide box with command label) | `lib/extension_row.rb` (or folded into `extensions_dialog.rb`) | row | **no** | 5 instances (JavaScript, Python, Rust, Vala, TypeScript), 2 availability states each. |
| `src/Previewer/External.js` | add to `lib/previewer.rb`/new `lib/external_previewer.rb` | service | **no** | Explicitly called out as not-yet-ported in `lib/previewer.rb`'s header comment. Needed for previewing Vala/Rust/Python code out-of-process. |
| `src/Previewer/DBusPreviewer.js` + `src/Previewer/previewer.xml` (D-Bus interface) | `lib/dbus_previewer.rb` | service | **no** | Same comment in `lib/previewer.rb`. This is the D-Bus transport the external previewer processes use. |
| `src/Previewer/crasher.vala` | n/a (helper binary) | service | **no** | Backs upstream's safe-mode pre-check; `lib/previewer.rb` documents that the `safe-mode` session key is stored/shown but not acted on yet. |
| `src/libworkbench/workbench-preview-window.blp`/`.c`/`.h` (template `$WorkbenchPreviewWindow: Adw.Window`) | `lib/preview_window.rb` | window | **no** | The separate top-level window `panel_preview`'s `open_window`/`close_window` `StackPage`s in `src/window.blp` open when previewing a `Gtk.Root`. `lib/panel_preview.rb` should be checked for whether it fakes this inline instead — worth a closer read before writing it. |
| `src/WorkbenchHoverProvider.js` | `lib/workbench_hover_provider.rb` | widget (GtkSource.HoverProvider) | **no** | `lib/code_view.rb` explicitly documents completion and hover providers as unported. |
| `src/langs/javascript/Builder.js` | fold into `lib/javascript_document.rb` | service | **no** | GJS-specific preview-building logic (builds a `Gtk.Builder`-backed object graph for JS demos); confirm whether `lib/document.rb`/`previewer.rb` already cover its job generically before treating as a gap. |
| `src/langs/python/Builder.js` | fold into `lib/python_document.rb` | service | **no** | Same, Python side. |
| `src/overrides.js` | n/a or fold into `lib/document.rb` | service | **no** | GJS-only `system.exit`/`GObject.registerClass` monkey-patches so previewed demo code can't kill the app; Ruby has no GJS `system` module, so this needs a from-scratch equivalent (trap `exit`/`at_exit` in previewed code) rather than a line-for-line port. |
| `src/util.js` (`ensureDir`, `data_dir`, `portal`) | partially covered by `lib/session.rb`/`lib/flatpak.rb`/`lib/actions.rb` (ashpd) | service | **partial** | `ensureDir` semantics should be double-checked against `lib/session.rb`'s directory creation before assuming full coverage. |
| `src/cli/*.js` (`workbench --format`, `--lint`, lang-specific CLI formatters for css/js/python/rust/typescript/vala) | `exe/workbench` subcommands / `lib/cli/*.rb` | action-set | **no** | A separate CLI surface of the `workbench` binary (`workbench format`, `workbench lint`), not part of the GUI widget tree; out of scope for widget parity but a real upstream feature gap worth flagging. |
| `data/app.metainfo.xml`, `data/app.desktop`, `data/app.service`, icons under `data/icons/` | no `data/` dir in the port at all | packaging | **no** | No AppStream metainfo, desktop entry, D-Bus service file or app icons exist on `ruby` yet. Needed for a installable/launchable app, not just a widget tree. |
| `po/` catalogue | n/a | i18n | **n/a** | Upstream has **no `po/` directory** (`git ls-tree -r --name-only origin/main \| grep '^po/'` returns nothing) — translation is GJS `gettext()` calls with no `.pot`/`.po` files checked in. Nothing to port here; translation-parity should note this rather than look for a missing `po/`. |

## Notes on scope and ambiguity

- **`src/Previewer/utils.js`** was not separately checked against `lib/previewer.rb`; worth a follow-up read since `previewer.rb` is large and may already cover it inline.
- **`src/langs/python/gdbus_ext.py`**, **`src/langs/python/workbench-python-previewer`**, **`src/langs/rust/template/*`**, **`src/langs/typescript/types/ambient.d.ts`** are support assets for the out-of-process previewers (External/DBus, above), not components in their own right; they become relevant once `lib/external_previewer.rb`/`lib/dbus_previewer.rb` are written.
- **`troll/`** is a git submodule (vendored UI-library code, per `.gitmodules`) and is not checked out in this clone, so it produced no rows directly; `ThemeSelector` is the one upstream component known to live there (confirmed already ported, reconstructed from call sites per its file header).
- **`gi-types/`** is TypeScript ambient typings for editor tooling, not a runtime component.
- `lib/panel_preview.rb`, `lib/internal_previewer.rb`, and `lib/previewer.rb` together need a closer per-widget pass (not done in this survey) to confirm every `StackPage`/button in `panel_preview`'s block of `src/window.blp` (already counted as "yes" above at the panel level) has its signal connected — this survey confirmed file-level presence, not widget-by-widget signal parity within that one panel.
