#!/usr/bin/env bash
set -euo pipefail
mkdir -p reports
yosys -s scripts/yosys_opt_check.ys
python scripts/check_opt_mul_count.py reports/fp32_fma_finite_opt.json
