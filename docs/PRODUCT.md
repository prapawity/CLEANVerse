# Product definition

Status: research and architecture baseline, 2026-11-21. The Python desktop app is an early prototype; Flutter and mobile apps are not implemented.

## Purpose

CLEANVerse helps everyday users understand and organize storage on personal devices. The product family targets Windows, macOS, Linux, Android, and iOS. It is local-first and does not promise identical capabilities across platforms.

## First milestone

Build a read-only Flutter vertical slice: choose permitted content, scan, show large files and exact duplicate candidates, explain scope and incomplete results, and cancel. Desktop folder scanning and mobile media/document access need separate adapters. Do not delete files in this milestone. Clearly identify unsupported operations.

## Later milestones

Add explicit review and native recovery-aware removal only after platform-specific design, testing, and review. Add temporary-file rules only with a separately reviewed allowlist. Accounts, subscriptions, cloud-provider APIs, antivirus, automatic optimization, and remote scanning are outside the first milestone.

## Experience principles

- Ask for access when a user starts a task; explain the purpose.
- Show item identity, size, reason, scan limitations, and possible synchronization.
- Distinguish potential duplicate bytes, moved-to-trash bytes, and verified free-space change. Avoid double-counting hard links and shared storage.
- Select nothing by default. Require review and protect at least one known good copy when removing duplicates.
- Avoid misleading health scores, automatic performance claims, and fake progress.

