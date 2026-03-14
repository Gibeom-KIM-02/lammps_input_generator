#!/usr/bin/env python3
"""
make_system_lt.py

Generates a detailed, user-friendly system.lt for moltemplate
using config/molecules.yaml and a PACKMOL/ASE XYZ file.

Key features
------------
• YAML-driven: file paths, class names, counting rules, slab options
• Automatic dependency resolution among count_rule expressions
• Auto-detected simulation box
• Helpful comments & checklists injected into system.lt
"""

from pathlib import Path
import sys, yaml, re
import numpy as np

# -------------------------------------------------------------------
# CONFIG
# -------------------------------------------------------------------
MOLECULES_YAML = Path("config/molecules.yaml")

# -------------------------------------------------------------------
# 1) Load YAML
# -------------------------------------------------------------------
try:
    mol_cfg_full = yaml.safe_load(open(MOLECULES_YAML, encoding="utf-8"))
except Exception as e:
    sys.exit(f"[ERROR] Failed to load {MOLECULES_YAML}: {e}")

global_cfg = mol_cfg_full.get("global", {})
mol_cfg    = mol_cfg_full.get("molecules", {})
if not global_cfg or not mol_cfg:
    sys.exit("[ERROR] 'global' or 'molecules' block missing in molecules.yaml.")

# Add this line right after global_cfg is set:
extra_imports = global_cfg.get("extra_imports", [])

xyz_path = Path(global_cfg["xyz_file"])
lt_out   = Path(global_cfg["output_lt"])
if not xyz_path.exists():
    sys.exit(f"[ERROR] XYZ file not found: {xyz_path}")

# -------------------------------------------------------------------
# 2) Count elements & collect coordinates
# -------------------------------------------------------------------
elem_counts, coords = {}, []
with xyz_path.open() as fh:
    for line in fh.readlines()[2:]:  # skip atom count & comment
        if not line.strip():
            continue
        el, x, y, z, *_ = line.split()
        elem_counts[el] = elem_counts.get(el, 0) + 1
        coords.append((float(x), float(y), float(z)))
coords = np.asarray(coords)
if coords.size == 0:
    sys.exit("[ERROR] No atomic coordinates found in XYZ.")

# -------------------------------------------------------------------
# 3) Helper: atom count in slab .lt
# -------------------------------------------------------------------
def atoms_per_molecule(lt_file: str) -> int:
    txt = Path(lt_file).read_text(encoding="utf-8")
    # Accept both write_once("Data Atoms") and write("Data Atoms")
    match = re.search(r'write(?:_once)?\("Data Atoms"\)\s*\{([^}]*)\}', txt, re.S)
    if match:
        return len(re.findall(r'@atom:', match.group(1)))
    print(f"[WARN] No 'Data Atoms' block found in {lt_file}, counting in full file.")
    return len(re.findall(r'@atom:', txt))

# -------------------------------------------------------------------
# 4) Resolve molecule counts (handles dependencies)
# -------------------------------------------------------------------
mol_counts   = {}
unresolved   = dict(mol_cfg)  # shallow copy

while unresolved:
    progress = False
    for name, spec in list(unresolved.items()):
        if spec.get("adsorbent", False):
            n_per = atoms_per_molecule(spec["lt_path"])
            n    = elem_counts.get("Ag", 0) // n_per or 1
            if "force_count" in spec:
                n = int(spec["force_count"])
            mol_counts[name] = n
            unresolved.pop(name)
            progress = True
        else:
            rule = spec.get("count_rule")
            if rule is None:
                sys.exit(f"[ERROR] count_rule missing for molecule '{name}'.")
            try:
                mol_counts[name] = int(
                    eval(rule, {}, {"elem": elem_counts, "mol": mol_counts})
                )
                unresolved.pop(name)
                progress = True
            except KeyError:
                # depends on a molecule not yet calculated → wait next loop
                pass
    if not progress:
        sys.exit(f"[ERROR] Circular / unresolved dependencies in count_rule: "
                 f"{', '.join(unresolved)}")

print("[INFO] Molecule counts:", mol_counts)

# -------------------------------------------------------------------
# 5) Simulation box (+0 Å padding)
# -------------------------------------------------------------------
pad = 0.0
lo  = coords.min(0) - pad
hi  = coords.max(0) + pad
box_str = (
    f"{lo[0]} {hi[0]} xlo xhi\n"
    f"  {lo[1]} {hi[1]} ylo yhi\n"
    f"  {lo[2]} {hi[2]} zlo zhi"
)

