#!/bin/bash

# MSBI Quick Setup Script
# This script sets up the complete MSBI environment with data

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     MSBI Environment - Configuration et Insertion          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# SQL Server connection details
SQL_SERVER="localhost"
SQL_USER="sa"
SQL_PASSWORD="Passw0rd123!"

echo -e "${BLUE}Étape 1/5: Vérification de la connexion SQL Server...${NC}"
for i in {1..30}; do
    if sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -P "$SQL_PASSWORD" -Q "SELECT 1" -C &>/dev/null; then
        echo -e "${GREEN}✓ SQL Server est prêt!${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗ Timeout: SQL Server ne répond pas${NC}"
        echo "Essayez: docker restart mssql-dev"
        exit 1
    fi
    echo -n "."
    sleep 2
done
echo ""

echo -e "${BLUE}Étape 2/5: Vérification de la base SampleDW...${NC}"
DB_EXISTS=$(sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -P "$SQL_PASSWORD" -Q "SELECT name FROM sys.databases WHERE name = 'SampleDW'" -h -1 -C 2>/dev/null | tr -d '[:space:]')
if [ -z "$DB_EXISTS" ]; then
    echo -e "${YELLOW}Base SampleDW non trouvée, création...${NC}"
    sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -P "$SQL_PASSWORD" -d master -i init-sql-server.sql -C
    echo -e "${GREEN}✓ Base SampleDW créée!${NC}"
else
    echo -e "${GREEN}✓ Base SampleDW existe déjà${NC}"
fi
echo ""

echo -e "${BLUE}Étape 3/5: Création des tables...${NC}"
sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -P "$SQL_PASSWORD" -d SampleDW -i sql-scripts/create-tables.sql -C
echo -e "${GREEN}✓ Tables créées${NC}"
echo ""

echo -e "${BLUE}Étape 4/5: Insertion des données...${NC}"
sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -P "$SQL_PASSWORD" -d SampleDW -i sql-scripts/load-sample-data.sql -C
echo -e "${GREEN}✓ Données insérées${NC}"
echo ""

echo -e "${BLUE}Étape 5/5: Création des vues et procédures...${NC}"
sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -P "$SQL_PASSWORD" -d SampleDW -i sql-scripts/create-views.sql -C
sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -P "$SQL_PASSWORD" -d SampleDW -i sql-scripts/create-stored-procedures.sql -C
echo -e "${GREEN}✓ Vues et procédures créées${NC}"
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║                    Configuration Terminée! ✓               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo -e "${GREEN}Vérification finale:${NC}"
sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -P "$SQL_PASSWORD" -d SampleDW -Q "
SELECT 'Customers' AS TableName, COUNT(*) AS Records FROM dbo.Customers
UNION ALL
SELECT 'Products', COUNT(*) FROM dbo.Products
UNION ALL
SELECT 'Orders', COUNT(*) FROM dbo.Orders
" -C

echo ""
echo -e "${YELLOW}Commandes utiles:${NC}"
echo ""
echo "  # Voir les commandes"
echo "  sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -Q \"SELECT * FROM vw_OrderSummary\" -C"
echo ""
echo "  # Top clients"
echo "  sqlcmd -S localhost -U sa -P Passw0rd123! -d SampleDW -Q \"EXEC sp_GetTopCustomers @TopN = 5\" -C"
echo ""
echo "  # Utiliser PowerShell"
echo "  . ./manage-msbi.ps1"
echo ""
echo -e "${GREEN}Documentation complète: ${NC}CONFIGURATION.md"
echo ""
