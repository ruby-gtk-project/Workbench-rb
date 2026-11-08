# Test parity ledger — Workbench-rb

Root-level summary; see `.reports/test-parity.md` for the full per-round
analysis.

## RSpec unit suite

`spec/xml_spec.rb` ports upstream's `test/xml.test.js` — the "format" and
"invalid documents" tests (10 of the 11 owed assertions; the 11th, an
unquoted bare attribute on a self-closing tag, is left `pending` with a
comment explaining the port's tokenizer accepts what upstream's `ltx`
rejects — a real, narrow parity gap, not a test adjusted to pass). Upstream's
third test, "library examples", is itself `test.skip`ped upstream and stays
unported for the same reason.

Still owed: `isDiagnosticInRange` and `getObjectClass`
(lsp.rb/lsp_sourceview.rb), `isDeviceInputOverrideAvailable`
(flatpak.rb — this port's `Flatpak.device_input_override_available?`),
and whatever pure-function coverage `previewer.rb` owes beyond what the
drive script already exercises end-to-end.

## Runtime drive gate (`test/drive_workbench.rb`)

55 checks, all meaningful now (the three `{ true }` vacuous checks were
replaced this round — see COMPONENT_PARITY.md). Run 3 times this round under
`nix develop --command xvfb-run -a ruby test/drive_workbench.rb`: 3/3 clean
`DRIVE OK` with 55/55 checks passing. The prior round's flaky watchdog
timeout on the "close an edited session" (dialog-blocking-close) step did
not reproduce in these 3 runs; it has not been separately root-caused and
should not yet be treated as fixed — only as not reproduced this round.
