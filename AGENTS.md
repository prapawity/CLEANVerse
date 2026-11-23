# CLEANVerse contributor instructions

Read `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SAFETY.md`, and `docs/ROADMAP.md` before implementing a feature. Consult `docs/RESEARCH.md` for sources and verify platform policies before release. These describe the intended product; the Python prototype and the Flutter read-only desktop scan are experimental implementations.

## Design, UI/UX, and frontend review

For every change, assess whether it affects the user experience, interface, or product design. Apply the `design`, `ui-ux-pro-max`, and `frontend-design` skills when available, following the workflow in `docs/DESIGN_REVIEW.md`. For non-visual changes, check user-facing consequences and document why a visual review is not applicable. If a named skill is unavailable, use the documented checklist and report the limitation; do not claim the skill was run. User instructions and safety requirements take precedence.

Read `docs/PRODUCT_FLOW.md` for the navigation and review flow, and `docs/VISUAL_DIRECTION.md` for the current GITVerse-inspired identity and CleanMyMac interaction research before visual changes.

Read `docs/RELEASING.md` before changing branches, versions, CI or release workflows.

Read `docs/DEVELOPER_REQUIREMENTS.md` and `docs/DEVELOPER_STORAGE.md` before changing developer storage discovery or cleanup.

- Scan read-only. Never auto-select personal content or silently fall back to permanent deletion. Require explicit confirmation before any future removal.
- Platform and distribution capabilities differ. Disable unsupported operations and explain limitations.
- Treat paths, names, hashes, and scan results as sensitive. Keep them local by default. No telemetry or uploads without a documented, explicit opt-in.
- Separate UI from platform access. Handle partial results, cancellation, denied access, changed files, symlinks, and cloud-synced data.
- Test risky behavior with temporary fixtures. Never test deletion on personal files. Document untested platforms and unresolved risks.
- Do not claim unverified features, performance, security, or store approval. Update docs and tests when behavior changes.
- Do not use `[preview-only]` to skip format, analysis and tests for code changes; it is only for rebuilding an already-tested commit.
- Do not add broad privileges, elevation, automated cleaning, or remote services without a documented product and design decision.

