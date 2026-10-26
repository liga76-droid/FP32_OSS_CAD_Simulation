import json,sys
path=sys.argv[1] if len(sys.argv)>1 else 'reports/fp32_fma_finite_opt.json'
data=json.load(open(path,encoding='utf-8'))
top='fp32_fma_finite_opt'
if top not in data.get('modules',{}): raise SystemExit('FAIL: optimized top missing')
cells=data['modules'][top].get('cells',{})
muls=[(n,c) for n,c in cells.items() if c.get('type','').startswith('$mul')]
print('Yosys audit —',top,'generic $mul cells:',len(muls))
if len(muls)!=4: raise SystemExit('FAIL: expected four multiplier cells')
def intval(v):
 if isinstance(v,int): return v
 if isinstance(v,str):
  try:return int(v,2)
  except ValueError:return int(v,0)
for n,c in muls:
 p=c.get('parameters',{}); w=tuple(intval(p.get(k)) for k in ('A_WIDTH','B_WIDTH','Y_WIDTH'))
 if w!=(16,16,32): raise SystemExit(f'FAIL: {n} widths={w}')
 print('PASS',n,w)
ports=data['modules'][top].get('ports',{})
if 'sum_mantissa' not in ports or len(ports['sum_mantissa']['bits'])!=64: raise SystemExit('FAIL: compact 64-bit sum port missing')
if 'exact_sum_scaled' in ports: raise SystemExit('FAIL: 560-bit exact output still present in optimized top')
print('PASS: 64-bit compact accumulator interface; no 560-bit sum output.')
print('NOTE: audit does not prove FMA IEEE-754, PPA, or II under all stalls.')
