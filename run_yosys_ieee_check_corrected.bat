@echo off
setlocal EnableExtensions
pushd "%~dp0"
if errorlevel 1 (
    echo ERROR: cannot enter project directory.
    exit /b 1
)

if not exist reports mkdir reports
if not exist reports (
    echo ERROR: could not create reports directory.
    popd
    exit /b 1
)

rem Remove stale output so an old JSON cannot be mistaken for this run.
if exist reports\fp32_fma_ieee.json del /q reports\fp32_fma_ieee.json
if exist reports\yosys_ieee_stat.txt del /q reports\yosys_ieee_stat.txt
if exist reports\yosys_ieee_run.log del /q reports\yosys_ieee_run.log

echo Running Yosys IEEE synthesis check...
yosys -s scripts\yosys_ieee_check.ys > reports\yosys_ieee_run.log 2>&1
set "YOSYS_RC=%ERRORLEVEL%"

type reports\yosys_ieee_run.log

if not "%YOSYS_RC%"=="0" (
    echo ERROR: Yosys failed with exit code %YOSYS_RC%.
    popd
    exit /b %YOSYS_RC%
)

if not exist reports\fp32_fma_ieee.json (
    echo ERROR: Yosys returned success but did not create reports\fp32_fma_ieee.json.
    echo Inspect reports\yosys_ieee_run.log for the last completed pass.
    popd
    exit /b 2
)

if not exist reports\yosys_ieee_stat.txt (
    echo ERROR: Yosys did not create reports\yosys_ieee_stat.txt.
    popd
    exit /b 3
)

echo Yosys completed and generated the JSON report.
echo Running multiplier-structure audit...
python scripts\check_ieee_mul_count.py
set "AUDIT_RC=%ERRORLEVEL%"
if not "%AUDIT_RC%"=="0" (
    echo ERROR: multiplier audit failed with exit code %AUDIT_RC%.
    popd
    exit /b %AUDIT_RC%
)

echo PASS: Yosys report generation and multiplier audit completed.
popd
endlocal
exit /b 0
