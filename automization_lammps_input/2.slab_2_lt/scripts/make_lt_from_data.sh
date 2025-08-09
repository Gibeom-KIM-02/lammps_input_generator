#!/usr/bin/env bash
# make_lt_from_data.sh
# Convert a LAMMPS data file for a metal slab into a modular .lt file for Moltemplate.
# Usage:
#   bash scripts/make_lt_from_data.sh data/Ag_slab.data
# Output:
#   lt/Ag.lt

# ========== 1. Parse arguments and paths ==========
DATA="$1"                                         # Input LAMMPS DATA file
if [ ! -f "$DATA" ]; then
    echo "[Error] Input file not found: $DATA"
    exit 1
fi

LTNAME=$(basename "$DATA" _slab.data)             # Extract metal name (Ag, Cu, etc.)
OUTDIR="lt"                                       # Output directory for .lt files
OUTLT="$OUTDIR/${LTNAME}.lt"                      # Output .lt file
YAML="config/metals.yaml"                         # Metals parameter file

mkdir -p "$OUTDIR"

# ========== 2. Read metal parameters from metals.yaml ==========
# Uses python for robust YAML parsing
read -r MASS SIGMA EPSILON <<< $(python3 - <<PY
import yaml
p = yaml.safe_load(open("$YAML"))["$LTNAME"]
print(p['mass'], p['sigma'], p['epsilon'])
PY
)

echo "Converting $DATA → $OUTLT"
echo "Using parameters: mass=$MASS, sigma=$SIGMA, epsilon=$EPSILON (from $YAML)"

# ========== 3. Run ltemplify.py to convert DATA to initial LT format ==========
ltemplify.py "$DATA" > "$OUTDIR/${LTNAME}.lt.tmp"

# ========== 4. Insert parameters and rewrite atom types in LT file ==========
python3 - <<EOF
import re, os

ltname = "$LTNAME"
mass = float("$MASS")
sigma = float("$SIGMA")
epsilon = float("$EPSILON")
indir = "$OUTDIR"
tmpfile = f"{indir}/{ltname}.lt.tmp"
outfile = f"{indir}/{ltname}.lt"

# Read lines from the initial LT file
lines = open(tmpfile).readlines()

# Replace all atom types with a unique name, e.g., @atom:Ag
atom_types = sorted({at for l in lines for at in re.findall(r'@atom:type\\d+', l)})
atom_map = {old: f'@atom:{ltname}' for old in atom_types}

def repl_types(line):
    for k, v in atom_map.items():
        line = line.replace(k, v)
    return line

with open(outfile, "w") as out:
    out.write("import oplsaa2024.lt\n\n")
    out.write("{} inherits OPLSAA {{\n\n".format(ltname))
    out.write('  write_once("Data Masses") {\n')
    out.write("    @atom:{} {}\n  }}\n\n".format(ltname, mass))
    out.write('  write_once("In Settings") {\n')
    out.write("    pair_coeff @atom:{} @atom:{} {} {}\n  }}\n\n".format(ltname, ltname, epsilon, sigma))
    out.write('  write_once("In Init") {\n    atom_style full\n  }\n\n')   

    writing_block = False
    skip_block = False
    for line in lines:
        # Skip all lines within an In Init block from lt.tmp
        if "write_once" in line and "In Init" in line:
            skip_block = True
            continue
        if skip_block:
            # Block ends with a line containing just "}"
            if line.strip() == "}":
                skip_block = False
            continue

        if "write_once" in line or "write(" in line:
            writing_block = True
            out.write("  " + repl_types(line))
        elif writing_block and line.strip() == "}":
            writing_block = False
            out.write("  }\n\n")
        elif writing_block:
            out.write("    " + repl_types(line))
    out.write("}\n")
EOF

# ========== 5. Cleanup ==========
# rm "$OUTDIR/${LTNAME}.lt.tmp"

echo "[OK] LT file created at $OUTLT"


