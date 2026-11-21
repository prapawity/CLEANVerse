# CLEANVerse contributor instructions

Read `docs/PRODUCT.md`, `docs/ARCHITECTURE.md`, `docs/SAFETY.md`, and `docs/ROADMAP.md` before implementing a feature. Consult `docs/RESEARCH.md` for sources and verify platform policies before release. These describe the intended product; the Python desktop prototype is the only current implementation.

- Scan read-only. Never auto-select personal content or silently fall back to permanent deletion. Require explicit confirmation before any future removal.
- Platform and distribution capabilities differ. Disable unsupported operations and explain limitations.
- Treat paths, names, hashes, and scan results as sensitive. Keep them local by default. No telemetry or uploads without a documented, explicit opt-in.
- Separate UI from platform access. Handle partial results, cancellation, denied access, changed files, symlinks, and cloud-synced data.
- Test risky behavior with temporary fixtures. Never test deletion on personal files. Document untested platforms and unresolved risks.
- Do not claim unverified features, performance, security, or store approval. Update docs and tests when behavior changes.
- Do not add broad privileges, elevation, automated cleaning, or remote services without a documented product and design decision.

