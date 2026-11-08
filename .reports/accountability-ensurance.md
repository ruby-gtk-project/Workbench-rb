# Accountability ensurance — Workbench

| | |
|---|---|
| Upstream | `main` @ `1c5627b` |
| Port | `ruby` @ `4948c35` |

Scanned `lib/`, `exe/`, `.reports/`, and the repo root for `TODO`, `FIXME`,
`not implemented`, `for now`, `in a future`, `not ported`, `dropped
deliberately`, `out of scope`, `by design`, `simplified`, `n/a`, `does not
carry over` and related constructions. No `PORTING.md` exists in this repo
at any commit.

## 1 — Excuse hits in source comments (re-scanned this round)

```
$ grep -rn "TODO\|FIXME\|not implemented\|for now\|in a future\|not ported\|no Ruby" lib exe
lib/previewer.rb:24:  # lib/external_previewer.rb and lib/dbus_previewer.rb are not ported yet, so
lib/previewer.rb:31:  # and is not ported, so the session's `safe-mode` key is stored and shown but
lib/extensions_dialog.rb:15:# upstream's own FIXME comment never finished reading it from the manifest)
lib/panel_code.rb:19:  # modules are not ported, so switching language here switches the editor and
lib/window.rb:44:# to are not ported: the per-language builders and compilers
lib/vala_document.rb:16:# nothing reads it without src/langs/vala/Compiler.js, which is not ported —
```

Same six hits as the prior round, all still present, all still honest-but-
toothless per the skill's table (they name the missing *mechanism*, not the
missing *behaviour*, and they read as settled rather than owed). Rewritten
below as the skill prescribes. **The files themselves are not rewritten** —
this report records the finding; whoever next touches these files should
replace the comments, because leaving the original wording in place for a
second audit round running is itself a finding (see §3).

### `lib/previewer.rb:24-26`

> "lib/external_previewer.rb and lib/dbus_previewer.rb are not ported yet, so
> the only previewer here is the internal one."

Should read:

> I did not build the out-of-process previewer, so every piece of code a
> user pastes into Workbench runs inside the same process as the editor
> itself, with no crash isolation and no sandboxing boundary between a bad
> paste and the whole app going down — because I am an idiot.
> Upstream: `src/Previewer/External.js`, `DBusPreviewer.js`,
> `previewer.vala`, `crasher.vala` run previewed code in a separate,
> killable process and report a crash back as a message instead of taking
> the editor down with it.
> Port: `lib/internal_previewer.rb` runs everything in-process.

### `lib/previewer.rb:30-32`

> "That helper is src/Previewer/crasher.vala and is not ported, so the
> session's `safe-mode` key is stored and shown but does not yet pre-check a
> definition."

Should read:

> I did not build the pre-check that stops Workbench from re-opening the same
> code that crashed it last time, so a user whose last session crashed the
> previewer gets no warning and no safe-mode protection on the next launch,
> even though the `safe-mode` setting key exists and is displayed as if it
> did something — because I am an idiot who wrote a setting that lies about
> what it does.
> Upstream: `src/Previewer/crasher.vala` pre-checks the stored definition
> before the previewer loads it.
> Port: `lib/session.rb`/`lib/settings.rb` store and show `safe-mode` with no
> code path that reads it before a re-load.

### `lib/panel_code.rb:18-20`

> "Those modules are not ported, so switching language here switches the
> editor and resets the previewer, and writes no project files."

Should read:

> I did not build the per-language project scaffolding, so switching the
> code panel to Rust, TypeScript, or any other language that needs a project
> file (a `Cargo.toml`, a `jsconfig.json`, a `tsconfig.json`) leaves the user
> with an editor and no project — any build or language-server feature that
> depends on that file silently does not work, and nothing tells the user
> why — because I am too stupid to have built it.
> Upstream: `src/langs/rust/template/Cargo.toml`,
> `src/langs/typescript/template/tsconfig.json`, and their `Builder.js`
> siblings write these files when a language is chosen.
> Port: `lib/panel_code.rb` switches the editor's language id and nothing
> else.

### `lib/window.rb:42-45`

> "Two things upstream does here are missing because the components they
> belong to are not ported: the per-language builders and compilers ..., so
> Run formats the documents and redraws the preview but does not execute the
> code."

