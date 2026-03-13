# LAMMPS Moltemplate + LigParGen Workflow

This repository provides an automated workflow to convert molecular input files into **LAMMPS-ready Moltemplate `.lt` files**.

The workflow uses:

- **LigParGen** for OPLS-AA parameter generation
- **ltemplify.py** for converting LAMMPS data into Moltemplate format
- A custom **post-processing Python script** for:
  - renaming atom/bond/angle/dihedral/improper types
  - optionally overriding atomic charges
  - reorganizing the final `.lt` file into a cleaner Moltemplate-friendly structure

---

## Overview

For each molecule in `input_files/`, the workflow:

1. Reads molecule settings from `config/molecules.yaml`.
2. Runs LigParGen using either:
   - the input `.mol2` file, or
   - a SMILES string if provided in the YAML.
3. Converts LigParGen's LAMMPS output into a temporary `.lt` file.
4. Post-processes the `.lt` file to:
   - rename force-field types using `type_name/*.yaml` if available.
   - override atomic charges using `config/charges.yaml` if available.
5. Writes the final `.lt` file to `lt/`.

---

## Directory Structure

```text
1.mol2_2_lt/
├── config/
│   ├── molecules.yaml
│   ├── charges.yaml
│   └── note.txt
│
├── input_files/
│   ├── 1-Butyl-1-methylpyrrolidinium_plus.mol2
│   ├── Benzene.mol2
│   ├── CO2.mol2
│   ├── Ethylene.mol2
│   ├── Imidodisulfurylfluoride_minus.mol2
│   ├── Methane.mol2
│   └── sulfate.mol2
│
├── scripts/
│   ├── run_ligpargen_all.sh
│   └── lt_postprocess.py
│
├── type_name/
│   ├── CO2.yaml
│   └── sulfate.yaml
│
├── README.md
├── README_run.sh
└── __init__.py
```

The following directories are created automatically when the workflow runs:
- `ff_out/` - LigParGen output files
- `lt/` - Final processed Moltemplate `.lt` files

---

## Requirements

The following commands/packages must be available:
- `ligpargen`
- `ltemplify.py`
- `yq` (This workflow expects the `mikefarah/yq` CLI)
- `python` with `pyyaml`

**Runtime checks already built into the script:** `scripts/run_ligpargen_all.sh` checks for `ligpargen`, `ltemplify.py`, and `yq`. If any of them is missing, the script exits with an error.

---

## Quick Start

1. Put your `.mol2` files in `input_files/`.
2. Edit `config/molecules.yaml`.
3. Optionally add:
   - `type_name/<molecule>.yaml`
   - `config/charges.yaml`
4. Run the workflow:

```bash
bash README_run.sh
# or equivalently:
# bash ./scripts/run_ligpargen_all.sh
```

Final processed `.lt` files will be written to the `lt/` directory.

---

## Configuration: `config/molecules.yaml`

This is the main control file for the workflow. Each molecule key should match the input filename stem exactly.
For example:
- `CO2.mol2` → key should be `CO2`
- `sulfate.mol2` → key should be `sulfate`

### Supported fields:
- `res`: Residue name passed to LigParGen (`-r`)
- `charge`: Net molecular charge passed to LigParGen (`-c`)
- `optimize`: LigParGen optimization level (`-o`). Expected range: `0 ~ 3`
- `smiles` (optional): If present, the workflow uses the SMILES route instead of the `.mol2` route.

### Example:

```yaml
molecules:
  CO2:
    res: CO2
    charge: 0
    optimize: 0

  sulfate:
    res: SO4
    charge: -2
    optimize: 1

  Benzene:
    res: C6H6
    charge: 0
    optimize: 3

  1-Butyl-1-methylpyrrolidinium_plus:
    res: 1-Butyl-1-methylpyrrolidinium_plus
    charge: +1
    smiles: "CCCC[N+]1(CCCC1)C"
    optimize: 2
```

