"""
Turn a Roblox place saved as XML (.rbxlx) into a compact, readable snapshot
of the whole DataModel (Workspace, Lighting, ReplicatedStorage, ...).

Usage:
    python tools/snapshot_place.py [place.rbxlx] [--out snapshot]

Outputs:
    snapshot/place-tree.md   one line per instance with the useful properties
                             (position, size, anchored, material, tags, attributes, refs...)
    snapshot/scripts/...     source of every script found in the place, mirrored by path

Read-only: never touches Studio or the .rbxlx file.
"""

import argparse
import base64
import math
import struct
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

SCRIPT_CLASSES = {"Script", "LocalScript", "ModuleScript"}
SCRIPT_EXT = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}

# Collapse runs of identical leaf siblings (same name + class) at or above this count.
COLLAPSE_AT = 5

MATERIALS = {
    256: "Plastic", 272: "SmoothPlastic", 288: "Neon", 512: "Wood", 528: "WoodPlanks",
    784: "Marble", 788: "Basalt", 800: "Slate", 804: "CrackedLava", 816: "Concrete",
    820: "Limestone", 832: "Granite", 836: "Pavement", 848: "Brick", 864: "Pebble",
    880: "Cobblestone", 896: "Rock", 912: "Sandstone", 1040: "CorrodedMetal",
    1056: "DiamondPlate", 1072: "Foil", 1088: "Metal", 1280: "Grass", 1284: "LeafyGrass",
    1296: "Sand", 1312: "Fabric", 1328: "Snow", 1344: "Mud", 1360: "Ground",
    1376: "Asphalt", 1392: "Salt", 1536: "Ice", 1552: "Glacier", 1568: "Glass",
    1584: "ForceField", 1792: "Air", 2048: "Water", 2304: "Cardboard", 2305: "Carpet",
    2306: "CeramicTiles", 2307: "ClayRoofTiles", 2308: "RoofShingles", 2309: "Leather",
    2310: "Plaster", 2311: "Rubber",
}
PART_SHAPES = {0: "Ball", 1: "Block", 2: "Cylinder", 3: "Wedge", 4: "CornerWedge"}

# Properties worth showing when present (by XML property name).
INTERESTING = {
    "Anchored", "CanCollide", "CanTouch", "CanQuery", "Massless", "Transparency",
    "Enabled", "Disabled", "RunContext", "Value", "Text", "ActionText", "ObjectText",
    "HoldDuration", "MaxActivationDistance", "Health", "MaxHealth", "WalkSpeed",
    "JumpPower", "Volume", "Looped", "Playing", "Brightness", "Range", "Face",
    "ClockTime", "Ambient", "Archivable", "Locked", "CollisionGroup", "Duration",
}
# Defaults that are noise; skip them.
SKIP_IF = {
    "CanCollide": "true", "CanTouch": "true", "CanQuery": "true", "Massless": "false",
    "Transparency": "0", "Enabled": "true", "Disabled": "false", "Archivable": "true",
    "Locked": "false", "CollisionGroup": "Default", "Looped": "false", "Playing": "false",
}


def num(v):
    v = float(v)
    if abs(v) < 5e-4:
        v = 0.0
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s == "-0" else s


def vec(el, keys=("X", "Y", "Z")):
    return "(" + ", ".join(num(el.findtext(k, "0")) for k in keys) + ")"


def cframe(el):
    pos = vec(el)
    r = [float(el.findtext(k, "0")) for k in
         ("R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")]
    # Same convention as BasePart.Orientation (YXZ), in degrees.
    rx = math.degrees(math.asin(max(-1.0, min(1.0, -r[5]))))
    ry = math.degrees(math.atan2(r[2], r[8]))
    rz = math.degrees(math.atan2(r[3], r[4]))
    if all(abs(a) < 0.05 for a in (rx, ry, rz)):
        return f"pos={pos}"
    return f"pos={pos} rot=({num(rx)}, {num(ry)}, {num(rz)})"


def color_u8(text):
    v = int(text)
    return f"rgb({(v >> 16) & 255},{(v >> 8) & 255},{v & 255})"


def decode_tags(text):
    try:
        raw = base64.b64decode((text or "").strip())
    except Exception:
        return []
    return [t for t in raw.decode("utf-8", "replace").split("\0") if t]


