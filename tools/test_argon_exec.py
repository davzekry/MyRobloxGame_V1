"""
Tests for argon_exec.py. They run the real script against a small local HTTP server.

Usage:
    python tools/test_argon_exec.py
"""

import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

SCRIPT = Path(__file__).with_name("argon_exec.py")


def run_exec(code, status=200):
    received = {}

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            received["path"] = self.path
            received["body"] = self.rfile.read(int(self.headers["Content-Length"]))
            self.send_response(status)
            self.send_header("Content-Length", "0")
            self.end_headers()

        def log_message(self, *args):
            pass

    server = HTTPServer(("localhost", 0), Handler)
    threading.Thread(target=server.handle_request, daemon=True).start()
    with tempfile.TemporaryDirectory() as tmp:
        file = Path(tmp) / "code.luau"
        file.write_text(code, encoding="utf-8")
        result = subprocess.run([sys.executable, str(SCRIPT), str(server.server_port), str(file)],
                                capture_output=True, text=True)
    server.server_close()
    return result, received


class ArgonExecTest(unittest.TestCase):
    def test_posts_code_as_msgpack_to_exec(self):
        code = "x" * 300
        result, received = run_exec(code)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(received["path"], "/exec")
        self.assertEqual(received["body"], b"\x82\xa4code\xda\x01\x2c" + code.encode() + b"\xa5focus\xc2")

    def test_server_error_exits_nonzero(self):
        result, _ = run_exec("print('hi')", status=500)
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
