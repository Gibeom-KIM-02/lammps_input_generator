# 0.create_conda_env — `ligpargen_run` Conda Environment

Create/update a Conda environment for the LigParGen-based workflows in this repository.

This installer does more than just install Python packages:
1. creates or updates the Conda environment from YAML
2. installs LigParGen from a pinned Git commit for reproducibility
3. runs sanity checks for Python imports and CLI availability
4. runs a BOSS preflight check (if BOSSdir is set) to catch runtime problems early

---

## Files

- **ligpargen_run.yml** Conda environment specification (Python 3.7, rdkit, openbabel, pyyaml, moltemplate, go-yq, etc.)

- **install_ligpargen_run.sh** One-shot installer that:
  - creates/updates the environment
  - installs LigParGen from a pinned Git commit
  - verifies:
    - Python version
    - `from openbabel import pybel`
    - `import ligpargen`
    - `ligpargen` command in PATH
    - `ligpargen -h`
  - checks BOSS runtime readiness when `BOSSdir` is defined

---

## Quick Start

From this directory:
```bash
bash install_ligpargen_run.sh
# or explicitly
bash install_ligpargen_run.sh ligpargen_run.yml
```

Activate later with:
```bash
conda activate ligpargen_run
```

---

## BOSS Setup

LigParGen installation itself does not require BOSS to be runnable, but **actual OPLS-AA parameter generation does.**

Set the BOSS installation path before running LigParGen:
```bash
export BOSSdir=/path/to/boss
export PATH="$BOSSdir/scripts:$PATH"
```
If you want this to persist across sessions, add those lines to `~/.bashrc`.

### What the installer checks for BOSS
If `BOSSdir` is set, the installer performs a preflight check for:
* valid `BOSSdir`
* BOSS executable existence
* execute permission on BOSS
* `csh` availability
* required BOSS helper scripts under `"$BOSSdir/scripts"`
* execute permissions on helper scripts
* ELF interpreter availability
* basic BOSS runtime smoke test

This is intended to fail early with a clear message if the node cannot actually run BOSS.

### Typical HPC issue: missing 32-bit runtime
Some BOSS binaries are old 32-bit Linux executables. On certain HPC systems, the installer may stop with an error like:

```text
[INFO] BOSS ELF interpreter: /lib/ld-linux.so.2
[ERR] Required ELF interpreter is missing: /lib/ld-linux.so.2
      This usually means the system lacks 32-bit compatibility runtime.
```

This means:
1. LigParGen was installed successfully
2. but the system cannot execute the BOSS binary
3. so real LigParGen parameter generation will fail on that node

Typical admin-side packages on CentOS 7 may include:
* `glibc.i686`
* `libgcc.i686`
* `libstdc++.i686`

If you see this error on a cluster, contact the system administrator.

---

## Expected outcomes

- **Case 1 — BOSSdir not set**: The installer completes, but prints a warning that BOSS is not configured.
- **Case 2 — BOSSdir set and BOSS is runnable**: The installer completes and reports: `[OK] BOSS preflight passed.`
- **Case 3 — BOSSdir set but BOSS runtime is broken**: The installer stops with a clear diagnostic message explaining what is missing.

---

## Change LigParGen source / version (optional)

The installer supports environment variables:
```bash
# use a different branch or commit
export LIGPARGEN_REF=main

# use your own fork
export LIGPARGEN_URL=https://github.com/<user>/ligpargen.git
export LIGPARGEN_REF=<branch-or-commit>

bash install_ligpargen_run.sh
```

---

## Requirements

- `conda` must be available on PATH
- shell initialization for conda must work
- internet access is needed to clone LigParGen from GitHub
- **BOSS** is required for real parameter generation
- some systems may additionally need 32-bit compatibility runtime for BOSS

To obtain the **BOSS** program, please visit the
[Yale Chem BOSS software page](https://zarbi.chem.yale.edu/software.html).

### Recommended shell setup
Example `~/.bashrc` snippet:
```bash
export BOSSdir=/path/to/boss
export PATH="$BOSSdir/scripts:$PATH"
```
Then reload:
```bash
source ~/.bashrc
```

### Minimal usage check after installation
```bash
conda activate ligpargen_run
which ligpargen
ligpargen -h
```
If BOSS is available and runnable, you can then proceed to actual LigParGen workflows.
