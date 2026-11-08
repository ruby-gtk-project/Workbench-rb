# Component identification — Workbench

| | |
|---|---|
| Upstream | `origin/main` @ `1c5627b` |
| Port | `ruby` @ `4948c35` |
| Method | directory diff + targeted reads of `lib/*.rb` against `origin/main:src/**`. `gir-symbols.sh`/`component-scan.sh` were not re-run this round (see `component-inventory.md` for the last full scan, taken at `4353dd3` — stale by several commits, including the two that landed Library/Extensions; treat its counts as a lower bound, not current). |

Upstream is a GJS (JavaScript) app, not Vala — `src/**/*.js` paired with
`src/**/*.blp`, plus two Vala helper processes and one C widget library
(`src/libworkbench/`). 148 files under `src/`, ten `.blp` templates, no
GResource manifest for the app itself. Two submodules, `troll/` and `demos/`,
also contribute real UI and real data and are not checked out in this clone
(`demos` is a gitlink with 0 files on disk here), so neither was scanned.

The port has 47 files under `lib/` + `exe/workbench`.

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
| **Previewer (out-of-process)** | `Previewer/External.js`, `Previewer/DBusPreviewer.js`, `Previewer/previewer.vala`, `Previewer/previewer.xml`, `Previewer/crasher.vala`, `Previewer/utils.js` | — | **no** — `lib/previewer.rb:23-25` says so plainly |
| Devtools | `Devtools.js` | `lib/devtools.rb` | yes |
| Terminal console | `TermConsole.js` | `lib/term_console.rb` | yes |
| Code view widget | `widgets/CodeView.js` + `.blp` | `lib/code_view.rb` | yes (substitution: `Gtk::TextView` for `GtkSource.View` — no bindings in this dev shell) |
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
| Per-language documents (JS/TS/Vala/Rust/Python/Blueprint) | `langs/javascript/JavaScriptDocument.js`, `langs/typescript/TypeScriptDocument.js`, `langs/vala/ValaDocument.js`, `langs/rust/RustDocument.js`, `langs/python/PythonDocument.js`, `langs/blueprint/BlueprintDocument.js` | `lib/javascript_document.rb`, `lib/type_script_document.rb`, `lib/vala_document.rb`, `lib/rust_document.rb`, `lib/python_document.rb`, `lib/blueprint_document.rb` | yes, but each drops its paired `Builder.js`/`Compiler.js` (project scaffolding, actual run/compile) — see `component-parity.md` |
| Flatpak permission helper | `flatpak.js` | `lib/flatpak.rb` | yes |
| Log handler | `log_handler.js` | `lib/log_handler.rb` | yes |
| **Library** (demo browser) | `Library/Library.js` + `.blp`, `Library/EntryRow.js` + `.blp`, `Library/library.svg` | `lib/library_window.rb`, `lib/entry_row.rb` | **yes, structurally — but see "Library has no data" below** |
| **Extensions** (language-availability dialog) | `Extensions/Extensions.js` + `.blp`, `Extensions/Extension.js` + `.blp` | `lib/extensions_dialog.rb`, `lib/extension_row.rb` | yes |
| Permissions dialog | `Permissions/Permissions.js` + `.blp` | `lib/permissions_dialog.rb` | yes |
| **Hover provider** | `WorkbenchHoverProvider.js` | — | **no** — `GtkSource.HoverProvider` has no Ruby binding in this stack |
| **C preview-window widget** | `libworkbench/workbench-preview-window.{c,h,blp}`, `workbench-completion-{provider,request}.{c,h}` | — | **no** — requires a GObject C extension; no Ruby equivalent built, and nothing calls into it |
| **CLI** (`workbench-cli` subcommand) | `cli/*.js` (format/lint/main for blueprint, css, js, py, rust, ts, vala) | — | **no** |

Since the last identification round (`146e3ae`), two commits
(`70c891e`→`44b37e4`) landed the Library window and Extensions dialog. The
table above reflects that; the two items marked "no" in the prior round are
now "yes" above and have been re-checked against current `lib/` rather than
carried forward.

## Library has no data

`lib/library_window.rb:51` defines `demos_dir` as
`File.expand_path('../../data/demos', __dir__)`. **`data/demos` does not
exist anywhere in this repository** — upstream's `demos/` is a git submodule
(a gitlink commit, 0 files checked out in this clone) that Meson stages into
`pkg.pkgdatadir/demos` at install time; the port has no install step that
stages it and has not vendored a copy either. Confirmed:

```
$ find data -maxdepth 3        # no such directory at all
$ git ls-tree -r origin/main | grep '^demos/'   # 0 rows — it's a submodule, not files
```

So the Library window, as shipped on this branch, opens onto a real,
functioning widget tree with **zero demos in it**, every time, for every
user. `test/drive_workbench.rb` does not exercise the real path — it
monkey-patches `LibraryWindow.demos_dir` to a temp directory it writes a
synthetic fixture into (see `test/drive_workbench.rb:403-422`) before opening
the window. The structural port (the dialog, the search entry, the empty-
state placeholder, the row widget, opening a demo into a new session) is real
and does work on *some* data; it has never been driven, by any check in this
repo, against the actual upstream demo corpus, because that corpus isn't
here. This is recorded as a unit-level gap on the "data/content parity" axis
even though the widget-identification axis (type/CSS/signal/action) passes —
see `component-parity.md`.

## Button/action referencing a missing unit — resolved

The prior round flagged `lib/window.rb`'s `button_library` as wired to
`action_name = 'app.library'` with no action installed. That is fixed:
`lib/actions.rb:68` now installs `library_window.install_action`, and
`library_window` is memoized at `lib/actions.rb:86-88`. The button is live.

## What this inventory does not cover

No `gir-symbols.sh`/`component-scan.sh` re-run against the current `lib/`
tree this round, so CSS-class and signal-level inventory per file is not
re-verified beyond what `component-parity.md` checks by reading. Treat the
widget/CSS/signal counts in `component-inventory.md` (taken at `4353dd3`) as
a lower bound on the current gap, not a current measurement — they predate
Library and Extensions entirely.
