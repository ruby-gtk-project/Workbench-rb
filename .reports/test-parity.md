# Test parity — Workbench

| | |
|---|---|
| Upstream | `main` @ `1c5627b` |
| Port | `ruby` @ `146e3ae` |
| Upstream tests | 12 (named `test(...)` blocks across `test/*.test.js`) |
| Ported | 0 |
| Gaps | 12 |
| Test command (port) | `nix develop --command xvfb-run -a ruby test/drive_workbench.rb` (and `test/drive_window.rb`) — these are drive scripts, not unit tests; `rspec` finds zero examples (`spec/` has only a harness `spec_helper.rb`), and `test/` has no `test_*.rb` unit-test files either |

## Upstream census

Upstream's test runner is a custom harness (`troll/tst/tst.js`, from the
`troll` submodule), invoked as `test("name", () => { ...assert.fixture(...) })`.
Treating each named `test(...)` call as the assertion unit (matching the
`it(...)` convention this skill names for Jasmine-style suites):

| # | File | Test | Purpose | Port test | State |
|---|---|---|---|---|---|
| 1 | `test/isDeviceInputOverrideAvailable.test.js:9` | `returns a boolean` | return type contract | — | **gap** |
| 2 | `test/isDeviceInputOverrideAvailable.test.js:13` | `returns true if Flatpak version is equal to 1.15.6` | version-gate boundary, equal case | — | **gap** |
| 3 | `test/isDeviceInputOverrideAvailable.test.js:17` | `returns true if Flatpak version is higher than 1.15.6` | version-gate boundary, above case | — | **gap** |
| 4 | `test/isDeviceInputOverrideAvailable.test.js:23` | `returns false if Flatpak version is lower than 1.15.6` | version-gate boundary, below case | — | **gap** |
| 5 | `test/isDiagnosticInRange.test.js:9` | `in range` | LSP diagnostic range containment, inside case | — | **gap** |
| 6 | `test/isDiagnosticInRange.test.js:33` | `same line` | same-line range edge case | — | **gap** |
| 7 | `test/isDiagnosticInRange.test.js:57` | `between lines` | multi-line range case | — | **gap** |
| 8 | `test/isDiagnosticInRange.test.js:81` | `not in range` | negative case | — | **gap** |
| 9 | `test/xml.test.js:10` | `format` | XML/blueprint-XML pretty-printer, 4 fixture cases | — | **gap** |
| 10 | `test/xml.test.js:107` | `invalid documents` | formatter raises on 6 malformed inputs | — | **gap** |
| 11 | `test/xml.test.js:133` | `library examples` (upstream `test.skip`) | round-trips every Library demo's XML through the formatter | n/a — upstream itself skips this one | **gap** (upstream-skipped; not counted toward the owed total but listed for completeness) |
| 12 | `test/previewer.test.js:11` | `getObjectClass` | resolves a GObject class name from a tag/namespace pair | — | **gap** |

Owed count (excluding the one upstream already skips): **11 of 12**, plus the
skipped one carried forward as a note. Call it 11/11 gaps against the live
upstream suite.

## Why these are real gaps, not "doesn't apply to Ruby"

Three of the four source modules under test are things the port actually
ported, under different names:

- `isDeviceInputOverrideAvailable` (Flatpak version gate) → `lib/flatpak.rb`
  almost certainly reimplements this comparison (it is the flatpak helper the
  port ported in `2398e1f`). No Ruby test exercises the equal/above/below
  boundary the upstream test pins.
- `xml.js`'s `format` → `lib/xml.rb` (confirmed ported, has its own header
  comment). The formatter is live in the port (the UI panel's XML path uses
  it) and has zero unit tests of its own; its only exercise is indirectly,
  through `test/drive_workbench.rb`'s single XML-editing check (line 246-254),
  which asserts the buffer round-trips one string — not the 4 format fixtures
  or 6 invalid-document cases upstream pins.
- `isDiagnosticInRange` → almost certainly reimplemented inside
  `lib/lsp.rb`/`lib/lsp_sourceview.rb` to decide whether a diagnostic applies
  to the cursor's position. Zero Ruby tests of the boundary logic.
- `getObjectClass` (previewer) → `lib/previewer.rb`/`lib/internal_previewer.rb`.
  Zero Ruby tests.

None of these is "C-specific plumbing" or GObject-interface machinery that
Ruby's GC makes moot — they are small, pure, easily-portable functions with
documented edge cases upstream found worth pinning (an off-by-one on a
Flatpak version string, a diagnostic that starts on the line after the one
being checked). They are exactly the kind of test that is cheapest to port
and most valuable to keep, and none of the 12 exist in Ruby.

## The port's own test suite

`test/drive_workbench.rb` (32 `check(...)` calls) and `test/drive_window.rb`
(a GTK-driving helper, 0 assertions of its own — it is infrastructure, matched
by the `*driver*`/`*helper*` exclusion in `test-census.sh` and correctly not
counted) are end-to-end smoke checks of the live app, driven through
`test/gtk_driver.rb`. They are useful and they are **not substitutes for**
the 12 upstream unit tests above: an E2E check that "the buffer round-trips an
edit" cannot also stand in for "the formatter raises on 6 specific malformed
XML documents", because the E2E check never feeds any of those 6 documents in.

Three of the 32 checks are vacuous and do not actually test what their name
claims (see `component-parity.md` and `accountability-ensurance.md` for the
detail): `about dialog built without raising`, `shortcuts dialog built
without raising`, `permissions dialog built without raising` are all
`{ true }` — these pass regardless of whether the dialog shows anything
correct. Counting them toward "32 checks passed" overstates how much of the
app the runtime gate actually verifies. Treat the effective driven-check
count as 29, not 32, until those three are replaced with a real assertion
(e.g. that the dialog's title/heading widget holds the expected text).

The runtime gate's "21 components" also undercounts against
`component-identification.md`'s 31-unit list: Library, Extensions, the hover
provider, the out-of-process previewer, and the CLI are driven by zero
checks, because they do not exist to drive. A component no check exercises
is unverified, not done — stated here per the task's framing, and it also
means the 21/21 claim is a claim about a smaller app than upstream actually
is.

## RSpec / Minitest harness

`spec/spec_helper.rb` loads `kettle/test/rspec` but `spec/` contains no
`*_spec.rb` files — `bundle exec rspec` (or the project's own `rake` test task)
would report **0 examples, 0 failures**, which is a suite that has never
actually asserted anything and would read as green. This is the exact
"a suite that has never been executed is a gap" case the task calls out
explicitly: there is no spec suite here to execute, full stop — the
scaffolding is present and empty.

## Verdict

**0/12 upstream tests ported.** The runtime drive gate (32 checks, trimmed to
29 real ones) is a separate, smaller, E2E safety net that does not substitute
for unit coverage of the ported pure-function logic, and three of
`component-identification.md`'s biggest gaps (Library, Extensions, the
out-of-process previewer) have no test coverage of any kind because they have
no implementation of any kind.
