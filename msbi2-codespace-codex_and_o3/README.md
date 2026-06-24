# msbi2-codespace-codex_and_o3

Sous-projet MSBI hybride pour GitHub Codespaces / poste local.

Objectif couvert :

- monter une base `DW` sur SQL Server 2022 ;
- charger des tables en mode delta dans cette meme base via une orchestration compatible SSIS ;
- exposer un modele SSAS Tabular en schema en etoile ;
- fournir des rapports SSRS qui lisent les vues de reporting de `DW`.

> Note de support : SQL Server Database Engine est lance en conteneur Linux. SSIS,
> SSAS et SSRS restent des briques Microsoft a executer sur les hotes adaptes
> (SSIS/SSAS/SSRS Windows, ou SSIS Linux natif selon vos contraintes). Le
> Codespace valide la logique SQL et les artefacts ; les scripts Windows
> deployent les briques BI sur une machine disposant des outils Microsoft.

## Demarrage rapide SQL + delta load

```bash
cd msbi2-codespace-codex_and_o3
cp .env.example .env
./scripts/smoke-test.sh
```

Le smoke test :

1. demarre SQL Server 2022 avec Docker Compose ;
2. cree la base `DW`, les schemas `source`, `stg`, `dw`, `etl`, `rpt` ;
3. insere un premier lot source ;
4. execute le chargement delta initial ;
5. insere un second lot avec nouvelles lignes et mises a jour ;
6. execute le chargement delta suivant ;
7. verifie les dimensions, la table de faits, les watermarks et les vues de reporting.

## Architecture

```mermaid
flowchart LR
    SRC["Tables source delta\nsource.*Changes"] --> STG["Staging\nstg.*Delta"]
    STG --> ETL["SSIS orchestration\nExecute SQL Task / dtexec"]
    ETL --> DW["SQL Server DW\nschema en etoile"]
    DW --> SSAS["SSAS Tabular\nmodel.bim / TMSL"]
    DW --> SSRS["SSRS RDL\nrapports operationnels"]
```

## Contenu

- `compose.yaml` : SQL Server 2022 pour Codespace/local.
- `sql/` : creation `DW`, donnees source, procedures delta, validation.
- `ssis/` : source Biml du package SSIS `LoadDWDelta` et notes de generation.
- `ssas/` : modele tabulaire `model.bim`; le script Windows le transforme en TMSL de deploiement.
- `ssrs/` : rapports RDL `SalesByRegion`, `MonthlySales`, `TopCustomers`.
- `scripts/` : deploiement, delta, validation, smoke test, deploiement Windows BI.
- `tests/` : validations statiques executables en CI.

## Commandes utiles

```bash
./scripts/deploy.sh
./scripts/run-delta.sh
./scripts/validate.sh
docker compose logs -f mssql
docker compose down -v
```

## Deploiement SSIS / SSAS / SSRS

Sur une machine Windows avec SQL Server tooling :

```powershell
.\scripts\deploy-windows-bi.ps1 `
  -SqlServer "localhost,1433" `
  -SqlUser "sa" `
  -SqlPassword "Passw0rd123!" `
  -SsasServer "localhost" `
  -SsrsBaseUrl "http://localhost/ReportServer"
```

Le script Windows :

- verifie la connexion SQL ;
- documente l'execution SSIS attendue avec `dtexec` ;
- deploie le modele SSAS via `Invoke-ASCmd` si le module `SqlServer` est present ;
- publie les RDL via `ReportingServicesTools` si le module est present.

## Verification CI

```bash
python -m unittest discover -s msbi2-codespace-codex_and_o3/tests -v
```

Ces tests ne remplacent pas le smoke test SQL Server, mais ils garantissent que
les artefacts attendus existent et que les modeles SSAS/SSRS restent parseables.
