# 0.create_conda_env — `ligpargen_run` Conda Environment

Minimal setup to create/update a Conda env for the LigParGen-based workflows in this repository.

## Files

- `ligpargen_run.yml`  
  Conda environment spec (Python 3.7 + rdkit/openbabel/moltemplate/yq/pyyaml, etc.)
- `install_ligpargen_run.sh`  
  One-shot installer that:
  1) creates/updates the env from YAML  
  2) installs LigParGen from a pinned Git commit (reproducible)  
  3) runs sanity checks (OpenBabel `pybel`, `ligpargen` in PATH, `BOSSdir`)

---

## Quick Start

From this directory:

```bash
bash install_ligpargen_run.sh
# or (explicit YAML)
bash install_ligpargen_run.sh ligpargen_run.yml
```

Activate later with:

```bash
conda activate ligpargen_run
```

---

## Notes

### 1) `BOSSdir` is required for real OPLS-AA parameter generation
LigParGen typically needs a BOSS installation path:

```bash
export BOSSdir=/path/to/boss
# put in ~/.bashrc if you want it persistent
```

### 2) Change LigParGen source / version (optional)
The installer supports environment variables:

```bash
# use latest main (less reproducible)
export LIGPARGEN_REF=main

# or your own fork
export LIGPARGEN_URL=https://github.com/<user>/ligpargen.git
export LIGPARGEN_REF=<branch-or-commit>
bash install_ligpargen_run.sh
```

### 3) Requirements
- `conda` must be available on PATH (Miniconda/Anaconda initialized)
