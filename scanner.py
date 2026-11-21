"""Local, review-first storage scanner. No files are removed during scanning."""
from __future__ import annotations
import hashlib
import os
from dataclasses import dataclass
from pathlib import Path
from threading import Event
from typing import Callable

@dataclass(frozen=True)
class FileRecord:
    path: Path
    size: int
    mtime_ns: int
    device: int
    inode: int

@dataclass
class ScanResult:
    files: list[FileRecord]
    duplicates: list[list[FileRecord]]
    errors: list[str]
    cancelled: bool = False

def scan(root: Path, exclusions: list[Path] | None = None, cancel: Event | None = None, progress: Callable[[int], None] | None = None) -> ScanResult:
    root = root.expanduser().resolve(strict=True)
    if not root.is_dir():
        raise ValueError('Choose a folder to scan.')
    excluded = [p.expanduser().resolve() for p in (exclusions or [])]
    records, errors = [], []
    cancelled = cancel or Event()
    def is_excluded(p: Path) -> bool:
        return any(p == e or e in p.parents for e in excluded)
    def onerror(err: OSError) -> None:
        errors.append(str(err))
    for current, dirs, names in os.walk(root, followlinks=False, onerror=onerror):
        if cancelled.is_set():
            break
        base = Path(current)
        dirs[:] = [d for d in dirs if not (base / d).is_symlink() and not is_excluded(base / d)]
        for name in names:
            if cancelled.is_set():
                break
            path = base / name
            if is_excluded(path) or path.is_symlink():
                continue
            try:
                st = path.stat(follow_symlinks=False)
                if not path.is_file():
                    continue
                records.append(FileRecord(path, st.st_size, st.st_mtime_ns, st.st_dev, st.st_ino))
                if progress and len(records) % 100 == 0:
                    progress(len(records))
            except OSError as exc:
                errors.append(f'{path}: {exc}')
    by_size: dict[int, list[FileRecord]] = {}
    for rec in records:
        if rec.size:
            by_size.setdefault(rec.size, []).append(rec)
    by_hash: dict[tuple[int, str], list[FileRecord]] = {}
    for group in by_size.values():
        if len(group) < 2:
            continue
        for rec in group:
            if cancelled.is_set():
                break
            try:
                digest = hashlib.sha256()
                with rec.path.open('rb') as f:
                    for chunk in iter(lambda: f.read(1024 * 1024), b''):
                        if cancelled.is_set():
                            break
                        digest.update(chunk)
                st = rec.path.stat(follow_symlinks=False)
                if (st.st_size, st.st_mtime_ns, st.st_dev, st.st_ino) != (rec.size, rec.mtime_ns, rec.device, rec.inode):
                    errors.append(f'{rec.path}: changed during scan')
                    continue
                if not cancelled.is_set():
                    by_hash.setdefault((rec.size, digest.hexdigest()), []).append(rec)
            except OSError as exc:
                errors.append(f'{rec.path}: {exc}')
    groups = [g for g in by_hash.values() if len(g) > 1 and len({(r.device, r.inode) for r in g}) > 1]
    return ScanResult(records, groups, errors, cancelled.is_set())

def unchanged(rec: FileRecord) -> bool:
    try:
        if rec.path.is_symlink():
            return False
        st = rec.path.stat(follow_symlinks=False)
        return (st.st_size, st.st_mtime_ns, st.st_dev, st.st_ino) == (rec.size, rec.mtime_ns, rec.device, rec.inode)
    except OSError:
        return False

