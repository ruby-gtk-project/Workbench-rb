# Component parity — Workbench

| | |
|---|---|
| Upstream | `main` @ `1c5627b` |
| Port | `ruby` @ `4948c35` |
| Units with full (count + style + behaviour + text) parity | **0 / 29** (29 = implemented units in `component-identification.md`; 4 more units upstream has — out-of-process previewer, hover provider, C preview-window widget, CLI — are not implemented at all and so cannot even be scored) |

## Whole units with no counterpart at all (count axis: 0 of N)

| Unit | Upstream widgets involved (lead types) | Verdict |
|---|---|---|
| Out-of-process previewer | `External.js`/`DBusPreviewer.js`/the two Vala binaries, which run user code in a separate process and only hand back a snapshot/crash report | **gap** — `lib/previewer.rb:23-25` says plainly it is not ported; the in-process previewer runs user markup inline in the host process instead, which is a different trust and crash-isolation model, not a substitution |
| C preview-window widget (`libworkbench`) | `workbench-preview-window.blp`, completion provider/request | **gap** — no Ruby equivalent; nothing calls into it |
| Hover provider | diagnostic/doc hover on the code view (`WorkbenchHoverProvider.js`) | **gap** — `GtkSource.HoverProvider` has no Ruby binding available |
| CLI (`workbench-cli`) | n/a widgets, but format/lint entry points | **gap** |

## Units built this round that still fail an axis

### Library (demo browser) — `lib/library_window.rb`, `lib/entry_row.rb`

- **Count/style**: the dialog, search entry, filtered list, empty-results
  placeholder, and `EntryRow` (icon/title/category) are all built, with the
  `app.library` action now installed and wired to a real button
  (`lib/window.rb:338-346`, `lib/actions.rb:68,86-88` — the dead-control gap
  the prior round flagged is fixed).
- **Behaviour/data**: `demos_dir` (`lib/library_window.rb:51`) points at
  `data/demos`, which **does not exist in this repository** — upstream's
  `demos/` is a submodule, never vendored or staged by this gem. The result
  is a structurally complete window that shows zero demos for every real
  user, every time. **gap**, on the data axis specifically — see
  `component-identification.md` for the filesystem check.
- One piece of upstream's `openDemo` flow is still not reached: permissions
  pre-flighting (`needsAdditionalPermissions`/`showPermissionsDialog`).
  `PermissionsDialog` exists but is wired to an already-open window, not to
  gate opening one — a demo needing Flatpak permissions it doesn't have
  opens unconditionally. **gap**, smaller, noted in the file's own header
  comment.

### Extensions dialog — `lib/extensions_dialog.rb`, `lib/extension_row.rb`

- **Count/style/behaviour**: five language rows, each with a real
  `/usr/lib/sdk/<extension>` availability check (`ExtensionsDialog.vala_available?`
  etc., confirmed exercised by `test/drive_workbench.rb:397-401` against the
  actual filesystem, not a stub) and a real `flatpak install` command string
  for unavailable ones. This unit reads as genuinely built and genuinely
  checked, not just constructed. No gap found on this unit's own four axes.
- `lib/extensions_dialog.rb:15` carries its own comment admitting upstream's
  own `// FIXME` about never finishing reading availability from the
  manifest is itself never finished in the port either — a second-order gap
  worth flagging but not new to this unit; it's an upstream debt inherited
  unmodified, correctly labeled as such rather than silently dropped.

### Per-language documents (`vala_document.rb`, `rust_document.rb`, `type_script_document.rb`, `python_document.rb`, `javascript_document.rb`, `blueprint_document.rb`)

- **Count**: the `Document` subclass exists for each language — count parity
  at the class level.
- **Behaviour**: each upstream document pairs with a `Builder.js`/`Compiler.js`
  that does project scaffolding (`setupRustProject`, `setupTypeScriptProject`,
  jsconfig scaffolding) and actually runs/compiles the code. None of the six
  ports does this. **Confirmed still true at `4948c35`**:
  `lib/window.rb:176-196`'s `run` method clears the console, formats visible
  documents, and redraws the preview — it does not invoke a compiler or
  interpreter for any of the six languages. The single most central verb of
  this app — "run the code" — does not run code. **gap.**
- The Extensions-gate check upstream (`isRustAvailable()` etc.) is now
  properly surfaced through the Extensions dialog (see above) rather than
  silently downgraded to a log line, which **narrows** this gap from the
  prior round's finding — the per-language documents still start their
  language servers directly without checking availability first
  (`vala_document.rb` etc. still just try-and-log), but the user now has an
  Extensions dialog to consult. Partial improvement, not a close.

### Code view (`lib/code_view.rb`)

- `Gtk::TextView` substituted for `GtkSource.View` (no GtkSourceView bindings
  in this dev shell). Drops syntax highlighting and style schemes. Recorded
  by the port itself, still a real style/behaviour gap, not a neutral
  substitution. **gap**, unchanged from the prior round.

### About / Shortcuts / Permissions dialogs

- All three build without raising. The *only* runtime check exercising any
  of them is, verbatim, `d.check('... built without raising') { true }`
  (`test/drive_workbench.rb:182`, `:193`, `:377` at current `HEAD`) — a
  hardcoded `true` that passes regardless of what the dialog actually shows.
  This is **not evidence of behaviour or text parity** for any of the three;
  it is evidence the constructor didn't throw. See
  `accountability-ensurance.md` for why this is counted as a false-green
  risk in the runtime gate, not just a thin test.

## Stylesheet

`lib/style.rb` (105 lines) vs upstream `src/style.css` (66 lines) were not
diffed rule-by-rule this round (time-boxed, same as the prior round). Given
the C preview-window and out-of-process previewer remain entirely unbuilt,
any CSS their `.blp` files define cannot be attached to anything in the port
and is a style gap by construction, inherited from the unit-level gaps above.

## Summary

Two whole units (Library, Extensions) moved from "doesn't exist" to "exists
and mostly works" since the prior round — real progress, confirmed by
reading the current source and by two runtime checks that assert against
real filesystem state rather than fixtures (the Extensions SDK-availability
checks). But:

1. The Library window's only data source does not exist in this repo, so
   the unit is functionally empty for every real user even though its
   widget tree is complete.
2. No ported language actually runs or compiles code — still the single
   largest behavioural gap in the app, unchanged from the prior round.
3. Three dialogs (About, Shortcuts, Permissions) have no check that verifies
   anything beyond "didn't crash."
4. The out-of-process previewer, the C preview-window widget, the hover
   provider, and the CLI remain entirely unported.

No unit in this app has four-axis parity with upstream today.
