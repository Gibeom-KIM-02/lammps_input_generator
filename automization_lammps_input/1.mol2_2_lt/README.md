# 1.mol2_2_lt Workflow

This repository provides an **automated workflow** for converting `.mol2` files into LAMMPS-ready Moltemplate `.lt` files with **custom forcefield types**.  
It uses [LigParGen](https://zarbi.chem.yale.edu/ligpargen/) for OPLS-AA parameterization, [ltemplify.py](https://moltemplate.org/), and a **post-processing script** that allows you to assign chemical-type names to atoms, bonds, angles, etc.

---

## 📁 Directory Structure

1.mol2_2_lt/  
├── input_files/ # Input .mol2 molecules  
│ ├── CO2.mol2  
│ └── sulfate.mol2  
│  
├── lt/ # Output: processed .lt files (created automatically)  
│ ├── CO2.lt  
│ └── sulfate.lt  
│  
├── ff_out/ # LigParGen output files (auto-generated)  
│  
├── config/  
│ ├── molecules.yaml # Molecule charge/residue config  
│ └── charges.yaml   # Per-atom charge config  
│  
├── type_name/ # (Optional) Custom type naming for molecules (yaml)  
│ ├── co2.yaml  
│ └── sulfate.yaml  
│  
├── scripts/  
│ ├── run_ligpargen_all.sh # Main batch script (bash)  
│ └── lt_postprocess.py    # LT postprocessing (python)  
│  
├── README.md  
└── README_run.sh

---

## Quick Start

1. **Put .mol2 files in `input_files/`**
2. **Configure `config/molecules.yaml` `config/charges.yaml`** (see below)
3. **(Optional) Add custom naming yaml in `type_name/`**  
   e.g., `type_name/co2.yaml`
4. **(Optional) Set up per-atom charges in `config/charges.yaml`**  
   (see below for format)
5. **Run:**
    ```bash
    bash README_run.sh
    ```
   All processed `.lt` files will appear in `lt/`.

## 🛠 Script Details

### scripts/run_ligpargen_all.sh

- Runs LigParGen, ltemplify.py, and lt_postprocess.py for each `.mol2` in `input_files/`.
- Looks up each molecule's charge and residue in `config/molecules.yaml`.
- Overwrites atomic charges using `config/charges.yaml` if provided.
- Writes all final `.lt` files to the `lt/` directory.
- See `README_run.sh` for a manual run example.

---

## Example: `config/molecules.yaml` 

```yaml
molecules:
  CO2:
    res: CO2
    charge: 0
  sulfate:
    res: SO4
    charge: -2
```

## Example: `config/charges.yaml` (Optional: Per-Atom Charge Assignment)
You can provide per-atom charges for each molecule by editing config/charges.yaml.
This file lets you overwrite the charge column in the .lt files, ensuring your force field is consistent with literature or your own conventions.

YAML Format:
- Each top-level key (e.g., CO2, sulfate) matches the .mol2 file name (case-sensitive).
- Each block maps atomtype names (as used in the .lt file after type renaming) to charge values.

```
CO2:
  CO2_C: 0.700
  CO2_O1: -0.350
  CO2_O2: -0.350

sulfate:
  SO4_S:   1.472219
  SO4_O1: -0.868055
  SO4_O2: -0.868055
  SO4_O3: -0.868055
  SO4_O4: -0.868055
```

- If a molecule or atomtype is not listed, the original charge is used.
- You only need to specify atomtypes you want to override.

## (Optional) Set Up Custom Type Naming
If you want atoms/bonds/angles named chemically (e.g., CO2_C), create a YAML file in `type_name/:File`: `type_name/co2.yaml`

Example:

```
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

- Naming follows typeN mapping as used by LigParGen/ltemplify output.

---

📝 Manual Test Example
See `README_run.sh` for a step-by-step example of running the pipeline for a single molecule.

🛠 Script Details
scripts/run_ligpargen_all.sh

Main batch script:
1. Reads .mol2 files from input_files/
2. Looks up settings in `config/molecules.yaml`
3. Runs LigParGen (ff_out/ is the output)
4. Converts LAMMPS data to .lt.tmp using ltemplify.py
5. Calls lt_postprocess.py to apply type naming and (optionally) charges
6. Outputs .lt files (with custom names if YAML present)

scripts/lt_postprocess.py
- Python script for post-processing .lt.tmp files.
- If a matching YAML (type_name/<mol>.yaml) exists, atom/bond/angle/… types will be renamed as specified.
- If `config/charges.yaml` is present, per-atom charges will be assigned/overwritten.
- Otherwise, types are named as <PREFIX>_typeN by default.
- Produces modular, clean, Moltemplate-compatible .lt files.

🧪 Adding a New Molecule
1. Place your `molecule.mol2` in input_files/
2. Add an entry to `config/molecules.yaml` (res, charge)
3. (Optional) Add `type_name/molecule.yaml` for chemical-type naming
4. (Optional) Add per-atom charges to `config/charges.yaml`
5. Run the pipeline script


🔗 Requirements

- LigParGen (should be on PATH)
- ltemplify.py (should be on PATH)
- python3, pyyaml, yq for YAML parsing (install with pip install pyyaml yq)
- Bash shell

Example Output (CO2.lt)
With a custom type_name/co2.yaml and per-atom charges in config/charges.yaml, you’ll see:

```
import oplsaa2024.lt

CO2 inherits OPLSAA {

  write_once("In Init") {
    atom_style full
  }

  write_once("In Settings") {
    pair_coeff @atom:CO2_C @atom:CO2_C 0.066 3.3000000
    pair_coeff @atom:CO2_O1 @atom:CO2_O1 0.210 2.9600000
    bond_coeff @bond:CO2_C_O 700.0000 1.1680
    angle_coeff @angle:CO2_O_C_O 160.000 180.000
  }
  ...
}

```

📚 Tips & Troubleshooting

- If a molecule’s types are not renamed chemically, check:
	- The YAML file name and location (type_name/<mol>.yaml, all lowercase)
	- The typeN indices match those in the .lt.tmp file

- If charges are not overwritten, check:
	- The atomtype names in config/charges.yaml exactly match those in the output .lt file (after type renaming)
	- The molecule key matches the .mol2 filename

- To customize more types, add more entries in the YAML (type4: ... etc.)
- To debug, you can run lt_postprocess.py manually on a single molecule

📢 License
- MIT License (or your choice).
- Please cite LigParGen and Moltemplate as appropriate for published work.

✨ Credits
- LigParGen
- Moltemplate
- Custom scripting: [Your Name / Lab / Organization]

