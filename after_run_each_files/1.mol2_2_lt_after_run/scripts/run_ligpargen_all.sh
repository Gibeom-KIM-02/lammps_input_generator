#!/usr/bin/env bash
# scripts/run_ligpargen_all.sh
# Batch-convert all .mol2 files in input_files/ using LigParGen + ltemplify + lt_postprocess.py

set -euo pipefail
shopt -s nullglob

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
command -v yq >/dev/null 2>&1 || { echo "yq (mikefarah/yq) is required but not found."; exit 1; }

mkdir -p "${OUT_DIR}" "${LT_DIR}"

# --- Main loop over each .mol2 file in input_files/ ---
for mol2 in "${INPUT_DIR}"/*.mol2; do
    fname="$(basename -- "$mol2")"
    mol="${fname%.mol2}"

    echo "▶ Processing ${mol2}"

    RES="$(yq -r ".molecules[\"${mol}\"].res" "${CONFIG_YAML}")"
    CHARGE="$(yq -r ".molecules[\"${mol}\"].charge" "${CONFIG_YAML}")"
    SMILES="$(yq -r ".molecules[\"${mol}\"].smiles // \"\"" "${CONFIG_YAML}")"
    OPTIMIZE="$(yq -r ".molecules[\"${mol}\"].optimize // \"\"" "${CONFIG_YAML}")"

    # leading '+' safe-strip (e.g. "+1" -> "1")
    CHARGE="${CHARGE#+}"

    # default optimize value if not given
    if [[ -z "${OPTIMIZE}" || "${OPTIMIZE}" == "null" ]]; then
        OPTIMIZE=0
    fi

    # simple validation
    if ! [[ "${OPTIMIZE}" =~ ^[0-9]+$ ]]; then
        echo "  ✖ Invalid optimize value for '${mol}' in molecules.yaml: ${OPTIMIZE}" >&2
        continue
    fi

    if [[ -z "${RES}" || "${RES}" == "null" || -z "${CHARGE}" || "${CHARGE}" == "null" ]]; then
        echo "  ✖ Entry for '${mol}' not found in molecules.yaml (res/charge missing)" >&2
        continue
    fi

    WORKDIR="${OUT_DIR}/${mol}"
    mkdir -p "${WORKDIR}"

    # --- Step 1: Run LigParGen ---
    if [[ -n "${SMILES}" && "${SMILES}" != "null" ]]; then
        echo "  • Using SMILES route"
        echo "  • LigParGen optimize count = ${OPTIMIZE}"
        ligpargen  -s "${SMILES}" \
                   -n "${mol}" \
                   -p "${WORKDIR}" \
                   -r "${RES}" \
                   -c "${CHARGE}" \
                   -o "${OPTIMIZE}" \
                   -cgen CM1A
    else
        echo "  • Using MOL2 route"
        echo "  • LigParGen optimize count = ${OPTIMIZE}"
        ligpargen  -i "${mol2}" \
                   -n "${mol}" \
                   -p "${WORKDIR}" \
                   -r "${RES}" \
                   -c "${CHARGE}" \
                   -o "${OPTIMIZE}" \
                   -cgen CM1A
    fi

    # --- Step 2: Convert LAMMPS data to Moltemplate LT format ---
    ltemplify.py "${WORKDIR}/${mol}.lammps.lmp" > "${WORKDIR}/${mol}.lt.tmp"

    # --- Step 3: Post-process LT file (prefix types, section reorg) ---
    python "${POST_PY}" "${WORKDIR}/${mol}.lt.tmp" "${LT_DIR}/${mol}.lt"

    echo "  ✅ ${LT_DIR}/${mol}.lt generated"
done

echo "🎉 All input_files/*.mol2 have been processed!"
