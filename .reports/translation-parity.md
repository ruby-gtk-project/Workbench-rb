# Translation parity — Workbench

| | |
|---|---|
| Upstream | `main` @ `1c5627b` |
| Port | `ruby` @ `4948c35` |
| Domain | none found — upstream ships no `po/` directory, no `POTFILES.in`, no `.pot`, no gettext build step anywhere in `meson.build` |
| Upstream messages marked with `_()` | 123 distinct, 144 call sites (21 reused) |
| Upstream languages shipped | **0** |
| Ported | 0 |
| Gaps | 123 (relative to the marked-string set; see below) |
| Extra | 0 |

## Upstream has no translation catalogue

Confirmed by direct inspection of an `origin/main` export: no `po/` anywhere
in the tree, no `POTFILES.in`/`POTFILES`, no `.pot`, no `i18n.gettext(...)`
or `gettext` dependency in `meson.build` or `data/meson.build`. Parity on the
*catalogue* axis is **0/0 and met trivially** — upstream has never shipped a
translation of this app into any language.

## But upstream does mark strings — and the port still doesn't

123 distinct strings across the JS source and the `.blp` templates are
already wrapped in `_()` (`import { gettext as _ } from "gettext"` in
`src/Library/Library.js`, for example), presumably in preparation for
eventual l10n.gnome.org registration even though no catalogue exists yet.
Re-ran the grep this round against the current `lib/` tree, including the
two units landed since the prior round (Library, Extensions):

```
$ grep -rn 'gettext\|_("' lib/*.rb Gemfile *.gemspec
(0 matches)
$ grep -n 'gettext\|_("' lib/library_window.rb lib/extensions_dialog.rb \
    lib/entry_row.rb lib/extension_row.rb
(0 matches)
```

The port has **zero** translation markers and **no gettext dependency at
all**, in any file including the two new ones. Every user-visible string in
the port — every button label, dialog title, tooltip, placeholder, every
row in the newly-ported Library and Extensions dialogs — is a bare Ruby
literal.

- `ngettext`/plural forms: upstream has none in this app (0 plural call
  sites found), so there is no plural-form regression to check — genuine
  0/0, not a gap.
- `msgctxt`: none found upstream either.

Because upstream ships no catalogue, marking these 123 strings in the port
would not "restore" any existing translation — there is none to restore. It
is listed as a gap anyway, for the reason the skill gives regardless of
whether a catalogue exists yet: any of the 123 strings could be registered
for translation the day upstream adds a `po/` directory, and today the
port's rewritten/unmarked versions would not match upstream's marked bytes
even if that happened tomorrow.

Of the 123 upstream strings:

- The ones that live in units the port has now built, including Library and
  Extensions as of this round, were **not** diffed byte-for-byte against the
  port's literals — that check (diffing each upstream `_("...")` argument
  against the port's corresponding Ruby string, one by one) was not
  completed under this round's time budget either, and remains an open
  item, not a pass, now covering more surface area than before since Library
  and Extensions add roughly two dozen more strings to check.
- The ones that live in the three units still entirely unported — the
  out-of-process previewer, the hover provider, and the C preview-window
  widget — remain gaps by construction: every `_()` call inside those files
  (plus `libworkbench/workbench-preview-window.blp`'s strings) cannot exist
  in the port because the widgets that would show them don't exist.

## What was not checked this round

- No byte-for-byte diff of the marked strings in units the port has built
  (About, Shortcuts, CodeFind/CodeView, Window, Permissions, **and now
  Library and Extensions**) against the port's literal text. This remains
  the single largest open item in this report.
- No `scripts/catalogue.rb`/`msgid-census.sh` run — see below, unchanged
  from the prior round.

## A scripting gap in this skill's own install

`.claude/skills/translation-parity/` in this fork still contains only the
skill body; `scripts/msgid-census.sh` and `scripts/catalogue.rb`, which the
skill text repeatedly instructs the reader to run, are not present on disk
here (re-confirmed this round). The numbers above come from direct
`grep`/manual reading, not the skill's own prescribed tooling.

## Verdict

- Catalogue/language parity: **0/0, met trivially** — upstream ships nothing
  to inherit.
- Marked-string parity: **0/123** — unchanged from the prior round, and the
  two newly-ported units (Library, Extensions) add more unmarked strings on
  top of the existing gap rather than narrowing it. The port is not
  positioned to gain a translation catalogue without a rewrite, and an
  unknown (still unverified) number of its strings have drifted from
  upstream's wording.
