@echo off
setlocal EnableExtensions
pushd "%~dp0"
if errorlevel 1 (
    echo ERROR: cannot enter project directory.
    exit /b 1
)
call run_yosys_ieee_check_corrected.bat
set "RC=%ERRORLEVEL%"
popd
endlocal & exit /b %RC%
