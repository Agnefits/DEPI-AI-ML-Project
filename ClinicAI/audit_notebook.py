import json, ast
from pathlib import Path

nb = json.loads(Path("clinicai-v2-0.ipynb").read_text(encoding="utf-8"))
cells      = nb["cells"]
code_cells = [c for c in cells if c["cell_type"] == "code"]
md_cells   = [c for c in cells if c["cell_type"] == "markdown"]
full_code  = "\n".join("".join(c["source"]) for c in code_cells)

# ── 1. Inventory ─────────────────────────────────────────────────────────────
print("=== CELL INVENTORY ===")
print(f"  Total cells : {len(cells)}")
print(f"  Code cells  : {len(code_cells)}")
print(f"  MD   cells  : {len(md_cells)}")

# ── 2. Syntax check each code cell ───────────────────────────────────────────
print("\n=== SYNTAX CHECKS (per code cell) ===")
for i, c in enumerate(code_cells):
    src = "".join(c["source"])
    try:
        ast.parse(src)
        status = "OK"
    except SyntaxError as e:
        status = f"SYNTAX ERROR line {e.lineno}: {e.msg}"
    first = src.strip().splitlines()[0][:55] if src.strip() else "(empty)"
    print(f"  Cell {i+1:02d}: {status}  | {first}")

# ── 3. API / correctness checks ──────────────────────────────────────────────
print("\n=== API / PATTERN CHECKS ===")
checks = [
    ("from torch.cuda.amp import",        "DEPRECATED import (PyTorch>=2.x) -- use 'from torch.amp import'"),
    ("Data_Entry_2017.csv",               "WRONG CSV name -- NIH file is 'Data_Entry_2017_v2020.csv'"),
    ("kaggle/input/datasets/organizations","WRONG Kaggle path -- should be /kaggle/input/nih-chest-xrays-data"),
    ("var_limit=",                         "OLD GaussNoise API (albumentations<1.4) -- new param is std_range"),
    ("std_range=",                         None),
    ("max_holes=",                         "OLD CoarseDropout API -- new param is num_holes_range"),
    ("num_holes_range=",                   None),
    ("max_height=",                        "OLD CoarseDropout API -- new param is hole_height_range"),
    ("hole_height_range=",                 None),
    ("build_dataloader",                   None),
    ("IMAGE_MAP",                          None),
    ("channels_last",                      None),
    ("torch.compile",                      None),
    ("CosineWarmupScheduler",              None),
    ("ModelEMA",                           None),
    ("ThresholdOptimiser",                 None),
    ("TTAInference",                       None),
    ("GradCAMVisualiser",                  None),
    ("InferencePipeline",                  None),
    ("ErrorAnalyser",                      None),
    ("Reporter",                           None),
    ("def main(",                          None),
    ("def build_dataloader(",              None),
    ("def build_tta_transforms(",          None),
    ("def load_metadata(",                 None),
    ("apply_performance_opts",             None),
]

for pattern, warning in checks:
    found = pattern in full_code
    if found and warning:
        tag = "BUG   "
        note = f"  --> {warning}"
    elif found:
        tag = "FOUND "
        note = ""
    else:
        tag = "ABSENT"
        note = "  --> NOT DEFINED in notebook" if warning is None else ""
    print(f"  [{tag}] {pattern}{note}")

# ── 4. All defined symbols ────────────────────────────────────────────────────
print("\n=== DEFINED SYMBOLS ===")
try:
    tree    = ast.parse(full_code)
    classes = sorted(n.name for n in ast.walk(tree) if isinstance(n, ast.ClassDef))
    funcs   = sorted(set(
        n.name for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)
        and not n.name.startswith("_")
    ))
    print(f"  Classes : {classes}")
    print(f"  Funcs   : {funcs}")
except SyntaxError as e:
    print(f"  Cannot parse full_code: {e}")

# ── 5. Execution history ──────────────────────────────────────────────────────
print("\n=== EXECUTION STATUS ===")
for i, c in enumerate(code_cells):
    ec  = c.get("execution_count")
    out = c.get("outputs", [])
    err = any(o.get("output_type") == "error" for o in out)
    print(f"  Cell {i+1:02d} | exec#{str(ec):<4} outputs={len(out)}  error={err}")
