"""Dependency-free JSON API and static dashboard server."""
from __future__ import annotations

import argparse
import json
import mimetypes
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from .config import Settings
from .engine import TradingEngine

STATIC_DIR = Path(__file__).parent / "static"


class DashboardHandler(BaseHTTPRequestHandler):
    engine: TradingEngine

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/api/dashboard":
            return self._json(self.engine.dashboard())
        if self.path == "/api/health":
            return self._json({"ok": True, "status": self.engine.state.status})
        path = "index.html" if self.path in {"/", ""} else self.path.lstrip("/")
        target = (STATIC_DIR / path).resolve()
        if STATIC_DIR.resolve() not in target.parents and target != STATIC_DIR.resolve():
            return self.send_error(403)
        if not target.is_file():
            return self.send_error(404)
        body = target.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", mimetypes.guess_type(target.name)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:  # noqa: N802
        if self.path != "/api/scan":
            return self.send_error(404)
        self.engine.scan_once()
        self._json(self.engine.dashboard())

    def _json(self, payload: object) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format: str, *args: object) -> None:
        return


def create_server(host: str = "0.0.0.0", port: int = 8080, engine: TradingEngine | None = None) -> ThreadingHTTPServer:
    DashboardHandler.engine = engine or TradingEngine(Settings())
    DashboardHandler.engine.start()
    return ThreadingHTTPServer((host, port), DashboardHandler)


def main() -> None:
    parser = argparse.ArgumentParser(description="Kraken Guardian dashboard")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()
    server = create_server(args.host, args.port)
    print(f"Kraken Guardian disponible sur http://{args.host}:{args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        DashboardHandler.engine.stop()


if __name__ == "__main__":
    main()
