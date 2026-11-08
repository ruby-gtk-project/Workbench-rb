# Findings ledger — Workbench-rb

Root-level record of defects found and fixed during porting rounds, kept
alongside `PORTING.md`, `COMPONENT_PARITY.md`, `TEST_PARITY.md` and
`TRANSLATION_PARITY.md`. See `.reports/accountability-ensurance.md` for the
full per-round audit this distills.

## This round

- **`LibraryWindow.demos_dir` pointed outside the gem.**
  `File.expand_path('../../data/demos', __dir__)` in lib/library_window.rb
  resolves two directories above `lib/`, landing on
  `.../ruby-gtk-project/data/demos` (the *parent* of this checkout) rather
  than `Workbench-rb/data/demos`. Combined with no corpus having been
  vendored at all, every real user saw zero demos in the Library window;
  the only test coverage of this path monkey-patched `demos_dir` to a
  fixture and so never exercised the real default. Fixed the path (one `..`
  too many) and vendored a real corpus from `workbenchdev/demos.git` via
  `build-aux/vendor_demos.rb`, then added a drive check against the
  unpatched default (`LibraryWindow.demos_dir`/`.demos`) before the fixture
  is stocked.
- **Three drive checks were vacuous by construction** (`{ true }`): "about
  dialog built without raising", "shortcuts dialog built without raising",
  "permissions dialog built without raising". Replaced with assertions on
  each dialog's real rendered state (see COMPONENT_PARITY.md). A fourth
  near-miss noticed but left as-is: the Blueprint-experimental step's check
  reads `active_window.title` and discards it as a liveness probe — the
  same pattern, but not one of the three named vacuous checks, so left for
  a future round.
- Confirmed `ashpd`/`libshumate` wiring (gemspec, `nix/Gemfile`,
  `flake.nix` typelibs) was already correct from a prior round; both
  `require`d under `lib/`, both exercised by real drive assertions (not a
  blanket-rescued fallback or a stubbed drive step), both load cleanly via
  `nix develop --command ruby -e 'require "ashpd"/"libshumate"; ...'`. No
  regression found, no action needed beyond re-verifying.
