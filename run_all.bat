@echo off
REM Rebuilds the whole SQL pipeline in order and exports the Tableau CSVs.
REM Assumes PostgreSQL 18 on localhost and a database called delivery_sla.
REM 01_load.sql reads C:\Users\Public\dataco.csv (copy of the raw DataCo CSV).
cd /d "%~dp0"
if not exist exports mkdir exports
set PSQL="C:\Program Files\PostgreSQL\18\bin\psql.exe" -h 127.0.0.1 -U postgres -d delivery_sla -v ON_ERROR_STOP=1
for %%f in (01_load 02_clean 03_city_tiers 04_orders_view 05_ontime_by_dimension 06_cost_impact 07_monthly_trend 08_export_for_tableau) do (
  echo ===== %%f
  %PSQL% -f sql\%%f.sql || goto :error
)
echo.
echo Done. CSVs are in the exports folder.
goto :eof
:error
echo.
echo FAILED - see the error above.
exit /b 1
