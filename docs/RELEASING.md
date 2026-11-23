# Branching, CI and releases

Status: 2026-11-23. The workflows referenced here live in `.github/workflows/`.

## Branch model: GitHub Flow with release tags

```
feature/x ─┐   PR + CI    ┌─ tag v1.3.0-beta.1 ─▶ pre-release (testers only)
fix/y ─────┼────────────▶ main ──────────────────▶ tag v1.3.0 ─▶ draft release ─▶ publish ─▶ auto-update
release/v1.3.0 (version bump PR) ─┘
                                   └─ release/1.3.x (only if a hotfix is needed while main has moved on)
```

- `main` is always releasable. Nothing is pushed to it directly; every change arrives through a pull request with green CI.
- Work branches: `feature/<topic>`, `fix/<topic>`, `docs/<topic>`, `chore/<topic>`. Keep them short-lived and rebase on `main` before merging.
- Merge with **squash merge**, so `main` gets one commit per PR and the PR title becomes the commit message. Use the imperative mood: "Add macOS uninstaller".
- There is no `develop` branch. Pre-releases come from tags on `main`, not from a long-lived branch.
- **Hotfixes:** when `main` is still releasable, fix on `fix/<topic>`, merge, and tag a patch version. When `main` already contains unreleased work that isn't ready, create `release/<major>.<minor>.x` from the last release tag, cherry-pick the fix, and tag from that branch. Afterwards, make sure the fix is also on `main`.

### `[preview-only]`

A commit message containing `[preview-only]` builds a Windows preview without running the tests. It applies **only to pushes on work branches**, and only to rebuild code that already passed the checks; never use it to skip checks for new code changes. Pull requests and `main` always run the full checks.

## Versioning

[Semantic Versioning](https://semver.org) in `apps/cleanverse/pubspec.yaml` as `version: X.Y.Z[-pre]+build`.

| Change | Bump |
| --- | --- |
| Behavior that removes data differently, a new removal type, or a settings format change that can't be read back | minor while 0.x/1.x; major once the formats are stable |
| New feature or catalog entries | minor |
| Bug fix or copy change | patch |
| Test build for testers | `-beta.N` (for example `1.3.0-beta.1`) |

- `+build` must increase with every release, including betas. Store and package managers compare it.
- The tag is `v` plus the version without `+build`, for example `v1.3.0` or `v1.3.0-beta.1`. The release workflow refuses a tag that doesn't match `pubspec.yaml`.

## Releasing

1. Run **Actions → Prepare release** with the new version, for example `1.3.0`. It opens a `release/v1.3.0` PR that bumps `pubspec.yaml`, increments the build number and adds a changelog stub. Edit the PR if needed and merge it after CI passes.
2. Tag the merge commit on `main`:
   ```sh
   git switch main && git pull
   git tag -a v1.3.0 -m "CLEANVerse 1.3.0"
   git push origin v1.3.0
   ```
   You must push the tag yourself. Tags pushed by the workflow token don't start other workflows.
3. The **Release** workflow then:
   1. checks the tag against `pubspec.yaml`;
   2. tests;
   3. builds Windows, macOS and Linux;
   4. signs and notarizes macOS when the signing secrets are set;
   5. signs `latest.json`;
   6. creates a **draft** release. A tag with `-` (for example `-beta.1`) becomes a **pre-release**.
4. Review the draft: download each package, check the notes, and run the manual checks in the PR template on at least one OS. Then publish.
5. Installed apps see only **published, non-pre-release** releases. They read `releases/latest/download/latest.json`, which GitHub serves only from the latest full release. Drafts and pre-releases never reach users through auto-update.

**Rollback:** never delete or retag a published version. Publish a new patch release, for example `1.3.1`, that reverts the change. Apps update forward only.

## CI (`.github/workflows/ci.yml`)

| Job | Runs on | When | Purpose |
| --- | --- | --- | --- |
| `checks` | ubuntu | every PR and every push to `main` (work-branch pushes don't run it twice; open a PR) | format, analyze, test |
| `build` | windows, macos, ubuntu | after `checks` | proves each desktop target compiles; PR builds are uploaded as artifacts for 7 days |
| `preview` | windows | work-branch push with `[preview-only]` | untested Windows build for quick manual checks |

Newer runs cancel older runs on the same branch. Workflow permissions are read-only unless a job needs more.

## Repository settings (set once in GitHub)

- **Branch protection for `main`:**
  - require a pull request;
  - require the status checks `checks`, `build (windows)`, `build (macos)` and `build (linux)`;
  - require branches to be up to date;
  - block force pushes and deletion;
  - allow only squash merging.
- **Tag protection:** a ruleset on `v*` so only maintainers can create release tags.
- **Variables:** `UPDATE_PUBLIC_KEY`, the Ed25519 public key compiled into release builds.
- **Secrets:**

| Secret | Used for |
| --- | --- |
| `UPDATE_SIGNING_KEY` | Ed25519 private key that signs `latest.json` (`dart run tool/release/sign_manifest.dart keygen`) |
| `MACOS_CERTIFICATE` | base64 of the Developer ID Application `.p12` |
| `MACOS_CERTIFICATE_PASSWORD` | password of that `.p12` |
| `MACOS_SIGNING_IDENTITY` | for example `Developer ID Application: Name (TEAMID)` |
| `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` | `notarytool` credentials (an app-specific password) |

Without the macOS secrets, the release still builds, but the DMG is **unsigned** and the draft notes say so. Since the App Sandbox is off and distribution is direct (see `SAFETY.md`), only publish a full release after it is signed and notarized. Otherwise Gatekeeper blocks the app.

Windows code signing and Linux packaging (AppImage, Flatpak), winget and Homebrew cask are not set up yet; see `ROADMAP.md`.
