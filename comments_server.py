"""
Static-file server for the deck + a tiny comments API with edit/delete support.

Endpoints:
  GET    /                              — serves files from this directory
  GET    /api/comments?slide=<id>       — JSON list of comments for that slide (tokens stripped)
  POST   /api/comments                  — body: {slide, name, text} → returns the new row INCLUDING a token
  PATCH  /api/comments/<id>             — header: X-Comment-Token; body: {text} → updates that comment
  DELETE /api/comments/<id>             — header: X-Comment-Token → removes that comment

Each comment gets a random token on POST. The client stores it in localStorage and sends it
back to authorize edits/deletes. GET responses strip the token so other clients can't read it.

Comments persist to ./comments.json. No real auth — token-on-create + localStorage is just
"only the original poster's browser can edit/delete."

Run:
  python3 comments_server.py            # defaults to port 8765
  python3 comments_server.py 8080       # custom port
"""
import json
import os
import sys
import uuid
import threading
from datetime import datetime, timezone
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

HERE = os.path.dirname(os.path.abspath(__file__))
# COMMENTS_FILE env var lets a deploy point at a persistent volume (e.g. /data/comments.json
# on Fly.io). Falls back to the script directory for local runs.
COMMENTS_FILE = os.environ.get("COMMENTS_FILE") or os.path.join(HERE, "comments.json")
LOCK = threading.Lock()


def _read():
    if not os.path.exists(COMMENTS_FILE):
        return []
    try:
        with open(COMMENTS_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, list) else []
    except (json.JSONDecodeError, OSError):
        return []


def _write(rows):
    tmp = COMMENTS_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)
    os.replace(tmp, COMMENTS_FILE)


def _public(row):
    """Return a copy of a comment row without the secret token."""
    return {k: v for k, v in row.items() if k != "token"}


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=HERE, **kw)

    def log_message(self, fmt, *args):
        if "/api/" in (self.path or ""):
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    # ---------- routing ----------

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/comments":
            return self._get_comments(parsed)
        return super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/comments":
            return self._post_comment()
        self.send_error(404)

    def do_PATCH(self):
        parsed = urlparse(self.path)
        if parsed.path.startswith("/api/comments/"):
            cid = parsed.path[len("/api/comments/"):]
            return self._update_comment(cid)
        self.send_error(404)

    def do_DELETE(self):
        parsed = urlparse(self.path)
        if parsed.path.startswith("/api/comments/"):
            cid = parsed.path[len("/api/comments/"):]
            return self._delete_comment(cid)
        self.send_error(404)

    # ---------- helpers ----------

    def _read_json_body(self, max_size=64 * 1024):
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length <= 0 or length > max_size:
            return None
        try:
            return json.loads(self.rfile.read(length).decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            return None

    def _send_json(self, status, payload):
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _token_from_headers(self):
        return (self.headers.get("X-Comment-Token", "") or "").strip()

    # ---------- handlers ----------

    def _get_comments(self, parsed):
        qs = parse_qs(parsed.query)
        slide = (qs.get("slide", [""])[0] or "").strip()
        rows = _read()
        if slide:
            rows = [r for r in rows if r.get("slide") == slide]
        rows.sort(key=lambda r: r.get("created_at", ""))
        self._send_json(200, [_public(r) for r in rows])

    def _post_comment(self):
        payload = self._read_json_body()
        if payload is None:
            return self.send_error(400, "invalid json or oversized body")

        slide = (payload.get("slide") or "").strip()[:120]
        name = (payload.get("name") or "").strip()[:60]
        text = (payload.get("text") or "").strip()[:4000]
        if not slide or not text:
            return self.send_error(400, "missing slide or text")

        row = {
            "id": uuid.uuid4().hex[:10],
            "slide": slide,
            "name": name or "Anonymous",
            "text": text,
            "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "token": uuid.uuid4().hex,  # the secret — only sent back to the poster, never in GET
        }
        with LOCK:
            rows = _read()
            rows.append(row)
            _write(rows)

        # Send token back so the client can store it for future edit/delete.
        self._send_json(201, row)

    def _update_comment(self, cid):
        token = self._token_from_headers()
        if not token:
            return self.send_error(401, "missing token")
        payload = self._read_json_body()
        if payload is None:
            return self.send_error(400, "invalid json")
        new_text = (payload.get("text") or "").strip()[:4000]
        if not new_text:
            return self.send_error(400, "missing text")

        with LOCK:
            rows = _read()
            row = next((r for r in rows if r.get("id") == cid), None)
            if not row:
                return self.send_error(404, "comment not found")
            if row.get("token") != token:
                return self.send_error(403, "invalid token")
            row["text"] = new_text
            row["edited_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
            _write(rows)

        self._send_json(200, _public(row))

    def _delete_comment(self, cid):
        token = self._token_from_headers()
        if not token:
            return self.send_error(401, "missing token")

        with LOCK:
            rows = _read()
            row = next((r for r in rows if r.get("id") == cid), None)
            if not row:
                return self.send_error(404, "comment not found")
            if row.get("token") != token:
                return self.send_error(403, "invalid token")
            rows = [r for r in rows if r.get("id") != cid]
            _write(rows)

        self.send_response(204)
        self.end_headers()


def main():
    port = 8765
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            sys.exit(f"invalid port: {sys.argv[1]}")
    srv = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"Serving {HERE} on http://0.0.0.0:{port} (Ctrl+C to stop)")
    print(f"Comments stored in: {COMMENTS_FILE}")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\nshutting down")
        srv.server_close()


if __name__ == "__main__":
    main()
