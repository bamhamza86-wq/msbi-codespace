"""SQLite persistence for positions, trades and equity snapshots."""
from __future__ import annotations

import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


class Store:
    def __init__(self, path: str):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        self.path = path
        with self.connect() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS positions(pair TEXT PRIMARY KEY, symbol TEXT, quantity REAL, entry REAL, stop REAL, target REAL, opened_at TEXT);
                CREATE TABLE IF NOT EXISTS trades(id INTEGER PRIMARY KEY AUTOINCREMENT, pair TEXT, symbol TEXT, side TEXT, quantity REAL, price REAL, pnl REAL DEFAULT 0, reason TEXT, created_at TEXT);
                CREATE TABLE IF NOT EXISTS equity(id INTEGER PRIMARY KEY AUTOINCREMENT, value REAL, created_at TEXT);
            """)

    def connect(self) -> sqlite3.Connection:
        db = sqlite3.connect(self.path)
        db.row_factory = sqlite3.Row
        return db

    def positions(self) -> list[dict[str, Any]]:
        with self.connect() as db:
            return [dict(row) for row in db.execute("SELECT * FROM positions ORDER BY opened_at DESC")]

    def trades(self, limit: int = 20) -> list[dict[str, Any]]:
        with self.connect() as db:
            return [dict(row) for row in db.execute("SELECT * FROM trades ORDER BY id DESC LIMIT ?", (limit,))]

    def open_position(self, pair: str, symbol: str, quantity: float, entry: float, stop: float, target: float) -> None:
        now = _now()
        with self.connect() as db:
            db.execute("INSERT OR REPLACE INTO positions VALUES (?, ?, ?, ?, ?, ?, ?)", (pair, symbol, quantity, entry, stop, target, now))
            db.execute("INSERT INTO trades(pair,symbol,side,quantity,price,reason,created_at) VALUES(?,?,?,?,?,?,?)", (pair, symbol, "BUY", quantity, entry, "signal multifactoriel", now))

    def close_position(self, pair: str, price: float, reason: str) -> float:
        with self.connect() as db:
            position = db.execute("SELECT * FROM positions WHERE pair=?", (pair,)).fetchone()
            if not position:
                return 0.0
            pnl = (price - position["entry"]) * position["quantity"]
            db.execute("DELETE FROM positions WHERE pair=?", (pair,))
            db.execute("INSERT INTO trades(pair,symbol,side,quantity,price,pnl,reason,created_at) VALUES(?,?,?,?,?,?,?,?)", (pair, position["symbol"], "SELL", position["quantity"], price, pnl, reason, _now()))
            return pnl

    def realized_pnl(self) -> float:
        with self.connect() as db:
            return float(db.execute("SELECT COALESCE(SUM(pnl),0) FROM trades").fetchone()[0])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")
