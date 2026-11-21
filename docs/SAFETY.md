# Safety and privacy requirements

These are design requirements, not a claim the current prototype satisfies them. File deletion is outside the first Flutter slice.

## Scanning

- Access only explicitly selected or authorized scope. Do not follow symlinks, junctions or reparse points by default; prevent traversal outside scope and report skips.
- Handle missing, changing, locked, and unreadable items. Mark cancelled or partial scans clearly. Never elevate privileges for a scan.
- Compare duplicate sizes then stream SHA-256. Consider final byte comparison before future destructive actions. Account for hard links and shared identities where supported; file sizes are not necessarily physical space recoverable.
- Keep paths, names, media identifiers and hashes local. Avoid personal paths in logs unless the user deliberately enables a documented diagnostic mode.

## Future removal gate

- Require item selection and final confirmation showing scope, impact, sync implications, and recovery limitations. Keep at least one known good copy per duplicate group; revalidate selected and retained copies.
- Use a platform recovery mechanism only when supported and verified for that item and volume. Otherwise skip and explain. Never silently delete permanently.
- Revalidate identity and metadata immediately before action and skip on uncertainty. Document residual time-of-check/time-of-use races.
- Report individual outcomes and distinguish Trash from storage actually reclaimed. Handle cancellation and partial failures. Do not empty Trash.
- Warn that cloud-synced and shared items can affect others. Provider-specific behavior requires its own design.

## Release evidence

Use temporary fixtures. Test permissions, revoked access, symlinks, hard links, changed files, inaccessible directories, external and network volumes, cloud placeholders, interrupted operations, and low storage. Test removal on every supported OS and volume. Establish security review and a data-loss escalation path before beta removal features.

