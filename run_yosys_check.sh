#!/usr/bin/env bash
set -euo pipefail
mkdir -p reports
yosys -s scripts/yosys_check.ys
python3 scripts/check_mul_count.py reports/fp32_fma_z_pipeline.json
