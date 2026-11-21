# Device Care — desktop foundation

The Flutter application is in [apps/cleanverse](apps/cleanverse/README.md). It includes an experimental, read-only desktop folder scan; file removal and mobile scanning are not implemented.

> CLEANVerse is in the research and architecture phase. See [project documentation](docs/PRODUCT.md), [architecture](docs/ARCHITECTURE.md), [safety requirements](docs/SAFETY.md), [research](docs/RESEARCH.md), and [roadmap](docs/ROADMAP.md). The Python prototype below is experimental and has not passed the planned removal safety gate.

A local, review-first desktop storage scanner for Windows, macOS, and Linux. This is an early prototype, not a complete implementation of the five-platform product plan.

## Run

Install Python 3.10 or newer with Tkinter, then in this folder:

```
python -m pip install -r requirements.txt
python app.py
```

On Linux, Tkinter may need a separate system package, such as `python3-tk`. A desktop session and a working system Trash are required. Run tests with `python -m unittest -v`.

Choose a folder you own, optionally exclude subfolders, and scan. Results show up to 5,000 largest files or exact SHA-256 duplicate groups. Select files yourself and confirm before moving them to the system Trash. The app does not empty Trash; moving files there may not immediately free disk space. Trash availability varies across volumes and systems. Files that changed after the scan are skipped. Cloud-synced files may be removed from other devices. Review carefully and maintain backups.

Scanning is local and makes no network requests. A local history of files moved to Trash is written to `DeviceCare/history.jsonl` in the application data directory. It includes file paths and sizes; delete the file to clear history.

## Scope and limitations

There is no Android or iOS application, packaged installer, account, billing, cloud cleanup, malware scanning, app management, automated temporary-file rules, storage visualization, or integrated history viewer yet. Desktop builds have not been validated across all platforms. The app does not follow symbolic links and may report inaccessible or changing files as scan issues. SHA-256 matches are used to identify exact duplicates; hard-linked files alone are not treated as separate copies. Scan results are estimates, not a guarantee of recoverable space. The app relies on operating-system Trash behavior and cannot guarantee recovery. Avoid scanning sensitive system folders or running with elevated privileges.


