import unittest
from kraken_guardian.strategy import score_market


class StrategyTests(unittest.TestCase):
    def test_scores_trending_market(self):
        candles = [[i, "1", "1", "1", str(100 + i * 0.35), "1", "100"] for i in range(80)]
        ticker = {"c": ["128", "1"], "o": "123", "v": ["100", "1000"]}
        signal = score_market("XBTUSD", "BTC/USD", ticker, candles)
        self.assertIsNotNone(signal)
        self.assertGreater(signal.score, 50)
        self.assertEqual(signal.symbol, "BTC/USD")

    def test_rejects_insufficient_history(self):
        ticker = {"c": ["128", "1"], "o": "123", "v": ["100", "1000"]}
        self.assertIsNone(score_market("XBTUSD", "BTC/USD", ticker, [[1, 1, 1, 1, 1, 1, 1]]))


if __name__ == "__main__":
    unittest.main()
