#!/bin/bash

# MSBI Setup Validation Script
# This script validates that all components are properly configured

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     MSBI Environment - Validation de la Configuration     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

ERRORS=0

# Function to check if file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1 (MANQUANT)"
        ERRORS=$((ERRORS + 1))
    fi
}

# Function to check if directory exists
check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1/"
    else
        echo -e "${RED}✗${NC} $1/ (MANQUANT)"
        ERRORS=$((ERRORS + 1))
    fi
}

echo -e "${BLUE}Vérification 1/5: Structure des répertoires${NC}"
check_dir ".devcontainer"
check_dir ".devcontainer/sql-init"
check_dir "sql-scripts"
check_dir "ssis-packages"
check_dir "data"
echo ""

echo -e "${BLUE}Vérification 2/5: Fichiers de configuration${NC}"
check_file ".devcontainer/devcontainer.json"
check_file ".devcontainer/docker-compose.yml"
check_file ".devcontainer/setup.sh"
check_file ".devcontainer/sql-init/init-sql-server.sql"
check_file ".gitignore"
echo ""

echo -e "${BLUE}Vérification 3/5: Scripts SQL${NC}"
check_file "sql-scripts/create-tables.sql"
check_file "sql-scripts/load-sample-data.sql"
check_file "sql-scripts/create-views.sql"
check_file "sql-scripts/create-stored-procedures.sql"
check_file "sql-scripts/setup-complete.sql"
check_file "sql-scripts/README.md"
echo ""

echo -e "${BLUE}Vérification 4/5: Fichiers de données${NC}"
check_file "data/customers.csv"
check_file "data/products.csv"
check_file "data/orders.csv"
check_file "data/README.md"
echo ""

echo -e "${BLUE}Vérification 5/5: Documentation et outils${NC}"
check_file "README.md"
check_file "CONFIGURATION.md"
check_file "quick-setup.sh"
check_file "manage-msbi.ps1"
check_file "ssis-packages/README.md"
echo ""

# Check executability
echo -e "${BLUE}Vérification des permissions d'exécution${NC}"
if [ -x "quick-setup.sh" ]; then
    echo -e "${GREEN}✓${NC} quick-setup.sh (exécutable)"
else
    echo -e "${YELLOW}⚠${NC} quick-setup.sh (non exécutable, correction...)"
    chmod +x quick-setup.sh
fi

if [ -x ".devcontainer/setup.sh" ]; then
    echo -e "${GREEN}✓${NC} .devcontainer/setup.sh (exécutable)"
else
    echo -e "${YELLOW}⚠${NC} .devcontainer/setup.sh (non exécutable, correction...)"
    chmod +x .devcontainer/setup.sh
fi
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
if [ $ERRORS -eq 0 ]; then
    echo -e "║  ${GREEN}✓ Validation Réussie - Tous les composants présents${NC}  ║"
else
    echo -e "║  ${RED}✗ Validation Échouée - $ERRORS erreur(s) trouvée(s)${NC}     ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}Votre environnement MSBI est correctement configuré!${NC}"
    echo ""
    echo -e "${YELLOW}Prochaines étapes:${NC}"
    echo "  1. Démarrer Codespace (si pas déjà fait)"
    echo "  2. Attendre que les conteneurs démarrent (docker ps)"
    echo "  3. Exécuter: ./quick-setup.sh"
    echo "  4. Consulter: CONFIGURATION.md pour plus de détails"
    echo ""
else
    echo -e "${RED}Certains fichiers sont manquants. Vérifiez votre repository.${NC}"
    exit 1
fi
