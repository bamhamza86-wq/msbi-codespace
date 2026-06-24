# SSIS delta load

`LoadDWDelta.biml` is the SSIS package source for the delta pipeline.

Expected package flow:

1. Execute SQL Task: create or refresh staging objects when needed.
2. Execute SQL Task: run `EXEC etl.usp_LoadDeltaAll @BatchName = N'ssis-delta';`.
3. Execute SQL Task: run the validation query in `sql/90_validation.sql` or a subset for operational monitoring.

The Codespace/Linux path validates the same delta logic through SQL scripts because
SSIS is not supported as a Linux container workload. On a Windows SSIS host, generate
the `.dtsx` from this Biml file and run it with `dtexec`.
