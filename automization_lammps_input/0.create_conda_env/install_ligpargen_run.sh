#!/usr/bin/env bash
set -euo pipefail

trap 'echo "[ERR] line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

YML="${1:-ligpargen_run.yml}"

# -----------------------------
# 0) locate conda
# -----------------------------
if ! command -v conda >/dev/null 2>&1; then
  echo "[ERR] conda command not found. Install/enable Miniconda/Anaconda first." >&2
  exit 1
fi

CONDA_BASE="$(conda info --base)"

# conda.sh may reference PS1; avoid nounset crash in non-interactive shell
export PS1="${PS1-}"

set +u
# shellcheck disable=SC1090
source "${CONDA_BASE}/etc/profile.d/conda.sh"
set -u

# -----------------------------
# 1) read env name from YAML
# -----------------------------
if [[ ! -f "${YML}" ]]; then
  echo "[ERR] YAML file not found: ${YML}" >&2
  exit 2
fi

ENV_NAME="$(awk -F': *' '$1=="name"{print $2; exit}' "${YML}")"
if [[ -z "${ENV_NAME}" ]]; then
  echo "[ERR] No 'name:' found in ${YML}" >&2
  exit 3
fi

echo "[INFO] YAML: ${YML}"
echo "[INFO] ENV : ${ENV_NAME}"

# -----------------------------
# 2) create/update env
# -----------------------------
if conda env list | awk '{print $1}' | grep -qx "${ENV_NAME}"; then
  echo "[INFO] Env exists -> update"
  conda env update -n "${ENV_NAME}" -f "${YML}" --prune
else
  echo "[INFO] Create env"
  conda env create -f "${YML}"
fi

set +u
conda activate "${ENV_NAME}"
set -u

echo "[INFO] Active python : $(which python)"
echo "[INFO] Active pip    : $(which pip)"

# -----------------------------
# 3) basic Python toolchain
# -----------------------------
python -m pip install --upgrade pip setuptools wheel

# -----------------------------
# 4) remove old/broken install if any
# -----------------------------
python -m pip uninstall -y LigPargen ligpargen pybel >/dev/null 2>&1 || true

# -----------------------------
# 5) install LigParGen from pinned git commit
#    Use clone + editable install because this is more reliable
#    for creating the CLI entry point than the previous VCS direct install.
# -----------------------------
LIGPARGEN_URL="${LIGPARGEN_URL:-https://github.com/Isra3l/ligpargen.git}"
LIGPARGEN_REF="${LIGPARGEN_REF:-03732d8095aaafa2207bc16e89122e02d7a8bd14}"

WORKROOT="${TMPDIR:-/tmp}"
TMP_LIG_DIR="$(mktemp -d "${WORKROOT%/}/ligpargen_install_XXXXXX")"

cleanup() {
  if [[ -n "${TMP_LIG_DIR:-}" && -d "${TMP_LIG_DIR}" ]]; then
    rm -rf "${TMP_LIG_DIR}"
  fi
}
trap cleanup EXIT

echo "[INFO] Cloning LigParGen"
echo "       URL : ${LIGPARGEN_URL}"
echo "       REF : ${LIGPARGEN_REF}"
git clone "${LIGPARGEN_URL}" "${TMP_LIG_DIR}/ligpargen"

cd "${TMP_LIG_DIR}/ligpargen"
git checkout "${LIGPARGEN_REF}"

echo "[INFO] Installing LigParGen"
python -m pip install -U markdown
python -m pip install --no-deps .

# -----------------------------
# 6) sanity checks
# -----------------------------
echo "[TEST] python version"
python -V

echo "[TEST] openbabel/pybel import"
python - <<'PY'
from openbabel import pybel
print("OK: from openbabel import pybel")
PY

echo "[TEST] ligpargen Python import"
python - <<'PY'
import ligpargen
print("OK: import ligpargen")
print("LigParGen module path:", ligpargen.__file__)
PY

echo "[TEST] ligpargen command"
if command -v ligpargen >/dev/null 2>&1; then
  echo "OK: ligpargen found at $(command -v ligpargen)"
else
  echo "[ERR] ligpargen not in PATH after installation" >&2
  echo "[INFO] pip show ligpargen:" >&2
  python -m pip show ligpargen >&2 || true
  exit 4
fi

echo "[TEST] ligpargen help"
ligpargen -h >/dev/null 2>&1 && echo "OK: ligpargen -h works"

# -----------------------------
# 7) BOSSdir check
# -----------------------------
if [[ -z "${BOSSdir:-}" ]]; then
  echo "[WARN] BOSSdir is not set."
  echo "       LigParGen may fail during actual OPLS-AA parameter generation."
  echo "       Example:"
  echo "         export BOSSdir=/path/to/boss"
  echo "       Put it in ~/.bashrc if you want it persistent."
else
  if [[ -d "${BOSSdir}" ]]; then
    echo "[OK] BOSSdir is set: ${BOSSdir}"
  else
    echo "[WARN] BOSSdir is set but not a valid directory: ${BOSSdir}"
    echo "       Please check your ~/.bashrc entry."
  fi
fi

# -----------------------------
# 8) final summary
# -----------------------------
echo
echo "[DONE] LigParGen installation completed successfully."
echo "[DONE] To use it later:"
echo "       conda activate ${ENV_NAME}"
echo "       which ligpargen"
echo "       ligpargen -h"
