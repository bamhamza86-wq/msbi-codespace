# MSBI Environment - GitHub Codespaces Setup

Environnement complet **SQL Server 2022** + **SSIS** + **Oracle** pour GitHub Codespaces.

## 🚀 Démarrage Rapide

### Configuration Complète en Une Commande

```bash
# Setup automatique complet (recommandé)
./quick-setup.sh
```

Ce script configure automatiquement:
- ✅ Base de données SampleDW
- ✅ Tables (Customers, Products, Orders)
- ✅ Données d'exemple (10 clients, 10 produits, 10 commandes)
- ✅ Vues analytiques
- ✅ Procédures stockées

📖 **Guide détaillé:** [CONFIGURATION.md](CONFIGURATION.md)

### Services Disponibles

| Service | Host | Port | User | Password |
|---------|------|------|------|----------|
| **SQL Server 2022** | localhost | 1433 | sa | Passw0rd123! |
| **Oracle Database** | localhost | 1521 | system | Oracle_123 |
| **SSIS Runtime** | CLI | - | - | - |

### Vérifier les Services

```bash
# Vérifier les conteneurs
docker ps

# Tester SQL Server
sqlcmd -S localhost -U sa -P Passw0rd123! -Q "SELECT @@VERSION" -C

# Lister les bases de données
sqlcmd -S localhost -U sa -P Passw0rd123! -Q "SELECT name FROM sys.databases" -C

# Vérifier les données
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -Q "SELECT * FROM vw_OrderSummary" -C
```

## 📁 Structure du Projet

```
.
├── .devcontainer/
│   ├── devcontainer.json      # Configuration Codespace
│   ├── docker-compose.yml     # Services Docker
│   ├── setup.sh               # Script d'initialisation
│   └── sql-init/              # Scripts SQL d'initialisation
│       └── init-sql-server.sql
├── ssis-packages/             # Packages SSIS (.dtsx)
│   └── README.md              # Guide SSIS
├── sql-scripts/               # Scripts SQL réutilisables
│   ├── create-tables.sql      # Création des tables
│   ├── load-sample-data.sql   # Insertion des données
│   ├── create-views.sql       # Vues analytiques
│   ├── create-stored-procedures.sql
│   ├── setup-complete.sql     # Setup complet
│   └── README.md
├── data/                      # Données de test (CSV)
│   ├── customers.csv          # 10 clients
│   ├── products.csv           # 10 produits
│   ├── orders.csv             # 10 commandes
│   └── README.md
├── quick-setup.sh             # 🚀 Setup automatique
├── CONFIGURATION.md           # 📖 Guide complet
└── README.md
```

## 🛠️ Commandes Utiles

### SQL Server

```bash
# Exécuter une requête
sqlcmd -S localhost -U sa -P Passw0rd123! -Q "SELECT @@VERSION" -C

# Créer une base de données
sqlcmd -S localhost -U sa -P Passw0rd123! -Q "CREATE DATABASE TestDB" -C

# Exécuter un script SQL
sqlcmd -S localhost -U sa -P Passw0rd123! -i script.sql -C
```

### PowerShell & SQL Server

```powershell
# Importer le module SqlServer
Import-Module SqlServer

# Se connecter
$serverInstance = "localhost"
$database = "master"

# Exécuter une requête
Invoke-Sqlcmd -ServerInstance $serverInstance -Database $database -Query "SELECT @@VERSION"
```

## 🔌 Intégration SQL Server ↔ Oracle

### Via Linked Server (T-SQL)

```sql
-- Créer un linked server vers Oracle
EXEC sp_addlinkedserver 
    @server = 'ORACLE_LINK',
    @srvproduct = 'Oracle',
    @provider = 'OraOLEDB.Oracle',
    @datasrc = 'localhost:1521/FREEPDB1';

-- Tester
SELECT * FROM OPENQUERY(ORACLE_LINK, 'SELECT * FROM dual');
```

## 📊 Données d'Exemple Incluses

