#!/usr/bin/env bash
set -euo pipefail
mkdir -p build
gcc -O2 -std=c11 -fno-fast-math -frounding-math -fno-builtin-fmaf scripts/fma_reference.c -o build/fma_reference -lm
./build/fma_reference build/fma_vectors.hex
iverilog -g2012 -Wall -s tb_fma_ieee_diff -Ptb_fma_ieee_diff.N=100000 -o build/fma_ieee_diff.vvp rtl/alu_mul_reconfig.sv rtl/fp32_sigmul_linear4.sv rtl/fp32_fma_ieee.sv tb/tb_fma_ieee_diff.sv
vvp build/fma_ieee_diff.vvp
