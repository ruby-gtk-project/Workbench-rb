# Translation parity — Workbench

| | |
|---|---|
| Upstream | `main` @ `1c5627b` |
| Port | `ruby` @ `146e3ae` |
| Domain | none found — upstream ships no `po/` directory, no `POTFILES.in`, no `.pot`, no gettext build step anywhere in `meson.build` |
| Upstream messages marked with `_()` | 123 distinct, 144 call sites (21 reused) |
| Upstream languages shipped | **0** |
| Ported | 0 |
| Gaps | 123 (relative to the marked-string set; see below) |
| Extra | 0 |

## Upstream has no translation catalogue

Confirmed by direct inspection of an `origin/main` export: no `po/` anywhere
in the tree, no `POTFILES.in`/`POTFILES`, no `.pot`, no `i18n.gettext(...)`
or `gettext` dependency in `meson.build` or `data/meson.build`. This is the
"when upstream has no translations" case the skill names explicitly: parity
on the *catalogue* axis is **0/0 and met trivially** — there is nothing
upstream ships that the port can fail to carry over, because upstream has
never shipped a translation of this app into any language.

## But upstream does mark strings — and the port doesn't

123 distinct strings across the JS source and the `.blp` templates are
already wrapped in `_()` (`import { gettext as _ } from "gettext"` in
`src/Library/Library.js`, for example), presumably in preparation for
eventual l10n.gnome.org registration even though no catalogue exists yet.
Grepping the port:

```
grep -rn "_(\"" lib/*.rb   → 0 matches
grep -rn "gettext"         → 0 matches anywhere in lib/, Gemfile, gemspec
```

The port has **zero** translation markers and **no gettext dependency at
all**. Every user-visible string in the port — every button label, dialog
title, tooltip, placeholder — is a bare Ruby literal. Concretely:

- `ngettext`/plural forms: upstream has none in this app (0 plural call
  sites found), so there is no plural-form regression to check — a genuine
  0/0, not a gap.
- `msgctxt`: none found upstream either.

Because upstream ships no catalogue, marking these 123 strings in the port
would not "restore" any existing translation — there is none to restore.
It is listed as a gap anyway, for the reason the skill gives for every
unmarked string regardless of whether a catalogue exists yet: **any of the
123 strings could be registered for translation the day upstream adds a
`po/` directory, and today the port's rewritten/unmarked versions would not
match upstream's marked bytes even if that happened tomorrow.** Concretely,
of the 123 upstream strings, the ones that live in units the port actually
built (About dialog, shortcuts window, CodeFind, CodeView, window, Permissions)
were not checked byte-for-byte against the port's literals this round — that
check (diffing each upstream `_("...")` argument against the port's
corresponding Ruby string) was not completed under this round's time budget
and is an open item, not a pass. The ones that live in Library, Extensions,
and the C preview-window — the three units `component-identification.md`
reports as entirely unported — are gaps by construction: 24+ of the 123
strings (every `_()` call inside `Library/Library.js`, `Library/EntryRow.js`
plus their `.blp`s, both `Extensions/*.blp` files, and
`libworkbench/workbench-preview-window.blp`) cannot exist in the port because
the widgets that would show them don't exist.

## What was not checked this round

- No byte-for-byte diff of the ~90-odd marked strings in units the port *did*
  build (About, shortcuts, CodeFind/CodeView, window, Permissions) against
  the port's literal text. This is the single largest open item in this
  report: it is entirely possible some of those are already byte-identical
  by coincidence (the port clearly tries to preserve upstream wording — see
  the "Upstream's ... ." comments throughout `lib/*.rb`), but "ported and
  byte-identical" is a claim that has to be verified per string, not assumed
  from a comment saying so.
- No `scripts/catalogue.rb`/`msgid-census.sh` run (not present in this fork's
  `.claude/skills/translation-parity/scripts/`; only the markdown skill body
  was available this round — see note below).

## A scripting gap in this skill's own install

`.claude/skills/translation-parity/` in this fork contains only the skill
body; `scripts/msgid-census.sh` and `scripts/catalogue.rb`, which the skill
text repeatedly instructs the reader to run, are not present on disk here.
This is worth recording because it means the structured `--compare` YAML
workflow the skill describes could not be executed mechanically this round;
the numbers above come from direct `grep`/manual reading instead, which is a
weaker, less reproducible method than the skill prescribes.

## Verdict

- Catalogue/language parity: **0/0, met trivially** — upstream ships nothing
  to inherit.
- Marked-string parity: **0/123** — the port has no gettext infrastructure
  and no translation markers anywhere, so even though there is no catalogue
  to lose today, the port is not positioned to gain one without a rewrite,
  and an unknown (unverified) number of its strings have already drifted
  from upstream's wording.
- This is reported as a real gap, not waved through as "N/A because upstream
  has none" — the 0/0 catalogue finding and the 0/123 marking finding are
  both true at once, and only the first one is free.
