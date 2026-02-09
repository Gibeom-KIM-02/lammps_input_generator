#!/usr/bin/env bash
set -euo pipefail

YML="${1:-ligpargen_run.yml}"

# ---- locate conda in a portable way ----
if ! command -v conda >/dev/null 2>&1; then
  echo "[ERR] conda command not found. Install/enable Miniconda/Anaconda first." >&2
  exit 1
fi

CONDA_BASE="$(conda info --base)"
# shellcheck disable=SC1090
source "${CONDA_BASE}/etc/profile.d/conda.sh"

# ---- read env name from YAML ----
ENV_NAME="$(awk -F': *' '$1=="name"{print $2; exit}' "$YML")"
if [[ -z "${ENV_NAME}" ]]; then
  echo "[ERR] No 'name:' found in $YML" >&2
  exit 2
fi

echo "[INFO] YAML: $YML"
echo "[INFO] ENV : $ENV_NAME"

# ---- create/update env ----
if conda env list | awk '{print $1}' | grep -qx "${ENV_NAME}"; then
  echo "[INFO] Env exists -> update"
  conda env update -n "${ENV_NAME}" -f "${YML}" --prune
else
  echo "[INFO] Create env"
  conda env create -f "${YML}"
fi

conda activate "${ENV_NAME}"

# ---- install LigPargen WITHOUT pulling PyPI 'pybel' (biology) ----
# Pin to a known commit for reproducibility (override if you want)
LIGPARGEN_URL="${LIGPARGEN_URL:-https://github.com/Isra3l/ligpargen.git}"
LIGPARGEN_REF="${LIGPARGEN_REF:-03732d8095aaafa2207bc16e89122e02d7a8bd14}"  # set to "main" if you want latest
LIGPARGEN_PIP_SPEC="git+${LIGPARGEN_URL}@${LIGPARGEN_REF}"

echo "[INFO] Installing LigPargen from: ${LIGPARGEN_PIP_SPEC}"
python -m pip install --upgrade pip
python -m pip install -U markdown
python -m pip install --no-deps "${LIGPARGEN_PIP_SPEC}"

# ---- sanity checks ----
echo "[TEST] python = $(python -V)"

echo "[TEST] openbabel/pybel import (OpenBabel pybel)"
python - <<'PY'
from openbabel import pybel
print("OK: from openbabel import pybel")
PY

echo "[TEST] ligpargen command"
command -v ligpargen >/dev/null && echo "OK: ligpargen found" || echo "WARN: ligpargen not in PATH"

# ---- BOSSdir check (required for actual OPLS-AA parameter generation) ----
if [[ -z "${BOSSdir:-}" ]]; then
  echo "[WARN] BOSSdir is not set. LigParGen may fail when generating OPLS-AA parameters."
  echo "       Set it like:  export BOSSdir=/path/to/boss"
  echo "       (Put it in ~/.bashrc to persist.)"
else
  if [[ -d "${BOSSdir}" ]]; then
    echo "[OK] BOSSdir is set: ${BOSSdir}"
  else
    echo "[WARN] BOSSdir is set but not a directory: ${BOSSdir}"
  fi
fi

echo "[DONE] Activate with: conda activate ${ENV_NAME}"

