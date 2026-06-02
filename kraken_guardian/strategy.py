"""Explainable multi-factor market scoring. No strategy can guarantee returns."""
from __future__ import annotations

from dataclasses import asdict, dataclass
from math import sqrt
from statistics import mean, pstdev
from typing import Any


@dataclass
class Signal:
    pair: str
    symbol: str
    price: float
    change_24h: float
    volume_24h: float
    rsi: float
    volatility: float
    trend: float
    score: float
    action: str
    rationale: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _sma(values: list[float], window: int) -> float:
    values = values[-window:]
    return mean(values) if values else 0.0


def _rsi(closes: list[float], window: int = 14) -> float:
    deltas = [current - previous for previous, current in zip(closes, closes[1:])][-window:]
    if not deltas:
        return 50.0
    gains = mean([max(delta, 0.0) for delta in deltas])
    losses = mean([max(-delta, 0.0) for delta in deltas])
    return 100.0 if losses == 0 else 100 - (100 / (1 + gains / losses))


def score_market(pair: str, symbol: str, ticker: dict[str, Any], candles: list[list[Any]]) -> Signal | None:
    closes = [float(candle[4]) for candle in candles[-72:] if len(candle) > 6]
    if len(closes) < 24:
        return None
    price = float(ticker["c"][0])
    open_price = float(ticker["o"])
    volume = float(ticker["v"][1])
    returns = [(current / previous) - 1 for previous, current in zip(closes, closes[1:]) if previous]
    volatility = pstdev(returns) * sqrt(24) * 100 if len(returns) > 1 else 0.0
    rsi = _rsi(closes)
    sma_fast, sma_slow = _sma(closes, 8), _sma(closes, 24)
    trend = ((sma_fast / sma_slow) - 1) * 100 if sma_slow else 0.0
    change = ((price / open_price) - 1) * 100 if open_price else 0.0
    trend_points = max(-15, min(22, trend * 8))
    momentum_points = max(-12, min(15, change * 2))
    rsi_points = 15 if 44 <= rsi <= 62 else (7 if 35 <= rsi < 70 else -10)
    vol_points = 12 if 0.5 <= volatility <= 5 else (4 if volatility < 8 else -14)
    score = max(0.0, min(100.0, 50 + trend_points + momentum_points + rsi_points + vol_points))
    action = "ACHETER" if score >= 68 else ("SURVEILLER" if score >= 55 else "ÉVITER")
    rationale = f"Tendance {trend:+.2f}% · RSI {rsi:.0f} · volatilité {volatility:.1f}% · variation 24 h {change:+.2f}%"
    return Signal(pair, symbol, price, change, volume, rsi, volatility, trend, round(score, 1), action, rationale)
