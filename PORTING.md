# Porting ledger — Workbench-rb

Upstream: https://github.com/sonnyp/Workbench (ref: `origin/main` in this fork).
This file is the root-level summary of where the port stands; it is updated
whenever a component lands or a gap closes, not just by audit rounds. The
detailed per-round analysis lives in `.reports/`.

See also `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md` and
`FINDINGS.md`.

## Ported (present and wired into the real entry point)

Window chrome, documents and panels: `window.rb`, `panel_code.rb`,
`panel_style.rb`, `panel_ui.rb`, `panel_preview.rb`, `code_view.rb`,
`code_find.rb`, `term_console.rb`, every `*_document.rb` (xml, blueprint,
javascript, typescript, vala, rust, python, css), `lsp.rb` /
`lsp_client.rb` / `lsp_sourceview.rb`.

Dialogs and windows: `about_dialog.rb`, `shortcuts_window.rb`,
`permissions_dialog.rb`, `extensions_dialog.rb` + `extension_row.rb`,
`library_window.rb` + `entry_row.rb`, `save_project_dialog.rb`,
`blueprint_experimental_dialog.rb`.

Backends: `session.rb`, `settings.rb`, `flatpak.rb`, `previewer.rb` (internal
previewer only — see below), `internal_previewer.rb`, `xml.rb`, `actions.rb`,
`app_menu.rb`, `theme_selector.rb`, `devtools.rb`, `style.rb`,
`log_handler.rb`, `language.rb`.

The Library window's demo corpus (`data/demos`) is vendored from
`workbenchdev/demos.git` by `build-aux/vendor_demos.rb` (a port of upstream's
`build-aux/library.js`), so `LibraryWindow.demos` returns the real ~116-demo
corpus at runtime, not only the drive script's fixture.

## Known-unported, with the user-facing consequence (not just "missing")

- **No language actually runs.** `Window#run` (lib/window.rb) clears the
  console, formats the visible documents and redraws the preview for all six
  languages (Rust, TypeScript, Vala, Python, JavaScript, Blueprint) but never
  invokes a compiler or interpreter. The per-language `Builder.js`/
  `Compiler.js` scaffolding (`src/langs/*/{Builder,Compiler}.js`) is
  unported. This is the core verb of a code-playground app, not yet present.
- **Out-of-process previewing.** `External.js`, `DBusPreviewer.js` and the
  two Vala preview-process binaries are unported; only the in-process
  `InternalPreviewer` exists, so a demo whose previewed widget is defined in
  Vala/Rust/Python source (not the UI panel's XML) cannot be previewed.
- **Safe mode is cosmetic.** The `safe-mode` session key is stored and shown,
  but `workbench-crasher` (src/Previewer/crasher.vala) never runs it — a
  crashing preview definition takes this whole process down.
- **The C preview-window widget** (`libworkbench`'s
  `workbench-preview-window.blp/.c`) is unported. It needs a GObject C
  extension this stack does not build; a documented binding limitation, not
  a port in progress.
- **The diagnostic hover provider** (`WorkbenchHoverProvider.js`) is
  unported. It needs `GtkSource.HoverProvider`, which the current
  `gtksourceview4`/`gtksourceview5` GI binding does not expose to Ruby; a
  documented binding limitation.
- **CLI subcommands** (`re.sonny.Workbench --new`, `--open`, etc. as
  upstream's `src/cli.js` wires them) are unported; `exe/workbench` only
  launches the GUI.
- **Per-language project scaffolding on language switch** (jsconfig.json,
  Cargo.toml, tsconfig.json) is unported — `PanelCode` switches the editor
  and previewer but writes no project files.

## Gems

`ashpd` (`Ashpd`) and `libshumate` (`Shumate`) are both required under `lib/`
(`lib/actions.rb`, `lib/previewer.rb`) and exercised on the live code path by
the drive script (`test/drive_workbench.rb`: the ashpd portal-fallback check
and the `Shumate::SimpleMap` probe). Verified this round with
`nix develop --command ruby -e 'require "ashpd"; ...; require "libshumate"; ...'`
— both load and expose their real namespaces (`Ashpd` 7 constants, `Shumate`
56 constants).
