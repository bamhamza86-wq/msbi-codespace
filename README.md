# MSBI Environment - GitHub Codespaces Setup

Environnement complet **SQL Server 2022** + **SSIS** + **Oracle** pour GitHub Codespaces.

## 🚀 Démarrage Rapide

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
```

## 📁 Structure du Projet

```
.
├── .devcontainer/
│   ├── devcontainer.json      # Configuration Codespace
│   ├── docker-compose.yml     # Services Docker
│   └── setup.sh               # Script d'initialisation
├── sql-init/
│   └── init-sql-server.sql    # Scripts SQL d'initialisation
├── ssis-packages/             # Vos packages SSIS (.dtsx)
├── sql-scripts/               # Scripts SQL réutilisables
├── data/                      # Données de test
└── README.md
```

### Scripts SQL

- `sql-scripts/advanced-index-optimizer-v3.sql`  
  Analyse avancee des indexes, A/B test, Query Store, et recommandations CCI/NCCI.

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