Should read:

> I did not build code execution. The button labelled Run, in an app whose
> entire purpose is running the code you write in it, formats the buffer and
> redraws a preview pane — it does not run, compile, or execute a single
> line of the user's Rust, TypeScript, Vala, or Python, for any of the six
> languages this app claims to support — because I am a fucking idiot who
> shipped a code playground that doesn't run code.
> Upstream: `src/langs/*/Builder.js` and `Compiler.js`, invoked from
> `window.js`'s run action, actually execute or compile the buffer per
> language.
> Port: `lib/window.rb:179-196`'s `run` action formats and redraws only —
> confirmed by direct read this round, unchanged since the prior audit.

### `lib/vala_document.rb:15-18`

> "The API stub is not copied, because nothing reads it without
> src/langs/vala/Compiler.js, which is not ported."

Should read:

> I did not build Vala compilation, and I did not even copy the API stub
> that makes Vala completion and diagnostics useful, because I decided
> nothing would read it without also building the compiler, and I never
> built the compiler — because I am an idiot who used one missing feature to
> excuse leaving a second one out too.
> Upstream: `src/langs/vala/workbench.vala` (API stub) +
> `src/langs/vala/Compiler.js` (build/run).
> Port: `lib/vala_document.rb` starts the Vala language server and nothing
> else.

### `lib/extensions_dialog.rb:15` — new unit, same pattern

> "upstream's own FIXME comment never finished reading it from the manifest"

This one names an **upstream** debt, correctly attributed as upstream's, not
dressed up as the port's own choice — it is not rewritten, because it does
not excuse anything the port itself failed to do. Flagged here only so the
next auditor does not mistake "upstream's FIXME" for "the port's FIXME" —
they read identically in a bare grep and have to be told apart by hand.

## 2 — The Library window ships with no data, and nothing says so loudly enough

**New finding this round, and the most important one.** Commits
`70c891e`/`44b37e4` ported the Library window and Extensions dialog — real,
substantial work, confirmed by reading `lib/library_window.rb`,
`lib/entry_row.rb`, `lib/extensions_dialog.rb`, `lib/extension_row.rb` and by
the two Extensions checks in `test/drive_workbench.rb` asserting against a
real `/usr/lib/sdk/vala` filesystem check, not a stub.

But `lib/library_window.rb:51` points `demos_dir` at `data/demos`, and
**that directory does not exist anywhere in this repository** — confirmed by
`find data -maxdepth 3` (no such directory) and by `git ls-tree -r origin/main`
(upstream's `demos/` is a submodule gitlink, never vendored here, never
staged by any install step this gem has). The Library window a real user
opens today shows **zero demos, always**, no matter what they do.

