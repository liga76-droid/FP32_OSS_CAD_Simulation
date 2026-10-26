@echo off
setlocal
if not exist reports mkdir reports
yosys -s scripts\yosys_check.ys
if errorlevel 1 exit /b 1
python scripts\check_mul_count.py reports\fp32_fma_z_pipeline.json
if errorlevel 1 exit /b 1
endlocal
