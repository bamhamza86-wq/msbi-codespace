import tempfile
import unittest
from dataclasses import replace

from kraken_guardian.config import Settings
from kraken_guardian.engine import TradingEngine
from kraken_guardian.storage import Store


class FakeKraken:
    def asset_pairs(self):
        return {"XBTUSD": {"wsname": "BTC/USD", "status": "online"}, "USDTUSD": {"wsname": "USDT/USD", "status": "online"}, "XBTEUR": {"wsname": "BTC/EUR", "status": "online"}}

    def ticker(self, pairs):
        return {"XBTUSD": {"c": ["130", "1"], "o": "120", "v": ["500", "5000"]}}

    def ohlc(self, pair, interval=60):
        return [[i, "1", "1", "1", str(100 + i * .4), "1", "100"] for i in range(80)]


class EngineTests(unittest.TestCase):
    def test_discovers_filters_scores_and_opens_paper_position(self):
        with tempfile.TemporaryDirectory() as tmp:
            settings = replace(Settings(), db_path=f"{tmp}/test.db", min_signal_score=60)
            engine = TradingEngine(settings, client=FakeKraken(), store=Store(settings.db_path))
            signals = engine.scan_once()
            self.assertEqual(engine.state.universe_size, 1)
            self.assertEqual(len(signals), 1)
            self.assertEqual(len(engine.store.positions()), 1)
            dashboard = engine.dashboard()
            self.assertEqual(dashboard["mode"], "paper")
            self.assertFalse(dashboard["metrics"]["risk_locked"])

    def test_live_mode_requires_explicit_confirmation_and_credentials(self):
        base = Settings()
        self.assertFalse(replace(base, live_requested=True).live_enabled)
        configured = replace(base, api_key="key", api_secret="secret", live_requested=True, live_confirmation="I_ACCEPT_LIVE_TRADING_RISK")
        self.assertTrue(configured.live_enabled)


if __name__ == "__main__":
    unittest.main()
