# Kraken Guardian

Tableau de bord autonome de veille crypto pour Kraken Pro. L'application détecte automatiquement les marchés Spot en USD, analyse les actifs liquides, attribue un score multifactoriel explicable et simule une allocation prudente en continu. Elle remplace l'ancien environnement de démonstration MSBI à la racine du dépôt.

> **Important :** aucun algorithme ne garantit des gains journaliers. Kraken Guardian est fourni comme outil d'analyse et de simulation. Le mode paper est activé par défaut. Faites valider toute stratégie, effectuez des backtests et consultez un professionnel qualifié avant d'exposer du capital réel.

## Ce que l'application automatise

- découverte des paires Spot Kraken négociables via l'API publique `AssetPairs` ;
- classement des marchés USD par volume ;
- récupération de l'OHLC et des tickers publics ;
- scoring tendance, momentum, RSI et volatilité ;
- simulation d'entrées avec dimensionnement selon le budget de risque ;
- stop-loss, take-profit, nombre maximum de positions et circuit breaker de perte ;
- stockage local SQLite des positions et transactions simulées ;
- dashboard web rafraîchi automatiquement et analyse manuelle à la demande.

## Informations minimales à fournir

### Pour commencer immédiatement en simulation

**Aucune information personnelle et aucune clé API.** Les données publiques Kraken sont récupérées automatiquement.

### Pour connecter un compte Kraken Pro

Créez une clé API dédiée et fournissez uniquement ces deux variables d'environnement :

```bash
KRAKEN_API_KEY=...
KRAKEN_API_SECRET=...
```

N'accordez **jamais** la permission de retrait. Pour une future connexion privée de lecture seule, limitez la clé à la consultation des fonds et à la consultation des ordres et transactions ouverts/fermés. L'application actuelle ne transmet aucun ordre réel : le double verrou débloque uniquement un état de validation supervisée, mais l'exécution reste volontairement en simulation tant qu'un workflow de validation, de backtest et de déploiement supervisé n'a pas été accepté.

## Démarrage

Python 3.11+ suffit ; aucune dépendance externe n'est requise.

```bash
cp .env.example .env
set -a && source .env && set +a
python -m kraken_guardian.server --port 8080
```

Ouvrez ensuite <http://localhost:8080>.

## Tests

```bash
python -m unittest discover -s tests -v
```

## Architecture

| Module | Rôle |
|---|---|
| `kraken_guardian/kraken.py` | Client REST Kraken public et privé, signature HMAC comprise |
| `kraken_guardian/strategy.py` | Indicateurs et score multifactoriel explicable |
| `kraken_guardian/engine.py` | Scanner automatique, dimensionnement et garde-fous |
| `kraken_guardian/storage.py` | Persistance SQLite |
| `kraken_guardian/server.py` | Serveur HTTP et API JSON sans dépendance |
| `kraken_guardian/static/` | Dashboard responsive |

## Références Kraken officielles

- [Introduction Spot REST](https://docs.kraken.com/api/docs/guides/spot-rest-intro/)
- [Paires négociables](https://docs.kraken.com/api/docs/rest-api/get-tradable-asset-pairs/)
- [Ticker](https://docs.kraken.com/api/docs/rest-api/get-ticker-information/)
- [OHLC](https://docs.kraken.com/api/docs/rest-api/get-ohlc-data/)
- [Ajouter un ordre](https://docs.kraken.com/api/docs/rest-api/add-order/)
