"""Automated scanner and paper execution engine with risk circuit breakers."""
from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timezone
import threading
import time
from typing import Any

from .config import Settings
from .kraken import KrakenClient, KrakenError
from .storage import Store
from .strategy import Signal, score_market

STABLE_OR_FIAT = {"USD", "USDT", "USDC", "EUR", "GBP", "CAD", "JPY", "CHF", "AUD", "DAI", "PYUSD"}


@dataclass
class EngineState:
    status: str = "initialisation"
    last_scan: str = "—"
    next_scan: str = "—"
    error: str = ""
    scans: int = 0
    universe_size: int = 0


class TradingEngine:
    def __init__(self, settings: Settings, client: KrakenClient | None = None, store: Store | None = None):
        self.settings = settings
        self.client = client or KrakenClient(settings.api_key, settings.api_secret)
        self.store = store or Store(settings.db_path)
        self.state = EngineState()
        self.signals: list[Signal] = []
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop.clear()
        self._thread = threading.Thread(target=self._loop, name="guardian-engine", daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()

    def _loop(self) -> None:
        while not self._stop.is_set():
            self.scan_once()
            self._stop.wait(self.settings.scan_interval_seconds)

    def scan_once(self) -> list[Signal]:
        self.state.status = "analyse en cours"
        self.state.error = ""
        try:
            pair_map = self._discover_pairs()
            tickers = self.client.ticker(list(pair_map))
            ranked = sorted(pair_map, key=lambda pair: float(tickers.get(pair, {}).get("v", [0, 0])[1]), reverse=True)
            selected = ranked[: self.settings.max_pairs]
            signals: list[Signal] = []
            for pair in selected:
                try:
                    ticker = tickers.get(pair)
                    if not ticker:
                        continue
                    signal = score_market(pair, pair_map[pair], ticker, self.client.ohlc(pair))
                    if signal:
                        signals.append(signal)
                except (KrakenError, ValueError, KeyError):
                    continue
            self.signals = sorted(signals, key=lambda signal: signal.score, reverse=True)
            self._manage_paper_positions()
            self._open_paper_positions()
            self.state.status = "actif"
        except KrakenError as exc:
            self.state.status = "données indisponibles"
            self.state.error = str(exc)
        self.state.scans += 1
        self.state.last_scan = _now()
        self.state.next_scan = f"dans {self.settings.scan_interval_seconds // 60 or 1} min"
        return self.signals

    def _discover_pairs(self) -> dict[str, str]:
        pairs = self.client.asset_pairs()
        result: dict[str, str] = {}
        for pair_id, details in pairs.items():
            symbol = details.get("wsname") or details.get("altname", pair_id)
            if not symbol.endswith("/" + self.settings.quote_currency):
                continue
            base = symbol.split("/")[0]
            if base in STABLE_OR_FIAT or details.get("status", "online") != "online":
                continue
            result[pair_id] = symbol
        self.state.universe_size = len(result)
        return result

    def _manage_paper_positions(self) -> None:
        prices = {signal.pair: signal.price for signal in self.signals}
        for position in self.store.positions():
            price = prices.get(position["pair"])
            if not price:
                continue
            reason = ""
            if price <= position["stop"]:
                reason = "stop-loss"
            elif price >= position["target"]:
                reason = "take-profit"
            if reason:
                self.store.close_position(position["pair"], price, reason)

    def _open_paper_positions(self) -> None:
        if self.settings.live_enabled or self.risk_locked():
            return
        positions = self.store.positions()
        existing = {position["pair"] for position in positions}
        slots = self.settings.max_open_positions - len(existing)
        equity = self.equity()
        for signal in self.signals:
            if slots <= 0 or signal.score < self.settings.min_signal_score or signal.pair in existing:
                continue
            risk_budget = equity * self.settings.risk_per_trade
            max_notional = equity * self.settings.max_position_weight
            notional = min(max_notional, risk_budget / self.settings.stop_loss_pct)
            quantity = notional / signal.price
            self.store.open_position(signal.pair, signal.symbol, quantity, signal.price, signal.price * (1 - self.settings.stop_loss_pct), signal.price * (1 + self.settings.take_profit_pct))
            existing.add(signal.pair)
            slots -= 1

    def equity(self) -> float:
        unrealized = 0.0
        prices = {signal.pair: signal.price for signal in self.signals}
        for position in self.store.positions():
            unrealized += (prices.get(position["pair"], position["entry"]) - position["entry"]) * position["quantity"]
        return self.settings.paper_balance + self.store.realized_pnl() + unrealized

    def risk_locked(self) -> bool:
        return self.store.realized_pnl() <= -(self.settings.paper_balance * self.settings.max_daily_loss)

    def dashboard(self) -> dict[str, Any]:
        positions = self.store.positions()
        equity = self.equity()
        pnl = equity - self.settings.paper_balance
        return {
            "mode": self.settings.mode,
            "state": asdict(self.state),
            "metrics": {"equity": round(equity, 2), "pnl": round(pnl, 2), "pnl_pct": round(pnl / self.settings.paper_balance * 100, 2), "open_positions": len(positions), "risk_locked": self.risk_locked()},
            "risk": {"profile": "modéré", "risk_per_trade_pct": self.settings.risk_per_trade * 100, "max_daily_loss_pct": self.settings.max_daily_loss * 100, "stop_loss_pct": self.settings.stop_loss_pct * 100, "take_profit_pct": self.settings.take_profit_pct * 100, "max_positions": self.settings.max_open_positions},
            "signals": [signal.to_dict() for signal in self.signals[:20]],
            "positions": positions,
            "trades": self.store.trades(),
            "setup": {"api_configured": bool(self.settings.api_key and self.settings.api_secret), "live_requested": self.settings.live_requested, "live_enabled": self.settings.live_enabled},
        }


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")
