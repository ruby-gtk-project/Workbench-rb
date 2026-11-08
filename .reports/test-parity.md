# Test parity — Workbench

| | |
|---|---|
| Upstream | `main` @ `1c5627b` |
| Port | `ruby` @ `4948c35` |
| Upstream tests | 12 (named `test(...)` blocks across `test/*.test.js`) |
| Ported (RSpec/unit) | 0 |
| Gaps | 11 owed (1 upstream-skipped, carried as a note, not owed) |
| Test command (unit) | `ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` — **run fresh this round: `0 examples, 0 failures`** |
| Test command (E2E) | `nix develop --command xvfb-run -a ruby test/drive_workbench.rb` (and `test/drive_window.rb`) — drive scripts, not unit tests |

## Upstream census

Upstream's test runner is a custom harness (`troll/tst/tst.js`, from the
`troll` submodule), invoked as `test("name", () => { ...assert.fixture(...) })`.
Treating each named `test(...)` call as the assertion unit:

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
| 11 | `test/xml.test.js:133` | `library examples` (upstream `test.skip`) | round-trips every Library demo's XML through the formatter | n/a — upstream itself skips this one | note, not owed |
| 12 | `test/previewer.test.js:11` | `getObjectClass` | resolves a GObject class name from a tag/namespace pair | — | **gap** |

Owed count: **11 of 12** (excluding the upstream-skipped one).

## Why these are real gaps, not "doesn't apply to Ruby"

Four of the source modules under test map onto things the port actually
built, under different names, none of which carries the upstream unit test
with it:

- `isDeviceInputOverrideAvailable` (Flatpak version gate) → `lib/flatpak.rb`.
  No Ruby test exercises the equal/above/below version-string boundary.
- `xml.js`'s `format` → `lib/xml.rb` (confirmed ported, own header comment,
  live in the UI panel's XML path). Its only exercise is one indirect check
  in `test/drive_workbench.rb` (the buffer round-trips one edited string) —
  not the 4 format fixtures or 6 invalid-document cases upstream pins.
- `isDiagnosticInRange` → almost certainly reimplemented inside
  `lib/lsp.rb`/`lib/lsp_sourceview.rb`. Zero Ruby tests of the boundary.
- `getObjectClass` (previewer) → `lib/previewer.rb`/`lib/internal_previewer.rb`.
  Zero Ruby tests — and this is the function the drive suite's own Shumate
  check (`test/drive_workbench.rb:280-283`) exercises at the integration
  level for exactly one class name, which is not a substitute for the
  upstream unit test's edge cases.

None of these is GObject-interface plumbing Ruby's GC makes moot — they are
small, pure, portable functions with documented edge cases upstream found
worth pinning. They are the cheapest tests to port and none of the 12 exist
in Ruby.

## RSpec / Minitest harness — run fresh this round

`spec/` contains `spec_helper.rb` and `README.md` only — **no `*_spec.rb`
files anywhere in the tree.** Ran it directly in the dev shell this round:

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; \
    exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
NOTE: kettle-test isn't installed; running with plain RSpec.
No examples found.
Finished in 0.00199 seconds
0 examples, 0 failures
```

`0 examples, 0 failures` is a **suite that has never asserted anything and
reads as green.** This is precisely the "a suite that has never been
executed is a gap" case — except here it has been executed, in this round,
and confirmed empty, so it is not a hypothetical: there is no unit-level
Ruby test coverage of this port at all, full stop.

## The port's own test suite — run fresh this round, and found flaky

`test/drive_workbench.rb` has 45 `d.check(...)` calls (matches the runtime
gate's claimed "45 checks"); `test/drive_window.rb` has 0 (it's a smaller,
separate drive script exercising the window/panel-switching path, also with
its own `d.check(...)` calls counted separately — see its own output, not
part of the 45). Both are end-to-end smoke checks of the live app, driven
through `test/gtk_driver.rb`, not unit tests.

Ran `test/drive_workbench.rb` **four times** in the dev shell this round:

| Run | Result |
|---|---|
| 1 | `45 of 45 checks passed` then **`errored step: watchdog timeout` → `DRIVE FAILED (1)`** |
| 2 | `45 of 45 checks passed` → `DRIVE OK` |
| 3 | `45 of 45 checks passed` → `DRIVE OK` |
| 4 | `45 of 45 checks passed` → `DRIVE OK` |

**The suite is flaky: 1 of 4 runs failed**, after all 45 checks had already
reported passing, on a watchdog timeout hanging off the final step (closing
an edited session's confirmation dialog). This matters for exactly the
reason the task's runtime-gate framing calls out: a gate that is
intermittently red is not the same claim as a gate that is reliably green,
and "45 checks passed, 0 failed" taken from a single run overstates the
suite's actual reliability. This is a genuine, reproducible-on-this-machine
finding, not a one-off fluke from an unrelated host hiccup — it reproduced
with the identical final step hanging the process until the watchdog fired.

Three of the 45 checks are vacuous and do not test what their name claims
(see `component-parity.md` and `accountability-ensurance.md`): `about
dialog built without raising`, `shortcuts dialog built without raising`,
`permissions dialog built without raising` are each literally
`{ true }` — they pass regardless of what the dialog shows. Treat the
effective, meaningful driven-check count as 42, not 45.

The runtime gate's "30 components" also does not reach: Library's demo
content (no corpus ships — see `component-identification.md`), the
out-of-process previewer, the hover provider, the C preview-window widget,
and the CLI are driven by zero checks, because the first has no real data
and the rest do not exist to drive. A component no check exercises is
unverified, not done.

## Verdict

**0/12 upstream unit tests ported.** The runtime drive gate (45 checks,
effectively 42 meaningful ones) is a separate, E2E safety net that does not
substitute for unit coverage of the ported pure-function logic, is flaky on
this machine (1 failure in 4 runs, after-the-fact watchdog timeout), and
does not exercise the units that remain unported or undata'd.