def decode_attributes(text):
    """Decode Roblox AttributesSerialize. Unknown types stop decoding gracefully."""
    try:
        b = base64.b64decode((text or "").strip())
    except Exception:
        return {}
    if not b:
        return {}
    out, i = {}, 0

    def u32():
        nonlocal i
        v = struct.unpack_from("<I", b, i)[0]
        i += 4
        return v

    def string():
        nonlocal i
        n = u32()
        s = b[i:i + n].decode("utf-8", "replace")
        i += n
        return s

    def floats(n):
        nonlocal i
        v = struct.unpack_from(f"<{n}f", b, i)
        i += 4 * n
        return v

    try:
        for _ in range(u32()):
            key = string()
            t = b[i]
            i += 1
            if t == 0x02:
                val = repr(string())
            elif t == 0x03:
                val = "true" if b[i] else "false"
                i += 1
            elif t == 0x05:
                val = num(floats(1)[0])
            elif t == 0x06:
                val = num(struct.unpack_from("<d", b, i)[0])
                i += 8
            elif t == 0x0E:
                val = f"BrickColor({u32()})"
            elif t == 0x0F:
                c = floats(3)
                val = f"rgb({','.join(str(round(x * 255)) for x in c)})"
            elif t == 0x10:
                val = "(" + ", ".join(num(x) for x in floats(2)) + ")"
            elif t == 0x11:
                val = "(" + ", ".join(num(x) for x in floats(3)) + ")"
            elif t == 0x1B:
                val = "NumberRange(" + ", ".join(num(x) for x in floats(2)) + ")"
            else:
                out[key] = f"<type 0x{t:02x}>"
                break
            out[key] = val
    except (struct.error, IndexError):
        pass
    return out


class Node:
    __slots__ = ("cls", "name", "ref", "props", "children", "parent")

    def __init__(self, cls, ref, parent):
        self.cls, self.ref, self.parent = cls, ref, parent
        self.name = cls
        self.props = {}
        self.children = []

    def path(self):
        parts, n = [], self
        while n:
            parts.append(n.name)
            n = n.parent
        return ".".join(reversed(parts))


def resolve_shared_strings(root):
    """Replace each SharedString property's hash with the value stored in the SharedStrings table."""
    table = root.find("SharedStrings")
    values = {s.get("md5"): s.text or "" for s in table} if table is not None else {}
    for el in root.iter("SharedString"):
        if el.get("name"):
            el.text = values.get((el.text or "").strip(), "")


def parse(item, parent, by_ref):
    node = Node(item.get("class"), item.get("referent"), parent)
    if node.ref:
        by_ref[node.ref] = node
    props = item.find("Properties")
    if props is not None:
        for p in props:
            pname = p.get("name")
            if pname == "Name":
                node.name = p.text or ""
            else:
                node.props[pname] = p
    for child in item.findall("Item"):
        node.children.append(parse(child, node, by_ref))
    return node


def describe(node, by_ref):
    bits = []
    P = node.props

    cf = P.get("CFrame")
    if cf is not None and node.cls != "Camera":
        bits.append(cframe(cf))
    size = P.get("size") if "size" in P else P.get("Size")
    if size is not None and size.tag == "Vector3":
        bits.append(f"size={vec(size)}")
    shape = P["shape"] if "shape" in P else P.get("Shape")
    if shape is not None:
        s = shape.text
        if s and s.isdigit() and int(s) != 1:
            bits.append(f"shape={PART_SHAPES.get(int(s), s)}")
    mat = P.get("Material")
    if mat is not None and mat.text and mat.text.isdigit() and int(mat.text) != 256:
        bits.append(MATERIALS.get(int(mat.text), f"Material#{mat.text}"))
    col = P.get("Color3uint8")
    if col is not None and col.text:
        bits.append(color_u8(col.text))

    for pname, p in P.items():
        tag = p.tag
        text = (p.text or "").strip()
        if pname in INTERESTING and tag in ("bool", "float", "double", "int", "int64", "string", "token"):
            if SKIP_IF.get(pname) == text or (tag == "float" and pname in SKIP_IF and num(text) == SKIP_IF[pname]):
                continue
            if tag in ("float", "double"):
                text = num(text)
            elif tag == "string":
                text = repr(text)
            bits.append(f"{pname}={text}")
        elif tag == "Ref" and text and text != "null":
            target = by_ref.get(text)
            bits.append(f"{pname}->{target.path() if target else text}")
        elif tag in ("Content", "ContentId") and pname != "Source":
            url = (p.findtext("url") or text or "").strip()
            if url and url != "null":
                bits.append(f"{pname}={url}")
        elif tag == "Vector3" and pname == "Value":
            bits.append(f"Value={vec(p)}")
        elif tag == "CoordinateFrame" and pname == "Value":
            bits.append(f"Value=CFrame{cframe(p)}")

    tags = decode_tags(P["Tags"].text) if "Tags" in P else []
    if tags:
        bits.append("tags=" + ",".join(tags))
    attrs = decode_attributes(P["AttributesSerialize"].text) if "AttributesSerialize" in P else {}
    if attrs:
        bits.append("attrs{" + ", ".join(f"{k}={v}" for k, v in attrs.items()) + "}")
    return " ".join(bits)


