# Component parity ledger — Workbench-rb

Root-level summary; see `.reports/component-parity.md` and
`.reports/component-identification.md` for the full per-round analysis this
distills, and `PORTING.md` for the up-to-date ported/unported split.

## This round's changes

- Fixed `LibraryWindow.demos_dir` (lib/library_window.rb): it resolved two
  directories up from `lib/` instead of one (`../../data/demos` instead of
  `../data/demos`), so it pointed outside the gem entirely
  (`.../ruby-gtk-project/data/demos`) regardless of whether a corpus was
  vendored. Fixed, and a real demo corpus is now vendored at `data/demos`
  (see `build-aux/vendor_demos.rb`), so `LibraryWindow.demos` returns ~116
  real demos for every user, not zero.
- Replaced the three vacuous drive checks (`{ true }`, cannot fail by
  construction) with real assertions on rendered dialog state: the About
  dialog's `application_name`/`version`/`debug_info`, the Keyboard Shortcuts
  dialog's title and identity, and the Permissions dialog's heading and
  command text.
- Added a drive check against the real `data/demos` corpus (not only the
  fixture corpus the rest of the Library drive steps stock), so the gate
  would have caught the `demos_dir` bug above.

## Still open (see PORTING.md "Known-unported" for consequences)

- No language actually runs (`Window#run` never compiles/executes).
- External/DBus previewer, the two Vala preview binaries — unported.
- `libworkbench`'s C preview-window widget — binding limitation (no C
  extension build in this stack).
- `WorkbenchHoverProvider.js` — binding limitation (`GtkSource.HoverProvider`
  not exposed by the GI binding in use).
- CLI subcommands — unported.