# -------------------------------------------------------------------
# 6) Build import-block (YAML order preserved)
# -------------------------------------------------------------------
def import_line(path): 
    """Return a properly formatted import line with a path warning."""
    return f'import "{path}"   # <-- Adjust path if needed!'

import_block = [
    "# ------------------------------------------------------------",
    "# MOLECULE DEFINITIONS",
    "# !! NOTE !!  Paths are relative to the directory where you run moltemplate.sh.",
    "# ------------------------------------------------------------",
]
# Add extra_imports (from global block in molecules.yaml)
for path in extra_imports:
    import_block.append(f'import "{path}"   # <-- Adjust path if needed!')

# Then add all molecules' lt files (order preserved from YAML)
import_block += [import_line(Path(spec["lt_path"]).as_posix())
                 for spec in mol_cfg.values()]
import_block.append("")

# -------------------------------------------------------------------
# 7) Instantiate molecules (YAML order preserved)
# -------------------------------------------------------------------
inst_block = [
    "# ------------------------------------------------------------",
    "# INSTANTIATE OBJECTS  (must match XYZ ordering!)",
    "# ------------------------------------------------------------",
]
for name, spec in mol_cfg.items():
    inst_name = spec.get("instance_name", name)
    cls       = spec["class_name"]
    n         = mol_counts[name]
    extra     = ""
    if spec.get("adsorbent"):
        per   = atoms_per_molecule(spec["lt_path"])
        extra = f"  # {n*per} Ag atoms total ({per}/slab)"
    inst_block.append(f"{inst_name} = new {cls}[{n}]{extra}")
inst_block.append("")

# -------------------------------------------------------------------
# 8) Optional slab fixes
# -------------------------------------------------------------------
fix_block = ""
fix_lines = []
for name, spec in mol_cfg.items():
    gid = spec.get("fixed_group")
    if spec.get("adsorbent") and gid:
        fix_lines.append(
            f"  group fixed_{name} id {gid}\n"
            f"  fix   hold_{name} fixed_{name} setforce 0 0 0"
        )
if fix_lines:
    fix_block = (
        "# ------------------------------------------------------------\n"
        "# FIX SLAB ATOMS (edit 'fixed_group' in YAML as needed)\n"
        "# ------------------------------------------------------------\n"
        'write_once("In Settings") {\n'
        + "\n".join(fix_lines) + "\n}\n"
    )

# -------------------------------------------------------------------
# 9) Build instructions / checklist
# -------------------------------------------------------------------
mol_sequence = " → ".join(mol_cfg.keys())
build_note = (
    "###############################################################\n"
    "#  BUILD INSTRUCTIONS\n"
    f"#  Run: moltemplate.sh -xyz {xyz_path.name} -atomstyle \"full\" system.lt\n"
    "#\n"
    "#  CHECKLIST\n"
    f"#  1) XYZ atom order  : {mol_sequence}\n"
    "#  2) Net charge      : verify in molecules.yaml (add counter-ions if needed)\n"
    "#  3) SHAKE for water : see water .lt for fix name (e.g. fShakeTIP3P_2004)\n"
    "#  4) Adjust 'fixed_group' if slab size changes\n"
    "#  5) IMPORT paths above must be correct for your run directory\n"
    "###############################################################\n"
)

# -------------------------------------------------------------------
# 11) Write system.lt (no trailing slashes/empty lines)
# -------------------------------------------------------------------
lt_text = (
    "###############################################################\n"
    "#  system.lt (auto-generated by make_system_lt.py)\n"
    f"#  Source XYZ : {xyz_path.name}\n"
    "###############################################################\n\n"
    + "# ------------------------------------------------------------\n"
    + "# BOX DIMENSIONS  (auto-detected)\n"
    + "# ------------------------------------------------------------\n"
    + f"write_once(\"Data Boundary\") {{\n  {box_str}\n}}\n\n"
    + "\n".join(import_block)
    + "\n"
    + "\n".join(inst_block)
    + "\n"
    + fix_block
    + build_note
)

lt_out.write_text(lt_text)
print(f"[DONE] Wrote {lt_out}")

