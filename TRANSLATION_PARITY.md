# Translation parity ledger — Workbench-rb

Root-level summary; see `.reports/translation-parity.md` for the full
per-round analysis.

Status unchanged this round: zero gettext/translation markers anywhere in
`lib/` (0 of upstream's 123 marked strings). No `_()` infrastructure exists,
and no byte-for-byte diff against upstream's marked-string wording has been
done for any ported unit, including Library and Extensions.

Remaining for a future round: add gettext infrastructure (a `.pot` and the
`_()` marker convention) and mark every user-facing string this port
currently writes as a plain literal, then diff against upstream's marked
strings for wording fidelity.
