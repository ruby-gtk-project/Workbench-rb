# Component parity — Workbench

| | |
|---|---|
| Upstream | `main` @ `1c5627b` |
| Port | `ruby` @ `146e3ae` |
| Units with parity | **0 / 31** (31 = units listed in `component-identification.md`) |

No `COMPONENT_PARITY.md` exists on `ruby` prior to this round. Nothing in the
repo claims per-unit parity today, which is itself correct — because on
inspection no unit clears all four axes (count, style, behaviour, text).

## Whole units with no counterpart (count axis: 0 of N)

| Unit | Upstream widgets involved (lead types) | Verdict |
|---|---|---|
| Library (demo browser) | `Adw.Dialog`/window, `Gtk.SearchEntry`, a filtered `Gtk.ListView`/grid of `EntryRow` (icon, title, category chip), category filter chips, "No results" status page | **gap** — zero widgets, zero signals, zero actions in the port |
| Extensions dialog | `Adw.Dialog`, five `Adw.ActionRow`-style language rows (JavaScript/Python/Rust/Vala/TypeScript) each with a status icon and a "Run the following command" label + copyable command | **gap** |
| Hover provider | n/a (editor behaviour, not a dialog) — diagnostic/doc hover on the code view | **gap** |
| Out-of-process previewer | External.js/DBusPreviewer.js/the two Vala binaries, which run user code in a separate process and only hand back a snapshot/crash report | **gap** — `lib/previewer.rb:23` says plainly it is not ported; the in-process previewer runs user markup inline in the host process instead, which is a different trust and crash-isolation model, not a substitution |
| C preview-window widget (`libworkbench`) | `workbench-preview-window.blp`, completion provider/request | **gap** — no Ruby equivalent; nothing calls into it |
| CLI (`workbench-cli`) | n/a widgets, but `app.library`/format/lint entry points | **gap** |
| `app.library` action | installs on `Gio::SimpleAction` upstream; `button_library` in `lib/window.rb:344` targets `app.library` | **gap** — button exists, action does not; dead control |

## Units built, but failing the behaviour or style axis

### Per-language documents (`vala_document.rb`, `rust_document.rb`, `type_script_document.rb`, `python_document.rb`, `javascript_document.rb`, `blueprint_document.rb`)

- **Count**: the `Document` subclass exists for each language — count parity on the class level.
- **Style**: not separately checked this round.
- **Behaviour**: each upstream document pairs with a `Builder.js`/`Compiler.js`
  that does project scaffolding (`setupRustProject`, `setupTypeScriptProject`,
  jsconfig scaffolding) and actually runs/compiles the code. None of the six
  ports does this — `lib/window.rb:43` states plainly "the per-language
  builders and compilers ... are not ported", and `Window#run` only formats
  and redraws the preview, it does not execute anything. **gap**: the single
  most central verb of this app — "run the code" — does not run code for any
  of these six languages in the port.
- **Behaviour**: the Extensions-gate check upstream (`isRustAvailable()` etc.,
  which the Extensions dialog surfaces to the user as install instructions)
  is replaced by "just try to start the language server and log if missing" —
  the user gets a log line, not the Extensions dialog's actionable command.
  **gap**, compounding the missing Extensions unit above.

### Code view (`lib/code_view.rb`)

- **Count**: 1 widget, matches.
- **Style**: `Gtk::TextView` substituted for `GtkSource.View` because the dev
  shell has no GtkSourceView bindings. This drops syntax highlighting, style
  schemes, and (per `component-inventory.md`) more that was not re-checked
  this round. Per the `component-parity` skill this is a substitution that
  must be recorded with a reason — it is recorded in the file, but it is a
  real, large style/behaviour gap, not a neutral correspondence, because
  `GtkSource.View` is not "a strictly newer equivalent" of `Gtk::TextView` —
  it is a materially more capable widget upstream actually ships. **gap**,
  correctly flagged by the port, still a gap.

### Permissions dialog (`lib/permissions_dialog.rb`)

- The only check this unit has is `d.check('permissions dialog built without
  raising') { true }` in `test/drive_workbench.rb:300`. That assertion is
  true unconditionally the moment the method returns without an exception —
  it does not open the dialog, does not inspect a row, does not click a
  toggle. **No behaviour in this unit is actually driven.** Same pattern for
  the about dialog (`test/drive_workbench.rb:181`) and shortcuts dialog
  (`:192`): `{ true }` checks prove construction didn't throw, nothing else.
  Counting these as "parity" or as evidence a unit works is the false-green
  pattern `accountability-ensurance` exists to catch; recorded here against
  the component and there against the drive gate.

### Library button (`lib/window.rb`)

- **Count/Style**: the button itself is built (type, icon substitution, CSS
  class `view-toggler`-style flat button) and reasonably faithful.
- **Behaviour**: `action_name = 'app.library'` resolves to nothing. **gap.**
- **Text**: tooltip text is original English prose ("Open Library of Demos
  and Examples (Ctrl+Shift+O)"), not upstream's marked string (upstream has
  no literal tooltip of this form to begin with for this button — it is a
  `GtkButton` with an icon/label pair in `window.blp`). Not scored as a
  translation gap on its own since it doesn't correspond to an upstream
  msgid, but flagged because the shortcut it advertises, Ctrl+Shift+O, opens
  nothing.

## Stylesheet

`lib/style.rb` (105 lines) vs upstream `src/style.css` (66 lines) were not
diffed rule-by-rule this round (time-boxed); given the Library/Extensions/
preview-window units are entirely unbuilt, any CSS those units' `.blp` files
define (`Extensions/Extensions.blp`, `Library/Library.blp`,
`libworkbench/workbench-preview-window.blp` each carry their own `<style>`
blocks) cannot be attached to anything in the port and is a style gap by
construction, inherited from the missing-unit gaps above rather than an
independent finding.

## Summary

No unit in this app currently has four-axis parity. The three largest gaps by
user impact are: (1) the Library demo browser does not exist, (2) the
Extensions dialog does not exist and the language-availability UX it
provides is silently downgraded to a log message, and (3) **no ported
language actually runs or compiles code** — the single core verb of a code
playground app. All three predate this round and are carried forward, not
newly found, but none of them is written down as a tracked gap anywhere
except in prose inside the source files and the stale `component-inventory.md`.