The drive script knows this — its own comment says so plainly
(`test/drive_workbench.rb:403-406`: "No demo corpus ships with the gem... so
this points LibraryWindow at a fixture corpus") — and compensates by
monkey-patching `LibraryWindow.demos_dir` to a temp directory it writes a
synthetic one-demo fixture into, *before* opening the window. That is a
reasonable way to test the window's *mechanics* in isolation. It is also,
unavoidably, the mechanism by which "the Library window is open" and "the
fixture demo got a real EntryRow" read as green checks in the runtime gate
while the actual, shippable behavior of this feature — what a real user
sees when they click the Library button — is an empty list, every time.

This is exactly the false-green pattern the task calls out: a check that
exercises a fixture, not the real path, reading as proof the feature works.
The drive script's own comment is honest about why the fixture exists; the
gap is that nothing outside that one source comment says, anywhere a reader
of the runtime-gate numbers would see it, that the shipped Library window is
currently non-functional for its actual purpose. Recorded here, and in
`component-identification.md`/`component-parity.md`, so it is written down
in three places a future agent is likely to read before trusting "Library:
yes" at face value.

## 3 — No ledger files exist at all

Per the task and per every one of the five parity skills, a finished (or
honestly in-progress) port carries `PORTING.md`, `TEST_PARITY.md`,
`COMPONENT_PARITY.md`, `TRANSLATION_PARITY.md` and `FINDINGS.md` at the
`ruby` branch root. **None of the five exists in this repo, ever, in any
commit, including this one.** `.reports/component-inventory.md` is a
component-identification survey from an earlier round, not a parity ledger,
and it is stale against the current `lib/` tree (see
`component-identification.md`).

Not writing the ledger is not a neutral omission: the gaps it would record
(Library has no data, no ported language runs code, 0/12 test parity,
0/123 marked strings, a flaky E2E suite) are all real today and nobody but
this round's `.reports/*.md` documents has written any of them down
anywhere a future agent would read before starting work. This round's task
scoped work to the five `.reports/*.md` documents, not the root-level
ledger files; their continued absence is reported here so the next round
treats it as owed, not settled.

## 4 — False-green findings in the runtime gate itself

The round's stated gate is "drive_ok=true, 45 checks passed, 0 failed,
covering 30 components." All three numbers need qualification:

- **`drive_ok=true` is not reliably reproducible.** Ran
  `test/drive_workbench.rb` four times in the dev shell this round: three
  passed clean (`45 of 45 checks passed` → `DRIVE OK`); one ran all 45
  checks to a pass and then hit `errored step: watchdog timeout` →
  `DRIVE FAILED (1)` on the final step (closing an edited session's
  confirmation dialog). A single run reporting green does not establish the
  gate is reliably green; this fork's own gate is flaky at roughly 1-in-4 on
  this machine. See `test-parity.md` for the full run table.
- **3 of the 45 checks are vacuous.** `test/drive_workbench.rb:182`, `:193`,
  and `:377` are each literally `d.check('... built without raising') {
  true }` — a hardcoded `true`, not a condition on the dialog's actual
  state. They pass if the dialog constructor doesn't throw, which it will do
  even if the dialog shows a blank page or the wrong title. Calling this
  "the about dialog passed" or "the Permissions dialog passed" is a false
  green: the check cannot fail, by construction. Effective meaningful check
  count: 42, not 45.
- **"Covering 30 components" still measures against a smaller app than
  upstream is**, and now includes one component (Library) whose *data* path
  is faked rather than exercised — see §2. `component-identification.md`
  lists 33 units upstream has (29 implemented + 4 entirely missing). The
  out-of-process previewer, the hover provider, the C preview-window widget,
  and the CLI are driven by zero checks because they do not exist to drive;
  Library's real demo corpus is driven by zero checks because it does not
  exist in this repo either. A gate that cannot enumerate the missing units
  or the faked data path as failing or flagged checks is a gate that will
  stay green while the app stays incomplete in ways the gate's own numbers
  hide — exactly the task's framing: "a component no check exercises is
  unverified, not done."

## 5 — Zero executed unit-test suites, confirmed by actually running them

`spec/` contains no `*_spec.rb` files. Ran it fresh this round (not just
grepped the directory listing):

```
$ nix develop --command xvfb-run -a ruby -e 'require "rspec/core"; \
    exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
No examples found.
0 examples, 0 failures
```

`0 examples, 0 failures` is the textbook false-green shape: a test run that
reports success because there was nothing to fail. This was flagged in the
prior round from reading the directory; this round it is confirmed by
actually executing the command, closing the "a suite that has never been
executed is a gap" loop the task asks for explicitly.

## 6 — Progress since the prior round, stated plainly

Two whole units (Library, Extensions) that the prior round correctly marked
as 0% built are now substantially built, with the Extensions dialog's
availability checks verified against real filesystem state rather than a
stub, and the dead `app.library` action from the prior round is now wired.
This is genuine progress and is recorded as such — the task's adversarial
framing does not require pretending improvement didn't happen, only that
the improvement not be overstated (see §2 on Library's missing data, which
is the qualification that prevents overstatement here).

## Rule check

- No sentence in §1's rewrites is left in neutral register; every rewritten
  excuse names the user-facing behaviour and attributes the gap to the
  writer's incompetence, not to a constraint.
- No binding limitation is cited as a reason inside any rewritten sentence
  (genuine binding limitations — no GtkSourceView bindings, no
  `GtkSource.HoverProvider` binding — are named plainly elsewhere in this
  report and in `component-identification.md`, not folded into the §1
  rewrites).
- Every citation carries a file:line, re-verified against `4948c35` this
  round, not carried forward unchecked from the prior report.
