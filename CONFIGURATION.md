# Guide de Configuration et Insertion de Données MSBI

Ce guide vous accompagne dans la configuration complète de l'environnement MSBI et l'insertion des données de test.

## 📋 Table des Matières

1. [Prérequis](#prérequis)
2. [Configuration Initiale](#configuration-initiale)
3. [Insertion des Données](#insertion-des-données)
4. [Vérification](#vérification)
5. [Utilisation](#utilisation)

## Prérequis

L'environnement GitHub Codespaces est déjà configuré avec:
- ✅ SQL Server 2022
- ✅ Oracle Database (optionnel)
- ✅ Outils SQL (sqlcmd, PowerShell SqlServer module)
- ✅ Structure de répertoires

## Configuration Initiale

### Étape 1: Vérifier les Services

Après le démarrage du Codespace, vérifiez que les services sont actifs:

```bash
# Vérifier les conteneurs Docker
docker ps

# Tester la connexion SQL Server
sqlcmd -S localhost -U sa -P Passw0rd123! -Q "SELECT @@VERSION" -C
```

### Étape 2: Vérifier la Base de Données

```bash
# Lister les bases de données
sqlcmd -S localhost -U sa -P Passw0rd123! -Q "SELECT name FROM sys.databases" -C
```

Vous devriez voir:
- `master`
- `tempdb`
- `model`
- `msdb`
- `SampleDW` (créée par init-sql-server.sql)

## Insertion des Données

### Méthode 1: Script Complet (Recommandé)

Cette méthode exécute tous les scripts de configuration en une seule commande:

```bash
cd /workspaces/msbi-codespace

# Exécuter le script de configuration complète
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i sql-scripts/setup-complete.sql -C
```

Ce script:
1. ✅ Crée les tables (Customers, Products, Orders)
2. ✅ Insère les données d'exemple
3. ✅ Crée les vues analytiques
4. ✅ Crée les procédures stockées

### Méthode 2: Scripts Individuels

Si vous préférez exécuter les scripts séparément:

```bash
# 1. Créer les tables
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i sql-scripts/create-tables.sql -C

# 2. Charger les données
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i sql-scripts/load-sample-data.sql -C

# 3. Créer les vues
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i sql-scripts/create-views.sql -C

# 4. Créer les procédures stockées
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i sql-scripts/create-stored-procedures.sql -C
```

### Méthode 3: PowerShell

Utilisation de PowerShell pour plus de contrôle:

```powershell
# Charger l'outil de gestion
. ./manage-msbi.ps1

# Tester la connexion
Test-SqlConnection

# Exécuter le setup complet
Import-Module SqlServer
Invoke-Sqlcmd -ServerInstance "localhost" `
              -Database "SampleDW" `
              -InputFile "sql-scripts/setup-complete.sql" `
              -Username "sa" `
              -Password "Passw0rd123!" `
              -TrustServerCertificate

# Lister les bases
Get-Databases
```

## Vérification

### Vérifier les Tables

```sql
-- Via sqlcmd
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -Q "
SELECT 
    'Customers' AS TableName, COUNT(*) AS RecordCount 
FROM dbo.Customers
UNION ALL
SELECT 'Products', COUNT(*) FROM dbo.Products
UNION ALL
SELECT 'Orders', COUNT(*) FROM dbo.Orders
" -C
```

Résultats attendus:
- Customers: 10 enregistrements
- Products: 10 enregistrements
- Orders: 10 enregistrements

### Vérifier les Vues

```sql
-- Afficher un résumé des commandes
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -Q "
SELECT TOP 5 * FROM dbo.vw_OrderSummary ORDER BY OrderDate DESC
" -C
```

### Vérifier les Procédures Stockées

```sql
-- Tester la procédure Top Customers
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -Q "
EXEC dbo.sp_GetTopCustomers @TopN = 5
" -C
```

## Utilisation

### Requêtes d'Exemple

#### 1. Vue d'ensemble des commandes

```sql
SELECT * FROM dbo.vw_OrderSummary
ORDER BY OrderDate DESC;
```

#### 2. Top clients par dépenses

```sql
SELECT * FROM dbo.vw_CustomerOrders
ORDER BY TotalSpent DESC;
```

#### 3. Performance des produits

```sql
SELECT * FROM dbo.vw_ProductSales
ORDER BY TotalRevenue DESC;
```

#### 4. Ventes par période

```sql
EXEC dbo.sp_GetSalesByDateRange 
    @StartDate = '2024-01-01', 
    @EndDate = '2024-02-28';
```

### Données Disponibles

#### Fichiers CSV Source

Les données sources sont dans `/data/`:
- `customers.csv` - 10 clients français
- `products.csv` - 10 produits électroniques
- `orders.csv` - 10 commandes

#### Structure de la Base

```
SampleDW
├── dbo
│   ├── Customers (10 enregistrements)
│   ├── Products (10 enregistrements)
│   ├── Orders (10 enregistrements)
│   ├── vw_OrderSummary
│   ├── vw_CustomerOrders
│   ├── vw_ProductSales
│   ├── sp_RefreshStagingData
│   ├── sp_GetSalesByDateRange
│   └── sp_GetTopCustomers
└── ETL
    └── StagingCustomer
```

## Opérations Avancées

### Réinitialiser les Données

Pour réinitialiser complètement la base:

```bash
# Supprimer et recréer
sqlcmd -S localhost -U sa -P Passw0rd123! -Q "
DROP DATABASE IF EXISTS SampleDW;
CREATE DATABASE SampleDW;
" -C

# Recréer la structure ETL
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i init-sql-server.sql -C

# Recharger tout
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i sql-scripts/setup-complete.sql -C
```

### Ajouter des Données Personnalisées

```sql
-- Ajouter un nouveau client
INSERT INTO dbo.Customers (CustomerID, FirstName, LastName, Email, Phone, City, Country, RegistrationDate)
VALUES (11, 'Nouveau', 'Client', 'nouveau.client@example.fr', '+33999999999', 'Paris', 'France', GETDATE());

-- Ajouter un nouveau produit
INSERT INTO dbo.Products (ProductID, ProductName, Category, Price, Stock, SupplierID)
VALUES (111, 'Nouveau Produit', 'Electronics', 499.99, 100, 1001);

-- Créer une nouvelle commande
INSERT INTO dbo.Orders (OrderID, CustomerID, ProductID, Quantity, OrderDate, TotalAmount, Status)
VALUES (1011, 11, 111, 1, GETDATE(), 499.99, 'Processing');
```

### Exporter des Données

```bash
# Exporter les résultats vers un fichier
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -Q "SELECT * FROM dbo.vw_OrderSummary" -C -o /tmp/orders_export.txt

# Exporter en CSV (avec séparateurs)
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -Q "SELECT * FROM dbo.Customers" -C -s "," -o /tmp/customers_export.csv -W
```

## Dépannage

### Problème: Connexion refusée

```bash
# Vérifier que SQL Server est démarré
docker ps | grep mssql

# Redémarrer si nécessaire
docker restart mssql-dev

# Attendre 30 secondes puis réessayer
sleep 30
sqlcmd -S localhost -U sa -P Passw0rd123! -Q "SELECT 1" -C
```

### Problème: Base SampleDW n'existe pas

```bash
# Créer la base et exécuter le script d'init
sqlcmd -S localhost -U sa -P Passw0rd123! -Q "CREATE DATABASE SampleDW" -C
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i init-sql-server.sql -C
```

### Problème: Erreurs de script

```bash
# Exécuter avec plus de verbosité
sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -i sql-scripts/setup-complete.sql -C -v
```

## Prochaines Étapes

1. ✅ Configuration complète ✓
2. ✅ Données insérées ✓
3. 📊 Développer des packages SSIS dans `/ssis-packages/`
4. 🔍 Créer des rapports avec Power BI
5. 🚀 Développer des pipelines ETL personnalisés

## Ressources

- [README Principal](README.md)
- [Scripts SQL](sql-scripts/README.md)
- [Packages SSIS](ssis-packages/README.md)
- [Données d'Exemple](data/README.md)

---

**Configuration terminée! 🎉**

Votre environnement MSBI est maintenant prêt pour le développement ETL et l'analyse de données.
