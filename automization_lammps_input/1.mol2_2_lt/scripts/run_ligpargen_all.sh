#!/usr/bin/env bash
# scripts/run_ligpargen_all.sh
# Batch-convert all .mol2 files in input_files/ using LigParGen + ltemplify + lt_postprocess.py

set -euo pipefail

# --- Define key directories and script paths ---
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_DIR="${ROOT_DIR}/input_files"
CONFIG_YAML="${ROOT_DIR}/config/molecules.yaml"
POST_PY="${ROOT_DIR}/scripts/lt_postprocess.py"
OUT_DIR="${ROOT_DIR}/ff_out"
LT_DIR="${ROOT_DIR}/lt"

# --- Check for dependencies ---
command -v ligpargen >/dev/null 2>&1 || { echo "LigParGen not found in PATH."; exit 1; }
command -v ltemplify.py >/dev/null 2>&1 || { echo "ltemplify.py not found in PATH."; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "yq (YAML query) is required but not found."; exit 1; }

mkdir -p "${OUT_DIR}"
mkdir -p "${LT_DIR}"

# --- Main loop over each .mol2 file in input_files/ ---
for mol2 in "${INPUT_DIR}"/*.mol2; do
    fname=$(basename "${mol2}")            # Get filename, e.g., CO2.mol2
    mol=${fname%.mol2}                     # Remove extension, e.g., CO2

    echo "▶ Processing ${mol2}"

    # --- Query molecule parameters from YAML config ---
    RES=$(yq ".molecules.${mol}.res" "${CONFIG_YAML}")
    CHARGE=$(yq ".molecules.${mol}.charge" "${CONFIG_YAML}")

    # --- Guard: skip if not found in YAML ---
    if [[ "${RES}" == "null" || "${CHARGE}" == "null" ]]; then
        echo "  ✖ Entry for '${mol}' not found in molecules.yaml" >&2
        continue
    fi

    WORKDIR="${OUT_DIR}/${mol}"
    mkdir -p "${WORKDIR}"

    # --- Step 1: Run LigParGen to generate LAMMPS and topology files ---
    ligpargen  -i "${mol2}" \
               -n "${mol}" \
               -p "${WORKDIR}" \
               -r "${RES}" \
               -c "${CHARGE}" \
               -o 0 \
               -cgen CM1A-LBCC

    # --- Step 2: Convert LAMMPS data to Moltemplate LT format ---
    ltemplify.py  "${WORKDIR}/${mol}.lammps.lmp" > "${WORKDIR}/${mol}.lt.tmp"

    # --- Step 3: Post-process LT file (prefix types, section reorg) ---
    python "${POST_PY}" "${WORKDIR}/${mol}.lt.tmp" "${LT_DIR}/${mol}.lt"
#    rm "${WORKDIR}/${mol}.lt.tmp"

    echo "  ✅ ${LT_DIR}/${mol}.lt generated"
done

echo "🎉 All input_files/*.mol2 have been processed!"

