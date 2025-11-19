#!/bin/bash

set -e

echo "================================"
echo "MSBI Environment Setup Starting"
echo "================================"

# Update package manager
sudo apt-get update -y

echo "📦 Installing SQL Server tools..."
curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc > /dev/null
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list

sudo apt-get update -y
sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev

# Setup PATH
echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc
export PATH="$PATH:/opt/mssql-tools18/bin"

# Install PowerShell modules
echo "📚 Installing PowerShell modules..."
pwsh -Command "Install-Module -Name SqlServer -Force -Scope CurrentUser -AllowClobber" || true

# Create sample directories
mkdir -p /workspaces/$(basename $PWD)/ssis-packages
mkdir -p /workspaces/$(basename $PWD)/sql-scripts
mkdir -p /workspaces/$(basename $PWD)/data

echo ""
echo "================================"
echo "✅ Setup Complete!"
echo "================================"
echo ""
echo "Available services:"
echo "  • SQL Server 2022:   localhost:1433 (sa / Passw0rd123!)"
echo "  • Oracle Database:   localhost:1521 (system / Oracle_123)"
echo ""
echo "Test connection:"
echo "  sqlcmd -S localhost -U sa -P Passw0rd123! -Q 'SELECT @@VERSION' -C"
echo ""
