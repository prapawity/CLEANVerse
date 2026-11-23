# UX redesign: simple first, detail on demand

Status: 2026-11-23, agreed direction for the redesign. Owner feedback: too many menus and buttons, hard to use, too much folder picking, and long pages that are hard to scan.

## Principles

1. **One obvious start.** Opening the app shows one primary action that works without choosing anything. The default scope is the user's home folder. "Choose another folder" is a secondary link.
2. **Answers before tools.** Results come back as a few plain-language findings with sizes, each with one action. Tools and detail sit one level deeper.
3. **Progressive disclosure.** Simple view first. Advanced views (folder map, duplicates, developer tooling, Docker, package commands) are reachable but never in the way. A professional can always get to paths, sizes, risk and the exact command.
4. **Few destinations.** At most five navigation items, plus Settings.
5. **Every long list is lazy and bounded.** No page renders hundreds of rows at once. Lists show the top items, with sorting/filtering and "Show more", and scroll inside the page. Actions for a selection live in a bar that stays visible.
6. **Safety rules are unchanged** (`SAFETY.md`): nothing is pre-selected. Every removal shows the confirmation listing each item. One-click shortcuts such as "Clean safe junk…" only open that confirmation, with exactly the items they name.

## Navigation

```
Sidebar (≥ 900 px)                 Compact (< 900 px): same items as a bottom-free top row
┌────────────────────┐
│ CLEANVerse          │
│ ● Home              │  one-button scan + findings
│   Clean up          │  junk and caches, grouped, risk labels
│   Storage           │  Biggest files | Folders | Duplicates (tabs)
│   Apps        (mac) │  uninstaller; hidden where unsupported
│ ─ Pro tools ─────── │
│   Developer         │  projects, global caches, Docker, package commands
│                     │
│ ⚙ Settings          │  includes "Try with sample data" (old Example scan)
└────────────────────┘
```

Removed from top-level navigation: Smart Scan (now Home), Space Lens, Large & old files and Duplicates (now tabs in Storage), Example scan (moved to Settings).

## Home

```
┌──────────────────────────────────────────────────────────────┐
│  Your Mac at a glance                         [Scan now]      │  before the first scan: one button,
│  Scans your home folder and known cache       Choose folder…  │  plus a quiet link for another folder
│  locations. Nothing is removed without asking.                │
├──────────────────────────────────────────────────────────────┤
│  Junk you can clean          3.2 GB   [Clean safe junk…]      │  findings after a scan, biggest first.
│  Biggest files              18.4 GB   [Review]                │  Each row = one sentence + size + one
│  Apps                       45 apps   [Uninstall apps]        │  action that opens the right page.
│  Developer storage          12.1 GB   [Review]                │  (only if something was found)
│  What grew since Nov 20     +2.3 GB   [See folders]           │  (only with history on)
└──────────────────────────────────────────────────────────────┘
```

- "Scan now" runs the home-folder scan (largest files, folder sizes, developer folders) and the junk check together, with one progress display and Cancel. Duplicates are not part of it (slow); the Storage → Duplicates tab offers "Find duplicates" on the same scope.
- The scan options checkboxes disappear from the first screen. The rare options move to Storage/Developer, where they're needed.

## Scroll and density contract (all pages)

- The shell no longer wraps pages in one big scroll view. Each page fills the content area and owns its scrolling through `PageScroll` (slivers), so long lists can be lazy.
- A list longer than ~30 rows uses a lazy builder, and shows 50 at first with "Show 50 more". Groups start collapsed when there are more than 3.
- Selection pages (Clean up, Apps, Developer) keep their action bar pinned at the bottom, outside the scrolling area.
- Paths are single-line with middle ellipsis and a tooltip or copy action, not wrapped multi-line text.
- Check every page at 1280×800, at 700 px wide and at 200% text, and with large data sets (500+ files, 100+ apps, 50+ junk locations).

## Search and sort (all list pages)

Every list uses the shared `ListToolbar` (`app/list_toolbar.dart`):

- **Search box:** waits briefly after typing, then filters as you type. It has a clear button and ignores case. Every word must match the name, the path or a detail.
- **Sort menu:** the options depend on the page:

| Page | Search looks in | Sort options |
| --- | --- | --- |
| Biggest files | name, path | largest, smallest, oldest, newest, name |
| Folders | folder name, path | largest, name, most files |
| Duplicates | any copy's name or path (whole groups kept) | most space used, most copies, largest file, name |
| Clean up | label, path, note (matching groups open) | largest, name, safest, riskiest |
| Developer | tool, project, path, note (matching sections open) | largest, least recently changed, by type, path |
| Apps | name, bundle ID | name, largest (frozen while sizes are measured) |

- **While searching:** "Showing N of M" is shown, and "No matches" comes with a Clear search button.
- **Narrow windows or large text:** the controls stack.

## Visual

Keep the GITVerse family palette and system fonts (`VISUAL_DIRECTION.md`). Spend boldness in one place: the Home finding list, with large, confident size figures. Everything else is quieter: fewer outlined panels, fewer chips, one primary button per screen. Remove decorative icons that don't carry meaning.

## Work split (2026-11-23)

| Track | Owns | Delivers |
| --- | --- | --- |
| A Shell & Home | `app/`, `features/scan/smart_scan_page.dart` → Home, `features/example/`, `features/settings/`, scan view model defaults | new navigation, Home flow, default home scope, combined scan |
| B Storage | `features/scan/` review pages (large files, space lens, duplicates, what grew, needs scan) | Storage page with tabs, lazy lists, filters |
| C Clean, Apps, Developer | `features/cleanup/`, `features/uninstall/`, `features/developer/` | simplified pages, lazy lists, pinned action bars, Pro-tools Developer |

Shared foundation (done before the split): `Section` enum, navigation items, and `PageScroll` in `app/ui.dart`.
