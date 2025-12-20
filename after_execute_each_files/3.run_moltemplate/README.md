# run_moltemplate: Automated Moltemplate System Builder

This project provides a robust, YAML-configurable workflow for building `system.lt` files  
used with [moltemplate](https://moltemplate.org/) and [LAMMPS](https://lammps.org/).  
System and global simulation parameters are cleanly separated via a `config/` folder.
Finally, by running moltemplate, this directory generates input files for lammps run.

---

## 📦 Directory Structure Example
```
run_moltemplate/   
├── make_system_lt.py # Python automation script to make system.lt   
├── config/   
│ ├── molecules.yaml # Main molecule & system config (YAML)   
│ └── settings.yaml # All global force field & LAMMPS settings   
├── molecules_yaml_help.md # Detailed YAML help (optional)   
├── README.md # This file   
├── README_run.sh # Example run script (contains moltemplate run)   
│   
├── input_files_structure/   
│ └── Ag_sulfate_CO2_solvated.xyz   
│   
├── input_files_lt/   
│ ├── CO2.lt   
│ ├── sulfate.lt   
│ └── tip3p_2004_oplsaa2024.lt   
│   
└── input_files_lt_adsorbent/   
└── Ag.lt   
```

---

## 🚀 Workflow

1. **Prepare your structure**
    - Build your system with PACKMOL/ASE and export as `.xyz`.
    - Place the structure file in `input_files_structure/`.

2. **Prepare your .lt files**
    - Place all molecule/ion/solvent `.lt` files in `input_files_lt/`.
    - Place slab/adsorbent `.lt` files in `input_files_lt_adsorbent/`.

3. **Edit `config/molecules.yaml`**
    - Define each component: file paths, class names, and molecule count rules.
    - See `molecules_yaml_help.md` for full format and options.

4. **Edit `config/settings.yaml`**
    - Define all global simulation and force-field settings (pair_style, kspace_style, etc.).
    - Any LAMMPS command supported in `write_once("In Settings"){}` can go here.

5. **Generate `system.lt`**
    ```bash
    python make_system_lt.py
    ```

6. **Run moltemplate to build LAMMPS inputs**
    ```bash
    moltemplate.sh -xyz input_files_structure/Ag_sulfate_CO2_solvated.xyz -atomstyle "full" system.lt
    ```

7. **(Optional) Visualize or check the generated files before simulation.**

---

## ⚠️ Important: .lt File Import Paths

- The `import` lines in `system.lt` use **relative paths** (e.g., `import input_files_lt/CO2.lt`).
- If you move your `system.lt` or run `moltemplate.sh` from a different directory, you may need to adjust these paths manually.
- Always double-check import paths if you see errors like `"file not found"` when running moltemplate!

---

## ⚠️ Critical: Keep `molecules:` Order Aligned with Your XYZ File

When you invoke **`moltemplate.sh -xyz … system.lt`**, **Moltemplate assigns
coordinates strictly in sequence**:

1. It imports the first molecule definition in `system.lt`,
2. Instantiates it with `new …`,
3. Grabs the first block of atoms from the XYZ file,  
   and repeats for the next molecule.

If the order in **`config/molecules.yaml` → `molecules:`** and the order of
molecules in the **XYZ file** diverge, atoms will be mapped to the
wrong templates—yielding either cryptic Moltemplate errors _or_ chemically
impossible structures.

### ✅ How to stay safe

| Step | Action |
|------|--------|
| **1. Inspect the XYZ** | Identify the exact sequence of molecule blocks, e.g.<br>`Ag  →  CO₂  →  H₂O  →  SO₄²⁻`. |
| **2. Mirror that order in `molecules.yaml`** | The YAML mapping is order-preserving. Arrange molecules exactly as in the XYZ:<br>```yaml<br>molecules:<br>  AgSlab:   …<br>  CO2:      …<br>  TIP3P_2004: …  # water<br>  Sulfate:  …<br>``` |
| **3. Re-check after every repack** | If you shuffle, add, or remove species in PACKMOL / ASE, update the YAML list **before** running `make_system_lt.py`. |

> **Pro-tip:** Keep your XYZ-generation script and `molecules.yaml` under
> the same version-control commit so the two files never drift out of sync.

---

## ⚙️ Configuration Tips

- **Atom Order**:  
  The atom order in your `.xyz` must match the instantiation order in `system.lt`.
  This is controlled by the order of `molecules:` in `molecules.yaml`.
- **Molecule Counting**:  
  Use Python expressions in `count_rule` for each molecule.
  Slabs/adsorbents can be auto-counted from their `.lt` files.
- **Settings Control**:  
  `settings.yaml` lets you configure all LAMMPS global settings (e.g., `pair_style`, `kspace_style`, `units`, `bond_style`, etc.).
  Use a YAML dict for multi-argument commands, or a string for simple cases.
- **Extending**:  
  To add new molecules, copy-paste a block in `molecules.yaml`, specify the path/class, and define `count_rule`.
  You can add multiple slabs or other custom objects with their own settings.
- **Custom Fixes**:  
  For slabs, use `fixed_group` to define which atoms are immobilized.

---

📝 **Example: Adding a New Ion**

```yaml
  NaPlus:
    lt_path: "input_files_lt/Na.lt"
    class_name: "Na"
    count_rule: "elem['Na']"
    charge: +1

❗ Troubleshooting

If atom counts are wrong or a molecule is missing, check your count_rule expressions and .lt file class names.

If you get LAMMPS errors about missing pair_coeff/bond_coeff, ensure your .lt files and force-field settings are consistent.

If your simulation parameters are not being set as expected, check config/settings.yaml and ensure commands are written as shown in the help.

📖 Further Reading

See molecules_yaml_help.md for full YAML key documentation and advanced tips.

Moltemplate documentation: https://moltemplate.org/

LAMMPS documentation: https://lammps.org/doc/Manual.html
