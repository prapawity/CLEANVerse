# Product flow and information architecture

Status: 2026-11-22. Describes the implemented desktop Flutter flow and the reference products it was compared against. Researched 2026-11-22; verify vendor behavior again before relying on it.

## Reference products

| Product | Pattern worth learning from | What CLEANVerse does differently |
| --- | --- | --- |
| CleanMyMac (macOS) | One primary scan ("Smart Care") produces a summary of tiles; each tile opens a category review. Sidebar modules (My Clutter, Space Lens) give direct access. Large & Old Files shows files of 50 MB or more and never auto-selects. | No automatic junk cleaning, malware or "performance" tasks. Nothing is selected or removed. |
| DaisyDisk / GrandPerspective (macOS) | Visual storage map with drill-down into folders, largest first. | Uses a proportional bar plus a labelled list (accessible, works at 200% text) rather than a sunburst. |
| WinDirStat / WizTree / TreeSize (Windows) | Directory list sorted by size, file-type statistics, very fast scanning. | Scans a chosen folder only, not whole drives; no MFT access or elevation. |
| StorageRadar and similar | Review-first cleanup with developer-cache awareness. | Developer area keeps review-only plans; Move to Trash stays disabled. |

Common expectations across these tools: a single obvious "Scan" starting point, real progress, a summary in plain sizes, drill-down from big to small, filters for size and age, and a review step before any action.

## Implemented flow

```
Smart Scan ── choose folder + options ──▶ progress (real counts, cancel keeps partial)
     │
     ▼
Scan summary (status chip, totals, skipped count)
 ├─ Space Lens ........ largest folders (Explore → rescan inside, Back) + file types
 ├─ Large & old files . 100 largest, filter 50 MiB+ / older than a year, sort by size or age
 ├─ Duplicates ........ SHA-256 groups; "Turn on and scan again" if not included
 ├─ What grew ......... opt-in history; growth since the previous scan of this folder
 └─ Developer ......... quick check + project/tool candidates → select → review dialog
Example scan ......... fixed sample data, never touches files
```

One `FolderScanViewModel` lives in `HomeScreen` and feeds every page, so a single scan populates all review areas. Navigation is a grouped sidebar (Scan / Review / Tools / Learn) at 900 px and wider, and a scrollable chip row below that. Badges show result counts after a scan.

## Rules carried into the UI

- Nothing is pre-selected; every removal control is disabled (see `SAFETY.md`).
- "Old" uses modification time and says so; it is not a last-opened date.
- Sizes are labelled as logical; no reclaimable-space or savings estimates.
- Partial or cancelled scans show a caution callout on each affected page.
- Changing scan options clears results, and the UI says so.

## Next steps

1. Verify the new layout on real Windows, macOS and Linux builds, at 200% text and with a screen reader.
2. Persist exclusions and options (explicit opt-in).
3. Add an interactive treemap for Space Lens once the list version is validated.
4. Design the recoverable Move to Trash flow (per-item outcomes, keep-one-copy guard for duplicates) before enabling it.

Sources: [CleanMyMac large & old files](https://macpaw.com/support/cleanmymac/knowledgebase/large-and-old), [CleanMyMac free up more space](https://macpaw.com/support/cleanmymac/knowledgebase/free-up-more-space), [Space Lens revamp](https://macpaw.com/news/cleanmymac-space-lens-revamp), [DaisyDisk alternatives](https://macpaw.com/reviews/daisydisk-alternatives), [Disk cleanup tools 2026](https://worldmetrics.org/best/disk-cleanup-software/), [CleanMyMac alternatives](https://storageradar.chama.pro/blog/best-cleanmymac-alternatives-for-mac-2026).
