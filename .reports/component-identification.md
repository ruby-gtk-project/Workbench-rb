# Component identification — Workbench

| | |
|---|---|
| Upstream | `origin/main` @ `1c5627b` |
| Port | `ruby` @ `146e3ae` |
| Method | directory diff + targeted reads (full `gir-symbols`/`component-scan` pass not re-run this round; see `.reports/component-inventory.md` for the prior scan, which is stale against the two latest commits) |

Upstream is a GJS (JavaScript) app, not Vala — `src/**/*.js` paired with
`src/**/*.blp`, plus two Vala helper processes and one C widget library
(`src/libworkbench/`). 148 files under `src/`, ten `.blp` templates, no
GResource manifest for the app itself (two submodules, `troll/` and `demos/`,
also contribute real UI/data and were not scanned because they are not
checked out here).

The port has 42 files under `lib/` + `exe/workbench`.

## Unit inventory (upstream `src/` top-level units, mapped to `lib/`)

| Upstream unit | Backing files | Port file | Present? |
|---|---|---|---|
| Application | `application.js`, `actions.js`, `main.js`, `init.js` | `lib/workbench/application.rb`, `lib/actions.rb`, `exe/workbench` | yes |
| Main window | `window.js` + `window.blp` | `lib/window.rb` | yes |
| About dialog | `about.js` | `lib/about_dialog.rb` | yes |
| App menu | (menu model in `actions.js`/`window.blp`) | `lib/app_menu.rb` | yes |
| Shortcuts window | `shortcutsWindow.js` + `shortcutsWindow.blp` | `lib/shortcuts_window.rb` | yes |
| Theme selector | (part of `troll/` submodule, not in `src/`) | `lib/theme_selector.rb` | yes |
| Code panel | `PanelCode.js` | `lib/panel_code.rb` | yes |
| Style panel | `PanelStyle.js` | `lib/panel_style.rb` | yes |
| UI panel | `PanelUI.js` | `lib/panel_ui.rb` | yes |
| Preview panel | (part of window/previewer wiring) | `lib/panel_preview.rb` | yes |
| Previewer (in-process) | `Previewer/Previewer.js`, `Previewer/Internal.js` | `lib/previewer.rb`, `lib/internal_previewer.rb` | yes |
| Previewer (out-of-process) | `Previewer/External.js`, `Previewer/DBusPreviewer.js`, `Previewer/previewer.vala`, `Previewer/previewer.xml`, `Previewer/crasher.vala`, `Previewer/utils.js` | — | **no** |
| Devtools | `Devtools.js` | `lib/devtools.rb` | yes |
| Terminal console | `TermConsole.js` | `lib/term_console.rb` | yes |
| Code view widget | `widgets/CodeView.js` + `.blp` | `lib/code_view.rb` | yes (substitution: `Gtk::TextView` for `GtkSource.View` — no bindings) |
| Code-find widget | `widgets/CodeFind.js` + `.blp` | `lib/code_find.rb` | yes |
| Save-project dialog | (part of session/window flow) | `lib/save_project_dialog.rb` | yes |
| Blueprint-experimental dialog | (part of UI panel flow) | `lib/blueprint_experimental_dialog.rb` | yes |
| Settings | `common.js`/`util.js` (GSettings wiring) | `lib/settings.rb` | yes |
| Session | `sessions.js` | `lib/session.rb` | yes |
| Document base | `Document.js` | `lib/document.rb` | yes |
| Language registry | (scattered across `langs/`) | `lib/language.rb` | yes |
| Style document | `langs/css/CssDocument.js` | `lib/css_document.rb` | yes |
| XML document + formatter | `langs/xml/XmlDocument.js`, `langs/xml/xml.js` | `lib/xml_document.rb`, `lib/xml.rb` | yes |
| LSP client/doc/sourceview | `lsp/LSPClient.js`, `lsp/LSP.js`, `lsp/sourceview.js` | `lib/lsp_client.rb`, `lib/lsp.rb`, `lib/lsp_sourceview.rb`, `lib/lsp_document.rb` | yes |
| Per-language documents (JS/TS/Vala/Rust/Python/Blueprint) | `langs/javascript/JavaScriptDocument.js`, `langs/typescript/TypeScriptDocument.js`, `langs/vala/ValaDocument.js`, `langs/rust/RustDocument.js`, `langs/python/PythonDocument.js`, `langs/blueprint/BlueprintDocument.js` | `lib/javascript_document.rb`, `lib/type_script_document.rb`, `lib/vala_document.rb`, `lib/rust_document.rb`, `lib/python_document.rb`, `lib/blueprint_document.rb` | yes, but each drops its paired `Builder.js`/`Compiler.js` (project scaffolding, actual run/compile) — see component-parity |
| Flatpak permission helper | `flatpak.js` | `lib/flatpak.rb` | yes |
| Log handler | `log_handler.js` | `lib/log_handler.rb` | yes |
| **Library** (demo browser) | `Library/Library.js` + `.blp`, `Library/EntryRow.js` + `.blp`, `Library/library.svg` | — | **no** — zero references in `lib/` |
| **Extensions** (language-availability dialog) | `Extensions/Extensions.js` + `.blp`, `Extensions/Extension.js` + `.blp` | — | **no** — zero references in `lib/` |
| Permissions dialog | `Permissions/Permissions.js` + `.blp` | `lib/permissions_dialog.rb` | yes |
| Hover provider | `WorkbenchHoverProvider.js` | — | **no** |
| C preview-window widget | `libworkbench/workbench-preview-window.{c,h,blp}`, `workbench-completion-{provider,request}.{c,h}` | — | **no** (requires a GObject C extension; no Ruby equivalent built) |
| CLI (`workbench-cli` subcommand) | `cli/*.js` (format/lint/main for blueprint, css, js, py, rust, ts, vala) | — | **no** |

## Button/action referencing a missing unit

`lib/window.rb:344-350` builds `button_library` with `action_name = 'app.library'`
and a tooltip "Open Library of Demos and Examples (Ctrl+Shift+O)". `grep -rn
"library" lib/actions.rb lib/workbench/application.rb` returns nothing: no
`app.library` action is installed anywhere in the port. The button renders,
is clickable, and does nothing. This is a dead control, not a decoration —
identified here because it is the kind of gap `component-scan` text-matching
alone would miss (the widget exists; its behaviour does not).

## Existing inventory document is stale

`.reports/component-inventory.md` (last touched at `5ef5694`) predates two
landed commits — `2398e1f` (ports `flatpak.rb`, `log_handler.rb`,
`permissions_dialog.rb`) and `146e3ae` (extends the drive test) — and still
lists the Permissions dialog under "not ported at all". Anyone reading only
that document currently gets a wrong answer about Permissions. It is not
rewritten here because `component-identification`'s job is the inventory, not
the ledger; see the accountability-ensurance report for why a stale ledger
that nobody flagged is itself counted as a gap.

## What this inventory does not cover

No `gir-symbols.sh`/`component-scan.sh` re-run against the current `lib/`
tree, so CSS-class and signal-level inventory per file is not re-verified here
beyond what `component-parity` below checks by reading. The widget-level
scan in `.reports/component-inventory.md` (2569 upstream widget occurrences /
143 ported, 117 upstream types / 49 ported, 172 upstream CSS classes / 14
ported, 177 upstream signals / 30 ported) was taken at `4353dd3` and has not
been re-run since; treat those numbers as a lower bound on the current gap,
not a current measurement.
