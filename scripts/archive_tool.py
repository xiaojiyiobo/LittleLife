#!/usr/bin/env python3
"""Validate, derive, hash, and export a LittleLife open-file archive."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import shutil
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

import yaml


ID_RE = re.compile(r"^[0-9]{8}-[a-z0-9]+(?:-[a-z0-9]+)*$")
REQUIRED = {"id", "date", "title", "type", "media", "visibility", "created_at", "updated_at"}
ALLOWED_TYPES = {"story", "milestone", "note"}
DERIVED_MARKER = ".littlelife-derived"


class ArchiveError(RuntimeError):
    pass


@dataclass(frozen=True)
class Record:
    path: Path
    header: dict[str, Any]
    body: str
    media: tuple[Path, ...]


def _inside(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def _parse_datetime(value: Any, field: str, source: Path) -> dt.datetime:
    if isinstance(value, dt.datetime):
        parsed = value
    elif isinstance(value, str):
        try:
            parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError as exc:
            raise ArchiveError(f"{source}: {field} is not ISO-8601: {value}") from exc
    else:
        raise ArchiveError(f"{source}: {field} must be an ISO-8601 timestamp")
    if parsed.tzinfo is None or parsed.utcoffset() is None:
        raise ArchiveError(f"{source}: {field} must include a timezone offset")
    return parsed


def _frontmatter(path: Path) -> tuple[dict[str, Any], str]:
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    if not lines or lines[0].strip() != "---":
        raise ArchiveError(f"{path}: missing opening YAML front-matter marker")
    closing = next((i for i, line in enumerate(lines[1:], start=1) if line.strip() == "---"), None)
    if closing is None:
        raise ArchiveError(f"{path}: missing closing YAML front-matter marker")
    try:
        header = yaml.safe_load("".join(lines[1:closing])) or {}
    except yaml.YAMLError as exc:
        raise ArchiveError(f"{path}: invalid YAML: {exc}") from exc
    if not isinstance(header, dict):
        raise ArchiveError(f"{path}: front matter must be a mapping")
    return header, "".join(lines[closing + 1 :]).lstrip("\n")


def load_records(data_root: Path) -> list[Record]:
    data_root = data_root.resolve()
    entries_root = data_root / "entries"
    originals_root = (data_root / "media-originals").resolve()
    if not entries_root.is_dir():
        raise ArchiveError(f"missing entries directory: {entries_root}")
    if not originals_root.is_dir():
        raise ArchiveError(f"missing original-media directory: {originals_root}")

    records: list[Record] = []
    ids: set[str] = set()
    for path in sorted(entries_root.rglob("*.md")):
        header, body = _frontmatter(path)
        missing = REQUIRED - set(header)
        if missing:
            raise ArchiveError(f"{path}: missing required fields: {', '.join(sorted(missing))}")
        record_id = header["id"]
        if not isinstance(record_id, str) or not ID_RE.fullmatch(record_id):
            raise ArchiveError(f"{path}: invalid id: {record_id!r}")
        if record_id in ids:
            raise ArchiveError(f"{path}: duplicate id: {record_id}")
        ids.add(record_id)
        if not isinstance(header["title"], str) or not header["title"].strip():
            raise ArchiveError(f"{path}: title must be non-empty")
        if header["type"] not in ALLOWED_TYPES:
            raise ArchiveError(f"{path}: unsupported type: {header['type']!r}")
        if header["visibility"] != "private":
            raise ArchiveError(f"{path}: prototype records must have visibility: private")
        event_time = _parse_datetime(header["date"], "date", path)
        created = _parse_datetime(header["created_at"], "created_at", path)
        updated = _parse_datetime(header["updated_at"], "updated_at", path)
        if updated < created:
            raise ArchiveError(f"{path}: updated_at precedes created_at")
        if str(event_time.year) not in path.relative_to(entries_root).parts:
            raise ArchiveError(f"{path}: entry directory does not match date year {event_time.year}")
        media_value = header["media"]
        if not isinstance(media_value, list) or not all(isinstance(item, str) for item in media_value):
            raise ArchiveError(f"{path}: media must be a list of relative paths")
        resolved_media: list[Path] = []
        for item in media_value:
            if Path(item).is_absolute():
                raise ArchiveError(f"{path}: absolute media path is forbidden: {item}")
            media_path = (path.parent / item).resolve()
            if not _inside(media_path, originals_root):
                raise ArchiveError(f"{path}: media escapes media-originals: {item}")
            if not media_path.is_file():
                raise ArchiveError(f"{path}: referenced media does not exist: {item}")
            resolved_media.append(media_path)
        records.append(Record(path=path, header=header, body=body, media=tuple(resolved_media)))
    if not records:
        raise ArchiveError(f"no Markdown records found below {entries_root}")
    return records


def validate(data_root: Path) -> dict[str, Any]:
    records = load_records(data_root)
    media_files = {path for record in records for path in record.media}
    return {
        "status": "ok",
        "records": len(records),
        "referenced_media": len(media_files),
        "data_root": str(data_root.resolve()),
    }


def _prepare_derived(output: Path) -> None:
    output = output.resolve()
    if output == Path(output.anchor):
        raise ArchiveError("refusing to use a filesystem root as derived output")
    marker = output / DERIVED_MARKER
    if output.exists() and any(output.iterdir()) and not marker.is_file():
        raise ArchiveError(f"refusing to replace unmarked directory: {output}")
    output.mkdir(parents=True, exist_ok=True)
    for child in list(output.iterdir()):
        if child.is_dir() and not child.is_symlink():
            shutil.rmtree(child)
        else:
            child.unlink()
    marker.write_text("Generated by LittleLife archive_tool.py; safe to rebuild.\n", encoding="utf-8")


def _write_page(path: Path, header: dict[str, Any], body: str = "") -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    yaml_text = yaml.safe_dump(header, allow_unicode=True, sort_keys=False).strip()
    path.write_text(f"---\n{yaml_text}\n---\n\n{body.rstrip()}\n", encoding="utf-8", newline="\n")


def build_pages(data_root: Path, output: Path) -> dict[str, Any]:
    data_root = data_root.resolve()
    records = load_records(data_root)
    profile_path = data_root / "profile" / "child.yaml"
    if not profile_path.is_file():
        raise ArchiveError(f"missing profile: {profile_path}")
    profile = yaml.safe_load(profile_path.read_text(encoding="utf-8")) or {}
    if not isinstance(profile, dict) or not profile.get("display_name"):
        raise ArchiveError(f"{profile_path}: display_name is required")

    _prepare_derived(output)
    _write_page(
        output / "00.home" / "home.md",
        {"title": str(profile["display_name"]), "template": "home", "visible": True},
        str(profile.get("notice", "私人家庭成长档案。")),
    )
    _write_page(
        output / "01.timeline" / "timeline.md",
        {"title": "时间线", "template": "timeline", "visible": True},
        "按年份浏览成长记录。",
    )
    _write_page(output / "02.archive" / "default.md", {"title": "档案", "visible": False})

    media_count = 0
    entries_root = data_root / "entries"
    for record in records:
        event_time = _parse_datetime(record.header["date"], "date", record.path)
        year_root = output / "02.archive" / str(event_time.year)
        year_page = year_root / "default.md"
        if not year_page.exists():
            _write_page(year_page, {"title": str(event_time.year), "visible": False})
        page_root = year_root / str(record.header["id"])
        page_root.mkdir(parents=True, exist_ok=True)
        derived_names: list[str] = []
        used: set[str] = set()
        for index, media_path in enumerate(record.media, start=1):
            candidate = media_path.name
            if candidate in used:
                candidate = f"{index:02d}-{candidate}"
            used.add(candidate)
            shutil.copy2(media_path, page_root / candidate)
            derived_names.append(candidate)
            media_count += 1
        page_header = dict(record.header)
        page_header.update(
            {
                "template": "story",
                "visible": False,
                "media_files": derived_names,
                "source_record": record.path.relative_to(data_root).as_posix(),
            }
        )
        _write_page(page_root / "story.md", page_header, record.body)

    return {"status": "ok", "records": len(records), "media_copies": media_count, "output": str(output.resolve())}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _original_files(data_root: Path) -> Iterable[Path]:
    originals = data_root.resolve() / "media-originals"
    if not originals.is_dir():
        raise ArchiveError(f"missing original-media directory: {originals}")
    return sorted(path for path in originals.rglob("*") if path.is_file())


def create_manifest(data_root: Path, manifest: Path | None = None) -> dict[str, Any]:
    data_root = data_root.resolve()
    manifest = (manifest or data_root / "manifests" / "media-sha256.txt").resolve()
    if not _inside(manifest, data_root / "manifests"):
        raise ArchiveError("manifest must be written below data/manifests")
    lines = [f"{_sha256(path)}  {path.relative_to(data_root).as_posix()}" for path in _original_files(data_root)]
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8", newline="\n")
    return {"status": "ok", "files": len(lines), "manifest": str(manifest)}


def verify_manifest(data_root: Path, manifest: Path | None = None) -> dict[str, Any]:
    data_root = data_root.resolve()
    manifest = (manifest or data_root / "manifests" / "media-sha256.txt").resolve()
    if not manifest.is_file():
        raise ArchiveError(f"manifest not found: {manifest}")
    failures: list[str] = []
    checked = 0
    for line_number, line in enumerate(manifest.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            expected, relative = line.split("  ", 1)
        except ValueError:
            failures.append(f"line {line_number}: malformed")
            continue
        target = (data_root / relative).resolve()
        if not _inside(target, data_root) or not target.is_file():
            failures.append(f"{relative}: missing or outside archive")
            continue
        actual = _sha256(target)
        checked += 1
        if actual != expected:
            failures.append(f"{relative}: expected {expected}, got {actual}")
    if failures:
        raise ArchiveError("manifest verification failed:\n" + "\n".join(failures))
    return {"status": "ok", "checked": checked, "manifest": str(manifest)}


def export_archive(data_root: Path, destination: Path) -> dict[str, Any]:
    data_root = data_root.resolve()
    destination = destination.resolve()
    if _inside(destination, data_root):
        raise ArchiveError("export destination must be outside the source data directory")
    destination.parent.mkdir(parents=True, exist_ok=True)
    allowed_roots = ["README.md", "profile", "entries", "media-originals", "manifests"]
    count = 0
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name in allowed_roots:
            source = data_root / name
            if source.is_file():
                archive.write(source, Path("LittleLife-data") / name)
                count += 1
            elif source.is_dir():
                for path in sorted(item for item in source.rglob("*") if item.is_file()):
                    archive.write(path, Path("LittleLife-data") / path.relative_to(data_root))
                    count += 1
    return {"status": "ok", "files": count, "export": str(destination)}


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("validate", "manifest", "verify"):
        item = sub.add_parser(command)
        item.add_argument("--data", type=Path, required=True)
    build = sub.add_parser("build-pages")
    build.add_argument("--data", type=Path, required=True)
    build.add_argument("--output", type=Path, required=True)
    export = sub.add_parser("export")
    export.add_argument("--data", type=Path, required=True)
    export.add_argument("--output", type=Path, required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "validate":
            result = validate(args.data)
        elif args.command == "build-pages":
            result = build_pages(args.data, args.output)
        elif args.command == "manifest":
            result = create_manifest(args.data)
        elif args.command == "verify":
            result = verify_manifest(args.data)
        elif args.command == "export":
            result = export_archive(args.data, args.output)
        else:
            raise AssertionError(args.command)
    except (ArchiveError, OSError, yaml.YAMLError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

