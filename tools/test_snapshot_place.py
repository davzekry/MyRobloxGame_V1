"""
Tests for snapshot_place.py. They run the real script on small hand-written places.

Usage:
    python tools/test_snapshot_place.py
"""

import base64
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).with_name("snapshot_place.py")
HASH = "yuZpQdnvvUBOTYh1jqZ2cA=="


def encode_tags(*tags):
    return base64.b64encode("\0".join(tags).encode()).decode()


def place_xml(tags_property, shared_strings=""):
    return f"""<roblox version="4">
    <Item class="Part" referent="RBX1">
        <Properties>
            <string name="Name">Coin</string>
            {tags_property}
        </Properties>
    </Item>
    <SharedStrings>{shared_strings}</SharedStrings>
</roblox>
"""


def snapshot(xml):
    with tempfile.TemporaryDirectory() as tmp:
        place = Path(tmp) / "place.rbxlx"
        out = Path(tmp) / "snapshot"
        place.write_text(xml, encoding="utf-8")
        subprocess.run([sys.executable, str(SCRIPT), str(place), "--out", str(out)], check=True,
                       capture_output=True, text=True)
        return (out / "place-tree.md").read_text(encoding="utf-8")


class TagsTest(unittest.TestCase):
    def test_shared_string_tags_resolve_through_the_table(self):
        tree = snapshot(place_xml(
            f'<SharedString name="Tags">{HASH}</SharedString>',
            f'<SharedString md5="{HASH}">{encode_tags("CoinPickup", "Shop")}</SharedString>',
        ))
        self.assertIn("tags=CoinPickup,Shop", tree)

    def test_empty_shared_string_shows_no_tags(self):
        tree = snapshot(place_xml(
            f'<SharedString name="Tags">{HASH}</SharedString>',
            f'<SharedString md5="{HASH}"></SharedString>',
        ))
        self.assertNotIn("tags=", tree)

    def test_binary_string_tags_still_decode(self):
        tree = snapshot(place_xml(f'<BinaryString name="Tags">{encode_tags("CoinPickup")}</BinaryString>'))
        self.assertIn("tags=CoinPickup", tree)


if __name__ == "__main__":
    unittest.main()