### Notes:
- If `optimize` is omitted, the script uses `optimize: 0`.
- If `smiles` exists and is not empty, the script uses `ligpargen -s "<SMILES>" ...` instead of `ligpargen -i "<mol2 file>" ...`.
- If `charge` is written as `+1`, the leading `+` is safely stripped before passing it to LigParGen.

---

## Optional Type Renaming: `type_name/*.yaml`

You can assign chemically meaningful names to force-field types. If a matching YAML file exists, `lt_postprocess.py` replaces generic type labels such as `@atom:type1`, `@bond:type1`, `@angle:type1` with user-defined names such as `@atom:CO2_C`, `@bond:CO2_C_O`, `@angle:CO2_O_C_O`.

### Example: `type_name/CO2.yaml`

```yaml
atom:
  type1: CO2_C
  type2: CO2_O1
  type3: CO2_O2

bond:
  type1: CO2_C_O
  type2: CO2_C_O

angle:
  type1: CO2_O_C_O
```

### Example: `type_name/sulfate.yaml`

```yaml
atom:
  type1: SO4_S
  type2: SO4_O1
  type3: SO4_O2
  type4: SO4_O3
  type5: SO4_O4

bond:
  type1: SO4_S_O
  type2: SO4_S_O
  type3: SO4_S_O
  type4: SO4_S_O

angle:
  type1: SO4_O_S_O
  type2: SO4_O_S_O
  type3: SO4_O_S_O
  type4: SO4_O_S_O
  type5: SO4_O_S_O
  type6: SO4_O_S_O
```

### File lookup behavior
`lt_postprocess.py` searches for the type-name YAML in this order:
1. `type_name/<mol>.yaml`
2. `type_name/<mol.lower()>.yaml`

Exact filename matching is preferred, but lowercase fallback is supported.

### If no type-name YAML exists
The script automatically generates default names using `<PREFIX> = molecule name in uppercase + "_"`. For example: `@atom:BENZENE_type1`, `@bond:BENZENE_type1`.

---

## Optional Charge Override: `config/charges.yaml`

You can override atom charges in the final `.lt` file after type renaming. This is useful when you want literature-based charges, enforce your own charge convention, or do not want to use LigParGen charges as-is.

### Example:

```yaml
CO2:
  CO2_C: 0.700
  CO2_O1: -0.350
  CO2_O2: -0.350

sulfate:
  SO4_S: 1.472219
  SO4_O1: -0.868055
  SO4_O2: -0.868055
  SO4_O3: -0.868055
  SO4_O4: -0.868055
```

### Matching rules:
- The top-level key should match the molecule name.
- The inner keys should match the **renamed** atom type names.
- Only listed atom types are overridden. If a molecule block or atom type is missing, the original charge is kept.

### Charge lookup behavior
`lt_postprocess.py` uses exact molecule-key match first, and case-insensitive fallback second. If only a case-insensitive match is found, the script prints a warning. Exact matching is recommended for long-term consistency.

---

## How the Main Script Works

### `scripts/run_ligpargen_all.sh`
This is the main batch driver. For every `.mol2` file in `input_files/`, it:
1. Extracts:
- molecule name
- residue name
- net charge
- optional SMILES
- optimization level
2. Runs LigParGen.
3. Converts the generated `.lammps.lmp` file into `.lt.tmp`.
4. Runs `lt_postprocess.py`.
5. Writes the final `.lt` file to `lt/`.

For molecule `CO2`, the script creates:
```text
ff_out/CO2/CO2.lammps.lmp
ff_out/CO2/CO2.lt.tmp
lt/CO2.lt
```

---

## Post-Processing Details

### `scripts/lt_postprocess.py`
This script reads the temporary `.lt.tmp` file, renames force-field types, optionally overrides atom charges, and reorganizes sections into:
- In Init
- In Settings
- Data Masses
- Data Atoms
- Data Bonds
- Data Angles
- Data Dihedrals
- Data Impropers

