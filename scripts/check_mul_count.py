import json, sys
path = sys.argv[1] if len(sys.argv) > 1 else "reports/fp32_fma_z_pipeline.json"
with open(path, encoding="utf-8") as f:
    data = json.load(f)
modules = data.get("modules", {})
top = "fp32_fma_z_pipeline"
if top not in modules:
    print(f"FAIL: top module {top!r} not found; available={list(modules)}")
    sys.exit(1)
cells = modules[top].get("cells", {})
mul = [(n, c) for n, c in cells.items() if c.get("type", "").startswith("$mul")]
print(f"Yosys audit — {top}")
print("Generic $mul cells:", len(mul))
if len(mul) != 4:
    print("FAIL: expected four 16x16 multiplier operators in integrated hierarchy.")
    sys.exit(1)
def intval(v):
    if isinstance(v, int): return v
    if isinstance(v, str):
        try: return int(v, 2)
        except ValueError: return int(v, 0)
    return None
for n, c in mul:
    p = c.get("parameters", {})
    widths = tuple(intval(p.get(k)) for k in ("A_WIDTH", "B_WIDTH", "Y_WIDTH"))
    if widths != (16, 16, 32):
        print("FAIL", n, widths); sys.exit(1)
    print("PASS", n, "A/B/Y widths", widths)
print("PASS: four 16x16 $mul cells in the integrated top.")
print("NOTE: this structural audit does not prove FMA arithmetic, IEEE-754, PPA, or II under backpressure.")
