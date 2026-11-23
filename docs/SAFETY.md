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

## Removal decision (2026-11-22)

The owner approved user-confirmed removal on desktop. Implemented in `apps/cleanverse/lib/src/cleanup/`:

- Nothing is pre-selected. Every removal goes through a confirmation listing each item, its path and whether it will be deleted permanently or moved to the Recycle Bin/Trash.
- Default mode is per item: rebuildable caches (temp, browser cache folders, package-manager caches) are deleted permanently; project dependencies, user files, duplicates and possibly unique data (e.g. Xcode archives) go to the Recycle Bin/Trash. The user can override this for all items in the dialog.
- Trash uses Windows Recycle Bin (VisualBasic FileSystem via PowerShell), macOS Finder, or Linux `gio trash`/`trash-put`. If trash fails the item is reported as not cleaned; it never falls back to permanent deletion.
- Each item is re-checked just before acting: it must still exist, not be a link, stay inside its reviewed location, and not be a top-level or home folder. Links are never followed. Items in use are skipped and reported.
- Duplicates always keep at least one copy per group. Results separate space freed now from bytes moved to the bin. Trash is never emptied.
- Every Clean up item shows a risk label: Safe (rebuilt automatically), Caution (app must close, broad app caches, or re-download needed) or Risky (may hold data that cannot be rebuilt; defaults to the bin and adds a warning to the confirmation). Labels never select anything.
- Package-manager caches (Homebrew, npm, pub) are cleaned only through the tool's own command, shown verbatim in the confirmation; a Homebrew dry run is shown first. npm and pub have no dry run, so the dialog says the tool decides and it cannot be undone.
- Junk locations are limited to the user's own profile; no administrator rights. Browser cleanup touches cache folders only, not cookies, history or passwords.

Verified: unit tests with temporary fixtures, and a read-only junk check on Windows 11. Not yet verified: macOS and Linux trash, cloud-synced folders, network volumes, and real-world removal on any OS.
