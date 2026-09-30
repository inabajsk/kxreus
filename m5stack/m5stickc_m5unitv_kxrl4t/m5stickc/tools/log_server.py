#!/usr/bin/env python3
"""Receive telemetry batches phones buffer from kWebPage and file them by date.

Runs on a PC the phone can reach -- not on the AtomS3, which has neither the
flash budget nor a filesystem worth writing a growing log to (see
lib/policy_mode/policy_mode.h's own remarks on how tight RAM already is).
The phone is the one durable copy until this has it: it logs to its own
IndexedDB the whole time (including with no server configured, or the AtomS3
in its own standalone AP with no route to this machine at all -- see
net::useOwnAccessPoint()), and syncs here opportunistically whenever it next
finds this reachable.

    log_server.py                       # listen on 0.0.0.0:8787
    log_server.py --port 8787 --dir ~/kxreus/atom_phone/field_logs

Stores one line of JSON per record, appended to
    <dir>/<robot>/<date>/<session>.jsonl
`<date>` is the UTC calendar day the SERVER received the batch, not whatever
clock the phone had -- a phone with no network has no reliable time source
either, so trusting it to label its own filing date would drift.

Default --dir is ~/kxreus/atom_phone/field_logs, a sibling of this firmware tree
rather than of the training repo (~/kxreus/walking-kxr-rl) it will eventually
feed, because this server has no involvement from that repo at all -- it is
only ever run from a laptop sitting next to whoever is operating the robot.
walking-kxr-rl reads this same directory through the `field_logs` symlink at
its own top level (see that repo) rather than this tool writing into it
directly, so upgrading walking-kxr-rl (or replacing it) never means touching
this file.

No third-party dependencies (http.server is stdlib): this is a field tool
meant to start with `python3 log_server.py` on whatever laptop is at hand,
not something to `pip install` for first.
"""
import argparse
import json
import os
import re
import sys
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# Session and robot names travel from the phone into a file path; a stray
# "/" or ".." must not turn into writing outside --dir.
_SAFE = re.compile(r"^[A-Za-z0-9_.-]{1,128}$")


def _safe_component(name, fallback):
    return name if isinstance(name, str) and _SAFE.match(name) else fallback


class Handler(BaseHTTPRequestHandler):
    server_version = "kxr-log-server/1"
    # One process serves every robot's phone at once (see ThreadingHTTPServer
    # below); appends to the same day's file from two threads at once are
    # the one place that needs a lock.
    write_lock = threading.Lock()

    def _cors(self):
        # The phone page is served BY THE ROBOT (http://<atom ip>/), a
        # different origin than this server, so every response needs these
        # or the browser discards it before this handler's return value ever
        # reaches the page's fetch() promise.
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def do_OPTIONS(self):
        # The preflight a browser sends ahead of a JSON POST. No body, no
        # meaning beyond "yes, that request is allowed" -- see _cors().
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self):
        # What the phone polls before spending a battery-and-airtime POST on
        # a batch that a still-booting or unreachable server would drop.
        if self.path == "/health":
            self.send_response(200)
            self._cors()
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"ok":true}')
            return
        self.send_response(404)
        self._cors()
        self.end_headers()

    def do_POST(self):
        if self.path != "/upload":
            self.send_response(404)
            self._cors()
            self.end_headers()
            return
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > 8 * 1024 * 1024:
            self._error(400, "bad content-length")
            return
        raw = self.rfile.read(length)
        try:
            payload = json.loads(raw)
        except ValueError:
            self._error(400, "invalid json")
            return
        if not isinstance(payload, dict):
            self._error(400, "expected a json object")
            return

        robot = _safe_component(payload.get("robot"), "unknown")
        session = _safe_component(payload.get("session"), "unknown-session")
        records = payload.get("records")
        if not isinstance(records, list):
            self._error(400, "records must be a list")
            return

        day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        out_dir = os.path.join(self.server.log_dir, robot, day)
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, session + ".jsonl")

        with Handler.write_lock:
            with open(out_path, "a", encoding="utf-8") as f:
                for rec in records:
                    f.write(json.dumps(rec, ensure_ascii=False))
                    f.write("\n")

        self.send_response(200)
        self._cors()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"ok": True, "stored": len(records)}).encode())
        print(f"[log_server] {robot}/{day}/{session}.jsonl += {len(records)} records",
              flush=True)

    def _error(self, code, message):
        self.send_response(code)
        self._cors()
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(json.dumps({"ok": False, "error": message}).encode())

    def log_message(self, fmt, *args):
        pass  # the per-upload print above is the log this tool wants


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--port", type=int, default=8787)
    ap.add_argument("--host", default="0.0.0.0",
                    help="listen address; 0.0.0.0 (default) so a phone on the"
                         " same network can reach it, not just this machine")
    ap.add_argument("--dir", default=os.path.expanduser(
        "~/kxreus/atom_phone/field_logs"),
        help="where <robot>/<date>/<session>.jsonl files are written")
    args = ap.parse_args()

    os.makedirs(args.dir, exist_ok=True)
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    server.log_dir = args.dir
    print(f"[log_server] listening on {args.host}:{args.port}, "
          f"writing under {args.dir}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[log_server] stopped", flush=True)
        sys.exit(0)


if __name__ == "__main__":
    main()
