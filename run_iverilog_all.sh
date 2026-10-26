#!/usr/bin/env bash
set -euo pipefail
mkdir -p build
iverilog -g2012 -Wall -s tb_mul_reconfig -o build/mul_reconfig.vvp rtl/alu_mul_reconfig.sv tb/tb_mul_reconfig.sv && vvp build/mul_reconfig.vvp
iverilog -g2012 -Wall -s tb_linear4_control -o build/linear4_control.vvp rtl/fp32_linear4_control.sv tb/tb_linear4_control.sv && vvp build/linear4_control.vvp
iverilog -g2012 -Wall -s tb_sigmul_linear4 -o build/sigmul_linear4.vvp rtl/alu_mul_reconfig.sv rtl/fp32_sigmul_linear4.sv tb/tb_sigmul_linear4.sv && vvp build/sigmul_linear4.vvp
iverilog -g2012 -Wall -s tb_partial_product_scheduler -o build/partial_product_scheduler.vvp rtl/partial_product_scheduler.sv tb/tb_partial_product_scheduler.sv && vvp build/partial_product_scheduler.vvp
iverilog -g2012 -Wall -s tb_fma_z_pipeline -o build/fma_z_pipeline.vvp rtl/alu_mul_reconfig.sv rtl/fp32_sigmul_linear4.sv rtl/fp32_fma_z_pipeline.sv tb/tb_fma_z_pipeline.sv && vvp build/fma_z_pipeline.vvp

iverilog -g2012 -Wall -s tb_fma_finite_opt -o build/fma_finite_opt.vvp rtl/alu_mul_reconfig.sv rtl/fp32_sigmul_linear4.sv rtl/fp32_fma_finite_opt.sv tb/tb_fma_finite_opt.sv && vvp build/fma_finite_opt.vvp
