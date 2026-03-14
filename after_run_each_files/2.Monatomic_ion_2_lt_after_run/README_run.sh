#!/usr/bin/env bash
# README_run.sh — monatomic ions only

set -euo pipefail

python scripts/make_monatomic_ion_2_lt.py --config config/ions.yaml --in input_files --out lt

echo "🎉 Done. Check lt/ for generated ion .lt files."