def is_leaf_dup_key(node, by_ref):
    if node.children:
        return None
    return (node.cls, node.name)


def write_tree(node, by_ref, lines, depth, stats):
    stats[node.cls] += 1
    desc = describe(node, by_ref)
    script_note = " (source in snapshot/scripts)" if node.cls in SCRIPT_CLASSES else ""
    lines.append(f"{'  ' * depth}- {node.name} [{node.cls}]{(' ' + desc) if desc else ''}{script_note}")

    # Group identical leaf siblings so huge builds stay readable.
    groups = defaultdict(list)
    for c in node.children:
        k = is_leaf_dup_key(c, by_ref)
        if k:
            groups[k].append(c)
    emitted = set()
    for c in node.children:
        k = is_leaf_dup_key(c, by_ref)
        if k and len(groups[k]) >= COLLAPSE_AT:
            if k in emitted:
                stats[c.cls] += 1
                continue
            emitted.add(k)
            stats[c.cls] += 1
            lines.append(f"{'  ' * (depth + 1)}- {c.name} [{c.cls}] x{len(groups[k])} "
                         f"(collapsed; first: {describe(c, by_ref) or 'no props'})")
        else:
            write_tree(c, by_ref, lines, depth + 1, stats)


def dump_scripts(node, out_dir, count):
    if node.cls in SCRIPT_CLASSES:
        src = node.props.get("Source")
        rel = Path(*[safe(n) for n in node.path().split(".")])
        dest = out_dir / rel.with_name(rel.name + SCRIPT_EXT[node.cls])
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text((src.text if src is not None else "") or "", encoding="utf-8")
        count[0] += 1
    for c in node.children:
        dump_scripts(c, out_dir, count)


def safe(name):
    return "".join(ch if ch.isalnum() or ch in " _-()" else "_" for ch in name) or "_"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("place", nargs="?", default="place.rbxlx")
    ap.add_argument("--out", default="snapshot")
    args = ap.parse_args()

    place = Path(args.place)
    if place.suffix.lower() == ".rbxl":
        sys.exit("Binary .rbxl is not supported. In Studio use File > Save to File As... and pick .rbxlx")
    if not place.exists():
        sys.exit(f"{place} not found. In Studio: File > Save to File As... > {place.name}")

    root = ET.parse(place).getroot()
    resolve_shared_strings(root)
    by_ref = {}
    game = Node("DataModel", None, None)
    game.name = "game"
    for item in root.findall("Item"):
        game.children.append(parse(item, game, by_ref))

    out = Path(args.out)
    scripts_dir = out / "scripts"
    if scripts_dir.exists():
        for f in sorted(scripts_dir.rglob("*"), reverse=True):
            f.unlink() if f.is_file() else f.rmdir()
    out.mkdir(parents=True, exist_ok=True)

    lines, stats = [], defaultdict(int)
    # Workspace first: it's what matters most when scripting the world.
    services = sorted(game.children, key=lambda n: (n.cls != "Workspace", n.cls))
    for svc in services:
        if not svc.children and not describe(svc, by_ref):
            continue
        write_tree(svc, by_ref, lines, 0, stats)

    count = [0]
    dump_scripts(game, scripts_dir, count)

    top = ", ".join(f"{c} {n}" for c, n in sorted(stats.items(), key=lambda kv: -kv[1])[:15])
    header = [
        f"# Place snapshot: {place.name}",
        "",
        "Generated by tools/snapshot_place.py. Positions/sizes in studs, rot = Orientation in degrees.",
        f"Instances: {sum(stats.values())} | Scripts exported: {count[0]} | Top classes: {top}",
        "",
    ]
    (out / "place-tree.md").write_text("\n".join(header + lines) + "\n", encoding="utf-8")
    print(f"Wrote {out / 'place-tree.md'} ({sum(stats.values())} instances, {count[0]} scripts)")


if __name__ == "__main__":
    main()
