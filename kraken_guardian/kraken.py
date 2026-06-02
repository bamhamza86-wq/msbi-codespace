"""Small dependency-free Kraken Spot REST client.

Official documentation: https://docs.kraken.com/api/docs/guides/spot-rest-intro/
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time
from typing import Any
from urllib.parse import urlencode
from urllib.request import Request, urlopen


class KrakenError(RuntimeError):
    """Raised when Kraken returns an API or transport error."""


class KrakenClient:
    base_url = "https://api.kraken.com/0"

    def __init__(self, api_key: str = "", api_secret: str = "", timeout: int = 12):
        self.api_key = api_key
        self.api_secret = api_secret
        self.timeout = timeout

    def _request(self, path: str, data: dict[str, Any] | None = None, private: bool = False) -> Any:
        payload = data or {}
        headers = {"User-Agent": "KrakenGuardian/1.0"}
        if private:
            if not self.api_key or not self.api_secret:
                raise KrakenError("Clé API Kraken et secret requis pour cet appel privé.")
            payload = {"nonce": str(time.time_ns()), **payload}
            encoded = urlencode(payload).encode()
            digest = hashlib.sha256((payload["nonce"] + urlencode(payload)).encode()).digest()
            signature = hmac.new(base64.b64decode(self.api_secret), ("/0" + path).encode() + digest, hashlib.sha512)
            headers.update({"API-Key": self.api_key, "API-Sign": base64.b64encode(signature.digest()).decode()})
        encoded = urlencode(payload).encode() if payload else None
        url = self.base_url + path
        if not private and encoded:
            url += "?" + encoded.decode()
            encoded = None
        request = Request(url, data=encoded, headers=headers, method="POST" if private else "GET")
        try:
            with urlopen(request, timeout=self.timeout) as response:
                body = json.loads(response.read())
        except Exception as exc:  # transport boundary
            raise KrakenError(f"Kraken indisponible: {exc}") from exc
        if body.get("error"):
            raise KrakenError("; ".join(body["error"]))
        return body.get("result", {})

    def asset_pairs(self) -> dict[str, Any]:
        return self._request("/public/AssetPairs")

    def ticker(self, pairs: list[str]) -> dict[str, Any]:
        return self._request("/public/Ticker", {"pair": ",".join(pairs)})

    def ohlc(self, pair: str, interval: int = 60) -> list[list[Any]]:
        result = self._request("/public/OHLC", {"pair": pair, "interval": interval})
        return next((value for key, value in result.items() if key != "last"), [])

    def balance(self) -> dict[str, str]:
        return self._request("/private/Balance", private=True)

    def open_orders(self) -> dict[str, Any]:
        return self._request("/private/OpenOrders", private=True)

    def add_order(self, pair: str, side: str, volume: str, price: str, validate: bool = True) -> dict[str, Any]:
        return self._request("/private/AddOrder", {"pair": pair, "type": side, "ordertype": "limit", "volume": volume, "price": price, "validate": str(validate).lower(), "oflags": "post"}, private=True)
