"""
Tests for audit_studio.py. They cover the comparison, which needs no Studio.

Usage:
    python tools/test_audit_studio.py
"""

import json
import tempfile
import unittest
from pathlib import Path

import audit_studio


def item(path, chars):
    return {"path": path, "chars": chars}


class CompareTest(unittest.TestCase):
    def test_matching_scripts_have_no_problems(self):
        self.assertEqual(audit_studio.compare({"A.B": 5}, [item("A.B", 5)]), [])

    def test_stale_script_is_reported(self):
        self.assertEqual(audit_studio.compare({"A.B": 5}, [item("A.B", 4)]), ["STALE A.B: disk 5, Studio 4"])

    def test_missing_script_is_reported(self):
        self.assertEqual(audit_studio.compare({"A.B": 5}, []), ["MISSING A.B"])

    def test_extra_script_is_reported(self):
        self.assertEqual(audit_studio.compare({}, [item("A.Main", 5)]), ["EXTRA A.Main"])

    def test_duplicate_script_is_reported(self):
        self.assertEqual(audit_studio.compare({"A.B": 5}, [item("A.B", 5), item("A.B", 5)]), ["DUPLICATE A.B x2"])


class ExpectedScriptsTest(unittest.TestCase):
    def test_maps_project_paths_to_instance_names(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "src" / "Server" / "Rules").mkdir(parents=True)
            (root / "src" / "Client").mkdir()
            (root / "src" / "Server" / "Boot.server.luau").write_bytes(b"abc")
            (root / "src" / "Server" / "Rules" / "A.spec.luau").write_bytes(b"ab")
            (root / "src" / "Client" / "Main.client.luau").write_bytes(b"a")
            (root / "default.project.json").write_text(json.dumps({"tree": {
                "$className": "DataModel",
                "ServerScriptService": {"$path": "src/Server"},
                "StarterPlayer": {"StarterPlayerScripts": {"$path": "src/Client"}},
            }}))

            self.assertEqual(audit_studio.expected_scripts(root / "default.project.json"), {
                "ServerScriptService.Boot": 3,
                "ServerScriptService.Rules.A.spec": 2,
                "StarterPlayer.StarterPlayerScripts.Main": 1,
            })

    def test_windows_line_endings_count_as_one_character(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "src").mkdir()
            (root / "src" / "A.luau").write_bytes(b"a\r\nb\r\n")
            (root / "default.project.json").write_text(json.dumps({"tree": {
                "ReplicatedStorage": {"$path": "src"},
            }}))

            self.assertEqual(audit_studio.expected_scripts(root / "default.project.json"), {"ReplicatedStorage.A": 4})


if __name__ == "__main__":
    unittest.main()
