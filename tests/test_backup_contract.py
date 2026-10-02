from __future__ import annotations

import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class BackupContractTests(unittest.TestCase):
    def test_public_root_documents_are_included(self) -> None:
        script = (ROOT / "scripts" / "backup.sh").read_text(encoding="utf-8")
        match = re.search(r"for root_file in ([^;]+); do", script)
        self.assertIsNotNone(match)
        included = set(match.group(1).split())

        for filename in ("VERSION", "README.md", "README.zh-CN.md", "LICENSE"):
            with self.subTest(filename=filename):
                self.assertTrue((ROOT / filename).is_file())
                self.assertIn(filename, included)


if __name__ == "__main__":
    unittest.main()
