# Windows BI acceptance

This is the acceptance gate for the parts that cannot run on a Linux
Codespace runner: SSIS, SSAS Tabular, and SSRS.

## Required runner

Register a self-hosted GitHub Actions runner on a Windows host with labels:

```text
self-hosted, Windows, msbi
```

The host must have:

- SQL Server Integration Services runtime with `dtexec.exe`;
- Microsoft OLE DB Driver for SQL Server;
- SQL Server Analysis Services Tabular reachable as `localhost` or the chosen `ssas_server`;
- SQL Server Reporting Services reachable at the chosen `ssrs_base_url`;
- PowerShell 7 or Windows PowerShell;
- PowerShell modules `SqlServer` and `ReportingServicesTools`.

## Repository secret

Create this repository secret:

```text
MSBI2_SQL_PASSWORD
```

The `sql_server` and `sql_user` values are workflow inputs so the same gate can
target local developer SQL Server, a VM, or a lab server.

## Manual workflow

Run the GitHub Actions workflow:

```text
MSBI2 Windows BI acceptance
```

The workflow runs:

1. prerequisite checks for `dtexec.exe`, `SqlServer`, and `ReportingServicesTools`;
2. `scripts/deploy-windows-bi.ps1`;
3. `scripts/validate-windows-bi.ps1`.

The validation fails unless all of the following are true:

- `DW` contains the expected six fact rows after the delta load;
- total sales equals `8260.00`;
- the SSIS package `ssis/LoadDWDelta.dtsx` executes through `dtexec.exe`;
- the SSAS Tabular model answers a DAX query;
- SSRS renders `SalesByRegion` to a non-empty PDF.

## Local equivalent

On the same Windows BI host, the equivalent command is:

```powershell
.\scripts\validate-windows-bi.ps1 `
  -SqlServer "localhost,1433" `
  -SqlUser "sa" `
  -SqlPassword "<password>" `
  -SsasServer "localhost" `
  -SsasDatabase "DW_Tabular" `
  -SsrsBaseUrl "http://localhost/ReportServer" `
  -SsrsFolder "/MSBI2"
```
