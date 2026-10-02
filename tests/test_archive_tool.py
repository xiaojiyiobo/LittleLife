from __future__ import annotations

import shutil
import tempfile
import unittest
from pathlib import Path

import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import archive_tool


class ArchiveToolTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.data = self.root / "data"
        shutil.copytree(ROOT / "examples" / "archive" / "data", self.data)

    def tearDown(self) -> None:
        self.temp.cleanup()

    def test_validate_and_build_pages(self) -> None:
        result = archive_tool.validate(self.data)
        self.assertEqual(result["records"], 1)
        output = self.root / "derived" / "grav-pages"
        build = archive_tool.build_pages(self.data, output)
        self.assertEqual(build["records"], 1)
        story = output / "02.archive" / "2026" / "20261002-first-smile" / "story.md"
        self.assertTrue(story.is_file())
        self.assertTrue((story.parent / "sample.svg").is_file())

    def test_manifest_detects_change(self) -> None:
        archive_tool.create_manifest(self.data)
        verified = archive_tool.verify_manifest(self.data)
        self.assertEqual(verified["checked"], 1)
        media = self.data / "media-originals" / "2026" / "2026-10-02" / "sample.svg"
        media.write_text("changed", encoding="utf-8")
        with self.assertRaises(archive_tool.ArchiveError):
            archive_tool.verify_manifest(self.data)

    def test_export_uses_open_files(self) -> None:
        archive_tool.create_manifest(self.data)
        destination = self.root / "LittleLife-export.zip"
        result = archive_tool.export_archive(self.data, destination)
        self.assertGreater(result["files"], 1)
        self.assertTrue(destination.is_file())


if __name__ == "__main__":
    unittest.main()
