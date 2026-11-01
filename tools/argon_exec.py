"""
Run a Luau file in Studio through a local Argon server's /exec endpoint.

Usage:
    python tools/argon_exec.py <port> <file.luau>

Use the port Studio is connected to. The server replies with success even when no Studio
is attached, so confirm the result in Studio or with a fresh snapshot.
"""

import sys
import urllib.error
import urllib.request
from pathlib import Path


def mp_str(text):
    raw = text.encode("utf-8")
    n = len(raw)
    if n < 32:
        return bytes([0xA0 | n]) + raw
    if n < 256:
        return bytes([0xD9, n]) + raw
    return bytes([0xDA]) + n.to_bytes(2, "big") + raw


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    port, path = sys.argv[1], sys.argv[2]
    body = bytes([0x82]) + mp_str("code") + mp_str(Path(path).read_text(encoding="utf-8")) + mp_str("focus") + b"\xc2"
    request = urllib.request.Request(
        f"http://localhost:{port}/exec", data=body, method="POST", headers={"Content-Type": "application/msgpack"}
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            print("status", response.status, response.read()[:200])
    except urllib.error.HTTPError as error:
        sys.exit(f"status {error.code} {error.read()[:200]}")


if __name__ == "__main__":
    main()
