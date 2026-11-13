"""Minimaler HTTP-PUT-Server fuer den Transfer Gast -> Host (Phase 11.7).

Aufruf: python putserver.py <port> <zielverzeichnis>
Nimmt PUT /<name> entgegen und schreibt die Bytes nach <zielverzeichnis>/<name>.
Nur fuer lokale Transfers im Testnetz gedacht.
"""
import http.server
import os
import sys

PORT = int(sys.argv[1])
DEST = sys.argv[2]


class Handler(http.server.BaseHTTPRequestHandler):
    def do_PUT(self):
        name = os.path.basename(self.path.lstrip("/")) or "upload.bin"
        total = int(self.headers.get("Content-Length", 0))
        target = os.path.join(DEST, name)
        got = 0
        with open(target, "wb") as fh:
            while got < total:
                chunk = self.rfile.read(min(1 << 20, total - got))
                if not chunk:
                    break
                fh.write(chunk)
                got += len(chunk)
        self.send_response(201 if got == total else 500)
        self.end_headers()
        self.wfile.write(("ok %d\n" % got).encode())

    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"nova-putserver bereit\n")

    def log_message(self, *args):
        pass


os.makedirs(DEST, exist_ok=True)
http.server.ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
