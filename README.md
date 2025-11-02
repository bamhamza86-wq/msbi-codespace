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

- [SQL Server on Linux](https://learn.microsoft.com/en-us/sql/linux/)
- [GitHub Codespaces Docs](https://docs.github.com/en/codespaces)
- [Docker Compose](https://docs.docker.com/compose/)

---

**Prêt à utiliser! 🚀**

Repository: https://github.com/bamhamza86-wq/msbi-codespace
