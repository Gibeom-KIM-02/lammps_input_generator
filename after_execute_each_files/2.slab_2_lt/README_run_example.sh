#!/usr/bin/env bash
# Quick demo: Generate an Ag slab and convert to LT file

set -e

echo "Step 1: Generate Ag slab as LAMMPS data file..."
python scripts/make_metal_slab.py --elem Ag --size 4 4 3 --vac 0.0

echo "Step 2: Convert Ag_slab.data to Moltemplate .lt file..."
bash scripts/make_lt_from_data.sh data/Ag_slab.data

echo "Result:"
ls -lh data/Ag_slab.data lt/Ag.lt

