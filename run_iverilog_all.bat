@echo off
setlocal
if not exist build mkdir build
iverilog -g2012 -Wall -s tb_mul_reconfig -o build\mul_reconfig.vvp rtl\alu_mul_reconfig.sv tb\tb_mul_reconfig.sv
if errorlevel 1 exit /b 1
vvp build\mul_reconfig.vvp
if errorlevel 1 exit /b 1
iverilog -g2012 -Wall -s tb_linear4_control -o build\linear4_control.vvp rtl\fp32_linear4_control.sv tb\tb_linear4_control.sv
if errorlevel 1 exit /b 1
vvp build\linear4_control.vvp
if errorlevel 1 exit /b 1
iverilog -g2012 -Wall -s tb_sigmul_linear4 -o build\sigmul_linear4.vvp rtl\alu_mul_reconfig.sv rtl\fp32_sigmul_linear4.sv tb\tb_sigmul_linear4.sv
if errorlevel 1 exit /b 1
vvp build\sigmul_linear4.vvp
if errorlevel 1 exit /b 1
iverilog -g2012 -Wall -s tb_partial_product_scheduler -o build\partial_product_scheduler.vvp rtl\partial_product_scheduler.sv tb\tb_partial_product_scheduler.sv
if errorlevel 1 exit /b 1
vvp build\partial_product_scheduler.vvp
if errorlevel 1 exit /b 1
iverilog -g2012 -Wall -s tb_fma_z_pipeline -o build\fma_z_pipeline.vvp rtl\alu_mul_reconfig.sv rtl\fp32_sigmul_linear4.sv rtl\fp32_fma_z_pipeline.sv tb\tb_fma_z_pipeline.sv
if errorlevel 1 exit /b 1
vvp build\fma_z_pipeline.vvp
if errorlevel 1 exit /b 1
iverilog -g2012 -Wall -s tb_fma_finite_opt -o build\fma_finite_opt.vvp rtl\alu_mul_reconfig.sv rtl\fp32_sigmul_linear4.sv rtl\fp32_fma_finite_opt.sv tb\tb_fma_finite_opt.sv
if errorlevel 1 exit /b 1
vvp build\fma_finite_opt.vvp
if errorlevel 1 exit /b 1
iverilog -g2012 -Wall -s tb_fma_ieee -o build\fma_ieee.vvp rtl\alu_mul_reconfig.sv rtl\fp32_sigmul_linear4.sv rtl\fp32_fma_ieee.sv tb\tb_fma_ieee.sv
if errorlevel 1 exit /b 1
vvp build\fma_ieee.vvp
if errorlevel 1 exit /b 1
endlocal
