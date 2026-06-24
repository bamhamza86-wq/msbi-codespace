# SSIS delta load

`LoadDWDelta.dtsx` is the runnable SSIS package for the delta pipeline.

Expected package flow:

1. Execute SQL Task: run `EXEC etl.usp_LoadDeltaAll @BatchName = N'ssis-delta';`.
2. Execute SQL Task: fail when `dw.FactSales` is empty after the SSIS delta load.

Run it on a Windows host with SSIS installed:

```powershell
dtexec.exe /F .\ssis\LoadDWDelta.dtsx /Connection "DW;Provider=MSOLEDBSQL;Data Source=localhost,1433;Initial Catalog=DW;User ID=sa;Password=Passw0rd123!;Trust Server Certificate=True;" /REP E
```

`LoadDWDelta.biml` is kept as the package source description for teams that
prefer to regenerate the package with Biml tooling.

The Codespace/Linux path validates the same delta logic through SQL scripts
because SSIS is not supported as a Linux container workload. Runtime SSIS
validation belongs on a Windows/SSIS host and is automated by
`scripts/validate-windows-bi.ps1`.
