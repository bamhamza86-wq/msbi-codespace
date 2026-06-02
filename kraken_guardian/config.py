"""Application configuration loaded from environment variables only."""
from __future__ import annotations

from dataclasses import dataclass
import os


def _bool(name: str, default: bool = False) -> bool:
    return os.getenv(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


def _float(name: str, default: float) -> float:
    try:
        return float(os.getenv(name, default))
    except ValueError:
        return default


def _int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, default))
    except ValueError:
        return default


@dataclass(frozen=True)
class Settings:
    api_key: str = os.getenv("KRAKEN_API_KEY", "")
    api_secret: str = os.getenv("KRAKEN_API_SECRET", "")
    quote_currency: str = os.getenv("GUARDIAN_QUOTE", "USD").upper()
    paper_balance: float = _float("GUARDIAN_PAPER_BALANCE", 10_000.0)
    scan_interval_seconds: int = max(30, _int("GUARDIAN_SCAN_INTERVAL", 300))
    max_pairs: int = max(5, _int("GUARDIAN_MAX_PAIRS", 35))
    max_open_positions: int = max(1, _int("GUARDIAN_MAX_POSITIONS", 5))
    risk_per_trade: float = min(0.02, max(0.001, _float("GUARDIAN_RISK_PER_TRADE", 0.0075)))
    max_daily_loss: float = min(0.10, max(0.005, _float("GUARDIAN_MAX_DAILY_LOSS", 0.025)))
    max_position_weight: float = min(0.25, max(0.01, _float("GUARDIAN_MAX_POSITION_WEIGHT", 0.12)))
    stop_loss_pct: float = min(0.15, max(0.005, _float("GUARDIAN_STOP_LOSS", 0.025)))
    take_profit_pct: float = min(0.50, max(0.01, _float("GUARDIAN_TAKE_PROFIT", 0.055)))
    min_signal_score: float = min(95.0, max(50.0, _float("GUARDIAN_MIN_SIGNAL", 68.0)))
    db_path: str = os.getenv("GUARDIAN_DB_PATH", "guardian.db")
    live_requested: bool = _bool("GUARDIAN_ENABLE_LIVE", False)
    live_confirmation: str = os.getenv("GUARDIAN_LIVE_CONFIRMATION", "")

    @property
    def live_enabled(self) -> bool:
        return bool(self.api_key and self.api_secret and self.live_requested and self.live_confirmation == "I_ACCEPT_LIVE_TRADING_RISK")

    @property
    def mode(self) -> str:
        # Live credentials unlock supervised validation, never silent autonomous execution.
        return "validation" if self.live_enabled else "paper"
