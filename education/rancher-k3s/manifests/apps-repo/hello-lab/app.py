""" ── COPY for the rancher-k3s study track. Source of truth: GitLab production/rancher-k3s → hello-lab/app.py @ 0682a5d (as built Oct 27, 2026). ── """
"""hello-lab — the smallest app that proves build -> registry -> Fleet -> pod end to end.

GET /         JSON with the commit the image was built from and the pod that answered
GET /healthz  200 "ok" (liveness/readiness)
"""
import json
import os
import signal
import socket
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

VERSION = os.environ.get("GIT_SHA", "unknown")
PORT = int(os.environ.get("PORT", "8080"))


class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype):
        data = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/healthz":
            self._send(200, "ok\n", "text/plain")
        elif self.path == "/":
            self._send(200, json.dumps({
                "app": "hello-lab",
                "version": VERSION,
                "delivered_by": "fleet" if os.environ.get("POD_NAMESPACE") == "hello-lab" else "push",
                "pod": socket.gethostname(),
                "namespace": os.environ.get("POD_NAMESPACE", "?"),
            }) + "\n", "application/json")
        else:
            self._send(404, "not found\n", "text/plain")

    def log_message(self, fmt, *args):
        if self.path != "/healthz":
            super().log_message(fmt, *args)


if __name__ == "__main__":
    # As PID 1, Python gets no default SIGTERM action; without this every rollout waits the full
    # 30 s terminationGracePeriod before the kubelet SIGKILLs the old pod.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    HTTPServer(("", PORT), Handler).serve_forever()
