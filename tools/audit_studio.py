"""
Compare the scripts in Studio with the scripts on disk. Read-only.

Usage:
    python tools/audit_studio.py <port>

Use the port Studio's Argon plugin is connected to. Exits with 1 if Studio doesn't match
the files or doesn't report back. Update a STALE file's modified time to make Argon resend it.
"""

import json
import socket
import subprocess
import sys
import threading
from collections import Counter
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

TOOLS = Path(__file__).parent
LISTEN_PORT = 8765
TIMEOUT_SECONDS = 30
SCRIPT_SUFFIXES = (".server.luau", ".client.luau", ".luau")


def instance_name(file_name):
    for suffix in SCRIPT_SUFFIXES:
        if file_name.endswith(suffix):
            return file_name[: -len(suffix)]
    return None


def add_scripts(folder, prefix, found):
    for path in sorted(folder.iterdir()):
        if path.is_dir():
            add_scripts(path, f"{prefix}.{path.name}", found)
        elif instance_name(path.name):
            # Argon normalizes line endings, so CRLF on disk is LF in Studio.
            found[f"{prefix}.{instance_name(path.name)}"] = len(path.read_bytes().replace(b"\r\n", b"\n"))


def add_tree(node, prefix, root, found):
    if "$path" in node:
        add_scripts(root / node["$path"], prefix, found)
    for name, child in node.items():
        if not name.startswith("$"):
            add_tree(child, f"{prefix}.{name}" if prefix else name, root, found)


def expected_scripts(project_file):
    project_file = Path(project_file)
    found = {}
    add_tree(json.loads(project_file.read_text(encoding="utf-8"))["tree"], "", project_file.parent, found)
    return found


def compare(expected, studio_items):
    problems = []
    counts = Counter(item["path"] for item in studio_items)
    sizes = {item["path"]: item["chars"] for item in studio_items}

    for path, count in sorted(counts.items()):
        if count > 1:
            problems.append(f"DUPLICATE {path} x{count}")
        if path not in expected:
            problems.append(f"EXTRA {path}")
    for path, chars in sorted(expected.items()):
        if path not in sizes:
            problems.append(f"MISSING {path}")
        elif counts[path] == 1 and sizes[path] != chars:
            problems.append(f"STALE {path}: disk {chars}, Studio {sizes[path]}")
    return problems


def request_report(port):
    received = threading.Event()
    report = {}

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            report["items"] = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            self.send_response(200)
            self.send_header("Content-Length", "0")
            self.end_headers()
            received.set()

        def log_message(self, *args):
            pass

    class IPv6Server(HTTPServer):
        address_family = socket.AF_INET6

    for server in (HTTPServer(("127.0.0.1", LISTEN_PORT), Handler), IPv6Server(("::1", LISTEN_PORT), Handler)):
        threading.Thread(target=server.serve_forever, daemon=True).start()

    subprocess.run([sys.executable, str(TOOLS / "argon_exec.py"), port, str(TOOLS / "audit_studio.luau")],
                   check=True, capture_output=True)
    return report["items"] if received.wait(TIMEOUT_SECONDS) else None


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)

    items = request_report(sys.argv[1])
    if items is None:
        sys.exit(f"Studio didn't report within {TIMEOUT_SECONDS} seconds. Is Argon connected on port {sys.argv[1]}?")

    problems = compare(expected_scripts(TOOLS.parent / "default.project.json"), items)
    if problems:
        sys.exit("\n".join(problems))
    print(f"OK: Studio matches disk ({len(items)} scripts)")


if __name__ == "__main__":
    main()
