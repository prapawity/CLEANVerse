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

## macOS sandbox decision (2026-11-23)

The owner chose direct distribution for macOS. The App Sandbox entitlement is removed from Debug and Release builds, so the app runs with the user's own file permissions (no elevation). Consequences: the Mac App Store is not a target as-is; every removal still goes through the confirmation and re-checks above; release builds need Developer ID signing, hardened runtime and notarization.

Full Disk Access is optional. CLEANVerse detects that it is missing by listing or opening protected paths (TCC database, Safari, Mail) without keeping any contents, and shows a dismissible banner that opens System Settings. Granting it never selects or removes anything. Verified: the build has no sandbox entitlement and the check reports denied from a Terminal without access. Not yet verified: the granted path in the app itself, and real cleanup on macOS.

## Scan history (2026-11-23)

Opt-in, off by default. When on, each finished (not cancelled) scan saves its root, time, total and the largest folders' paths and logical sizes to `scan_history.json` in the app's data folder; no file names, hashes or contents. At most 30 scans are kept. Turning the setting off deletes the file. Nothing is uploaded. Comparisons with skipped folders are labelled approximate.

## macOS uninstaller (2026-11-23)

Implemented in `apps/cleanverse/lib/src/features/uninstall/`.

- Lists `.app` bundles in /Applications, /Applications/Utilities and ~/Applications (links not followed). Apple apps (`com.apple.*`) and CLEANVerse are never listed.
- Leftovers are matched in the user's Library by exact bundle id, or the id followed by "." (helpers). A plain prefix never matches (`com.example.app` ≠ `com.example.application`). Name matches are allowed only in Caches, Logs and Application Support, only for specific names, and are labelled Risky and "Matched by name".
- Risk: caches, logs, saved state and web data Safe; app bundle, preferences, launch agents and scripts Caution; Application Support, Containers and Group Containers Risky (may hold documents).
- Nothing is selected automatically; "Select everything" is an explicit action. The confirmation offers no permanent option and the view model forces Trash regardless of caller. Each item still passes the removal engine's re-checks.
- A running app is refused, re-checked just before removal (`ps`); if the check fails the UI warns to quit the app.
- System-wide items in /Library are listed for information only; no administrator rights are requested.
- Launch agents are moved to the Trash but not unloaded; they stop after logout/restart.

Verified: unit tests with temporary fixtures and fake plutil/ps/Trash; read-only listing and leftover search on the developer's macOS machine. Not yet verified: real Trash moves of app bundles (including App Store apps owned by root, which may prompt for a password), protected containers on recent macOS, and vendor-folder data that is not named by bundle id.

## Audit fixes (2026-11-23)

- **Links are never moved to the Trash.** Finder (and likely the Windows Recycle Bin for junctions) acts on what a link points to, so trashing a link inside a cache folder moved its target, for example a personal folder, to the Trash. This was confirmed with temporary fixtures on macOS. Folder-content cleaning now skips links, and every Trash backend refuses a link path as a second guard. Tests: `test/removal_links_test.dart`.
- **Windows self-update only replaces a folder that holds nothing but the app** (the exe, its DLLs and `data`). If the app runs from a shared folder such as Downloads, the update is saved for the user instead of emptying that folder. Test: `test/installer_guard_test.dart`.
- macOS Trash moves are batched (one `osascript` call per 200 items) and still report each item.

Note: the macOS Trash tests move small temporary files into the developer's Trash when run locally.