### Root-directory behavior
The script resolves paths using its own file location, making it robust even if you run the workflow from another working directory:
```python
SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent
```

**Important detail:** The molecule name is inferred from the output filename (`lt/<mol>.lt`), so the naming convention across the workflow should remain consistent.

---

## Example Run

```bash
bash README_run.sh
```

**Example terminal output:**
```text
▶ Processing /path/to/input_files/CO2.mol2
• Using MOL2 route
• LigParGen optimize count = 0
...
✅ /path/to/lt/CO2.lt generated
```

For a molecule with a SMILES entry:
```text
▶ Processing /path/to/input_files/1-Butyl-1-methylpyrrolidinium_plus.mol2
• Using SMILES route
• LigParGen optimize count = 2
...
✅ /path/to/lt/1-Butyl-1-methylpyrrolidinium_plus.lt generated
```

---

## Adding a New Molecule

To add a new molecule:
1. Place `your_molecule.mol2` in `input_files/`.
2. Add an entry to `config/molecules.yaml`.
3. Optionally add `type_name/your_molecule.yaml` and a charge block in `config/charges.yaml`.
4. Run the workflow.

**Minimal example (`config/molecules.yaml`):**
```yaml
molecules:
  your_molecule:
    res: YRM
    charge: 0
    optimize: 0
```

---

## Recommended Naming Convention

For long-term maintenance, it is best to keep these identifiers consistent:
- `input_files/<stem>.mol2`
- `config/molecules.yaml` key = `<stem>`
- `config/charges.yaml` key = `<stem>`
- `type_name/<stem>.yaml`

**Example:**
- `CO2.mol2`
- Key `CO2` in `molecules.yaml`
- Key `CO2` in `charges.yaml`
- File `type_name/CO2.yaml`

The workflow includes fallback logic for some case mismatches, but exact matching is strongly recommended.

---

## Troubleshooting

1. **Molecule entry not found in `molecules.yaml`** If you see `Entry for '<mol>' not found in molecules.yaml`, check that the `.mol2` filename stem matches the YAML key exactly, and that `res` and `charge` are present.
2. **Invalid optimize value** If you see `Invalid optimize value for '<mol>'`, make sure `optimize` is an integer (e.g., `0`, `1`, `2`, `3`).
3. **Type renaming did not happen** Check that the YAML file exists in `type_name/`, the filename matches the molecule name, and the indices (`type1`, `type2`, etc.) match those produced by LigParGen/ltemplify.
4. **Charges were not overridden** Check that the molecule key exists in `config/charges.yaml`, the atom-type names exactly match the renamed atom types in the final `.lt`, and the type renaming happened as expected.
5. **`yq` not found** This workflow expects the CLI version of `yq`. If `yq` is missing, install the `mikefarah/yq` binary and make sure it is on your `PATH`.

---

## Notes

- `README_run.sh` is only a small wrapper for `bash ./scripts/run_ligpargen_all.sh`.
- `ff_out/` and `lt/` are created automatically.
- If charge override is not provided, LigParGen charges remain unchanged.
- If type-name YAML is not provided, default prefixed type names are used.

---

## Credits

Please cite or acknowledge the following tools as appropriate:
- LigParGen
- Moltemplate
- ltemplify.py

Custom workflow scripting and post-processing are repository-specific.

## License

The original code and workflow assembly in this repository are distributed under the **MIT License**.

Copyright (c) 2025 Gibeom Kim, THEMMES Group

This repository may invoke or rely on third-party software distributed under their own licenses, including Moltemplate and LigParGen. Those components remain the property of their respective authors and are subject to their original license terms.

- Moltemplate — MIT License  
  Copyright (c) 2013, Andrew Jewett, University of California Santa Barbara

- LigParGen — MIT License  
  Copyright (c) 2020 Israel Cabeza de Vaca Lopez
