@echo off
setlocal
if not exist build mkdir build
where gcc >nul 2>nul
if errorlevel 1 (
  echo ERROR: gcc not found. Install MinGW-w64 GCC and add it to PATH.
  exit /b 2
)
gcc -O2 -std=c11 -fno-fast-math -frounding-math -fno-builtin-fmaf scripts\fma_reference.c -o build\fma_reference.exe -lm
if errorlevel 1 exit /b 1
build\fma_reference.exe build\fma_vectors.hex
if errorlevel 1 exit /b 1
iverilog -g2012 -Wall -s tb_fma_ieee_diff -Ptb_fma_ieee_diff.N=100000 -o build\fma_ieee_diff.vvp rtl\alu_mul_reconfig.sv rtl\fp32_sigmul_linear4.sv rtl\fp32_fma_ieee.sv tb\tb_fma_ieee_diff.sv
if errorlevel 1 exit /b 1
vvp build\fma_ieee_diff.vvp
if errorlevel 1 exit /b 1
endlocal
