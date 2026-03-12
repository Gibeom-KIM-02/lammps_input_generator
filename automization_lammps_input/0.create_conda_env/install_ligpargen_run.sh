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
# 7) BOSSdir / runtime preflight check
# -----------------------------
echo "[TEST] BOSS preflight"

if [[ -z "${BOSSdir:-}" ]]; then
  echo "[WARN] BOSSdir is not set."
  echo "       LigParGen installation is complete, but real parameter generation"
  echo "       will fail unless BOSSdir is configured."
  echo "       Example:"
  echo "         export BOSSdir=/path/to/boss"
  echo '         export PATH="$BOSSdir/scripts:$PATH"'
  echo "       Put them in ~/.bashrc if you want them persistent."
else
  if [[ ! -d "${BOSSdir}" ]]; then
    echo "[ERR] BOSSdir is set but not a valid directory: ${BOSSdir}" >&2
    echo "      Please check your ~/.bashrc entry." >&2
    exit 5
  fi

  echo "[OK] BOSSdir is set: ${BOSSdir}"

  BOSS_BIN="${BOSSdir}/BOSS"
  BOSS_SCRIPTS_DIR="${BOSSdir}/scripts"

  if [[ ! -e "${BOSS_BIN}" ]]; then
    echo "[ERR] BOSS executable not found: ${BOSS_BIN}" >&2
    exit 6
  fi

  if [[ ! -x "${BOSS_BIN}" ]]; then
    echo "[ERR] BOSS exists but is not executable: ${BOSS_BIN}" >&2
    echo "      Fix example:" >&2
    echo "        chmod 755 \"${BOSS_BIN}\"" >&2
    exit 7
  fi

  if ! command -v csh >/dev/null 2>&1; then
    echo "[ERR] csh is not available in PATH." >&2
    echo "      LigParGen/BOSS helper scripts require csh." >&2
    exit 8
  fi

  if [[ ! -d "${BOSS_SCRIPTS_DIR}" ]]; then
    echo "[ERR] Missing BOSS scripts directory: ${BOSS_SCRIPTS_DIR}" >&2
    exit 9
  fi

  missing_root_files=()
  for f in oplsaa.par oplsaa.sb; do
    [[ -e "${BOSSdir}/${f}" ]] || missing_root_files+=("${BOSSdir}/${f}")
  done

  missing_script_files=()
  for f in xOPT xZCM1A xPDBZ xMOLZ OPTcmd OPLSpar; do
    [[ -e "${BOSS_SCRIPTS_DIR}/${f}" ]] || missing_script_files+=("${BOSS_SCRIPTS_DIR}/${f}")
  done

  if (( ${#missing_root_files[@]} > 0 )); then
    echo "[ERR] Missing required BOSS files:" >&2
    printf '      %s\n' "${missing_root_files[@]}" >&2
    exit 10
  fi

  if (( ${#missing_script_files[@]} > 0 )); then
    echo "[ERR] Missing required BOSS helper files:" >&2
    printf '      %s\n' "${missing_script_files[@]}" >&2
    exit 11
  fi

  nonexec_helpers=()
  for f in xOPT xZCM1A xPDBZ xMOLZ OPTcmd; do
    [[ -x "${BOSS_SCRIPTS_DIR}/${f}" ]] || nonexec_helpers+=("${BOSS_SCRIPTS_DIR}/${f}")
  done

  if (( ${#nonexec_helpers[@]} > 0 )); then
    echo "[ERR] Some BOSS helper scripts are not executable:" >&2
    printf '      %s\n' "${nonexec_helpers[@]}" >&2
    echo "      Fix example:" >&2
    echo "        chmod 755 \"${BOSS_SCRIPTS_DIR}\"/xOPT \"${BOSS_SCRIPTS_DIR}\"/xZCM1A \\" >&2
    echo "                  \"${BOSS_SCRIPTS_DIR}\"/xPDBZ \"${BOSS_SCRIPTS_DIR}\"/xMOLZ \\" >&2
    echo "                  \"${BOSS_SCRIPTS_DIR}\"/OPTcmd" >&2
    exit 12
  fi

  if command -v readelf >/dev/null 2>&1; then
    BOSS_INTERP="$(readelf -l "${BOSS_BIN}" 2>/dev/null | sed -n 's/.*Requesting program interpreter: \(.*\)\].*/\1/p' | head -n 1)"
    if [[ -n "${BOSS_INTERP}" ]]; then
      echo "[INFO] BOSS ELF interpreter: ${BOSS_INTERP}"
      if [[ ! -e "${BOSS_INTERP}" ]]; then
        echo "[ERR] Required ELF interpreter is missing: ${BOSS_INTERP}" >&2
        if [[ "${BOSS_INTERP}" == "/lib/ld-linux.so.2" ]]; then
          echo "      This usually means the system lacks 32-bit compatibility runtime." >&2
          echo "      Your BOSS binary is a 32-bit executable and cannot run on this node as-is." >&2
          echo "      Typical admin-side packages on CentOS 7 may include:" >&2
          echo "        glibc.i686  libgcc.i686  libstdc++.i686" >&2
        fi
        exit 13
      fi
    fi
  else
    echo "[WARN] readelf not found; skipping ELF interpreter check."
  fi

  # Make helper scripts reachable in the current shell
  export PATH="${BOSS_SCRIPTS_DIR}:${PATH}"

  # Runtime smoke test: nonzero exit code can be normal without input,
  # but loader / exec-format failures must be caught explicitly.
  BOSS_SMOKE_ERR="$(mktemp "${TMPDIR:-/tmp}/boss_smoke_XXXXXX.err")"
  set +e
  "${BOSS_BIN}" >/dev/null 2>"${BOSS_SMOKE_ERR}"
  BOSS_RC=$?
  set -e

  if grep -qi 'bad ELF interpreter' "${BOSS_SMOKE_ERR}"; then
    echo "[ERR] BOSS failed to start due to missing ELF interpreter:" >&2
    sed 's/^/      /' "${BOSS_SMOKE_ERR}" >&2
    rm -f "${BOSS_SMOKE_ERR}"
    exit 14
  fi

  if grep -qiE 'No such file or directory|cannot execute|Exec format error|Permission denied' "${BOSS_SMOKE_ERR}"; then
    echo "[ERR] BOSS failed the runtime smoke test." >&2
    sed 's/^/      /' "${BOSS_SMOKE_ERR}" >&2
    rm -f "${BOSS_SMOKE_ERR}"
    exit 15
  fi

  rm -f "${BOSS_SMOKE_ERR}"

  echo "[OK] BOSS preflight passed."
  echo "[INFO] BOSS binary could be invoked."
  echo "[INFO] Added \$BOSSdir/scripts to PATH for this install session."
fi

# -----------------------------
# 8) final summary
# -----------------------------
echo
echo "[DONE] To use it later:"
echo "       conda activate ${ENV_NAME}"
echo "       export BOSSdir=/path/to/boss"
echo '       export PATH="$BOSSdir/scripts:$PATH"'
echo "       which ligpargen"
echo "       ligpargen -h"
