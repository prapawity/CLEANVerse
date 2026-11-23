## What and why

<!-- One or two sentences. Link issues. -->

## Safety checklist (AGENTS.md / docs/SAFETY.md)

- [ ] Scans stay read-only; nothing is pre-selected or removed without explicit confirmation
- [ ] No silent fallback to permanent deletion
- [ ] Paths, names and scan results stay local (no new telemetry or uploads)
- [ ] Unsupported platforms or operations are disabled with an explanation
- [ ] Risky behavior is tested with temporary fixtures, never personal files
- [ ] Docs updated (SAFETY, ROADMAP, ARCHITECTURE as relevant)
- [ ] UI change: design review done per docs/DESIGN_REVIEW.md, or explain why not applicable

## Tested

- [ ] `flutter analyze` and `flutter test`
- [ ] Manually on: <!-- OS and version, or "not run" -->

## Not verified / risks

<!-- Platforms, edge cases or behavior that is untested. -->
