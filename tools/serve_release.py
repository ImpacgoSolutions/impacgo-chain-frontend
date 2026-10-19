"""Serves build/web for the fast release copy. Every response says "do not cache", so a reload (or the app's Restart button)
always shows the newest build and never an old copy kept by the browser.
Usage: python tools/serve_release.py 8099 build/web
"""
import http.server
import os
import sys


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()

    def log_message(self, *args):
        pass


port = int(sys.argv[1]) if len(sys.argv) > 1 else 8099
folder = sys.argv[2] if len(sys.argv) > 2 else "build/web"
os.chdir(folder)
http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler).serve_forever()
