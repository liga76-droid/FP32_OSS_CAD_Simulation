import json
import os
import sys

p = os.path.join('reports', 'fp32_fma_ieee.json')
if not os.path.isfile(p):
    print(f'ERROR: report not found: {p}')
    print('Yosys did not generate the JSON report. Inspect reports/yosys_ieee_run.log.')
    sys.exit(2)

try:
    with open(p, encoding='utf-8') as f:
        d = json.load(f)
except (OSError, json.JSONDecodeError) as e:
    print(f'ERROR: cannot read valid Yosys JSON report {p}: {e}')
    sys.exit(2)

try:
    cells = d['modules']['fp32_fma_ieee']['cells']
except (KeyError, TypeError) as e:
    print(f'ERROR: expected module/cells not found in {p}: {e}')
    sys.exit(2)

muls = [(n, c) for n, c in cells.items() if c.get('type') == '$mul']
print('Yosys audit — fp32_fma_ieee generic $mul cells:', len(muls))
for n, c in muls:
    con = c.get('connections', {})
    widths = (len(con.get('A', [])), len(con.get('B', [])), len(con.get('Y', [])))
    print(n, widths)

if len(muls) != 4:
    print('NOTE: optimizer may merge/remove multiplier cells; inspect JSON and stat manually.')
    sys.exit(1)
if any((len(c['connections'].get('A', [])), len(c['connections'].get('B', [])),
        len(c['connections'].get('Y', []))) != (16, 16, 32) for _, c in muls):
    print('FAIL: unexpected multiplier width')
    sys.exit(1)
print('PASS: four 16x16 generic multipliers visible in flattened top.')
print('LIMIT: structural audit does not prove FMA conformance, schedule mapping, PPA, or throughput.')