L'environnement est livré avec des données de démonstration prêtes à l'emploi:

### Base de Données: SampleDW

**Tables:**
- `Customers` - 10 clients français avec coordonnées
- `Products` - 10 produits électroniques avec prix et stock
- `Orders` - 10 commandes avec historique

**Vues Analytiques:**
- `vw_OrderSummary` - Vue complète des commandes avec clients et produits
- `vw_CustomerOrders` - Statistiques par client
- `vw_ProductSales` - Performance des ventes par produit

**Procédures Stockées:**
- `sp_RefreshStagingData` - Rafraîchissement des données de staging
- `sp_GetSalesByDateRange` - Rapport de ventes par période
- `sp_GetTopCustomers` - Top N clients par dépenses

### Exemples de Requêtes

```sql
-- Vue d'ensemble des commandes
SELECT * FROM dbo.vw_OrderSummary ORDER BY OrderDate DESC;

-- Top 5 clients
EXEC dbo.sp_GetTopCustomers @TopN = 5;

-- Ventes de janvier 2024
EXEC dbo.sp_GetSalesByDateRange 
    @StartDate = '2024-01-01', 
    @EndDate = '2024-01-31';
```

## ⚠️ Notes Importantes

### SSAS Non Disponible
SQL Server Analysis Services (SSAS) n'est pas disponible sur Linux/Codespaces.

**Alternatives :**
- Power BI Desktop (connexion à SQL Server)
- Azure Analysis Services
- Alternatives open-source (ClickHouse, Apache Kylin)

### Performance
- Codespaces est optimisé pour le développement
- Pour du traitement ETL lourd, considérez une VM Azure
- Oracle peut prendre 2-5 minutes au premier démarrage

### Sécurité
⚠️ Les mots de passe par défaut sont pour le développement uniquement.
En production, utilisez des mots de passe forts et des variables d'environnement.

## 🐛 Dépannage

### SQL Server ne démarre pas
```bash
docker logs mssql-dev
docker restart mssql-dev
```

### Oracle lent au démarrage
```bash
# Normal, patientez 2-5 minutes
docker logs oracle-dev
```

### Permission denied
```bash
chmod +x .devcontainer/setup.sh
```

## 📚 Ressources

### Documentation Interne
- [📖 CONFIGURATION.md](CONFIGURATION.md) - Guide complet de configuration et insertion de données
- [💾 sql-scripts/README.md](sql-scripts/README.md) - Documentation des scripts SQL
- [📦 ssis-packages/README.md](ssis-packages/README.md) - Guide SSIS et ETL
- [📊 data/README.md](data/README.md) - Description des données d'exemple

### Documentation Externe
- [SQL Server on Linux](https://learn.microsoft.com/en-us/sql/linux/)
- [SSIS Documentation](https://learn.microsoft.com/en-us/sql/integration-services/)
- [GitHub Codespaces Docs](https://docs.github.com/en/codespaces)
- [Docker Compose](https://docs.docker.com/compose/)

---

## ✅ Résumé des Fonctionnalités

✓ **Environnement complet prêt à l'emploi**
- SQL Server 2022 Developer Edition
- Oracle Database Free Edition
- Outils de gestion (sqlcmd, PowerShell, SSIS runtime)

✓ **Données de démonstration incluses**
- Base de données SampleDW avec 3 tables
- 30 enregistrements de test (10 clients, 10 produits, 10 commandes)
- 3 vues analytiques prêtes à l'emploi
- 3 procédures stockées pour ETL

✓ **Configuration automatisée**
- Script `quick-setup.sh` pour configuration en une commande
- Scripts SQL modulaires et réutilisables
- Documentation complète en français

✓ **Prêt pour le développement MSBI**
- Structure de projet ETL
- Répertoires pour packages SSIS
- Exemples de données CSV
- Outils de gestion PowerShell

---

**Prêt à utiliser! 🚀**

Repository: https://github.com/bamhamza86-wq/msbi-codespace
