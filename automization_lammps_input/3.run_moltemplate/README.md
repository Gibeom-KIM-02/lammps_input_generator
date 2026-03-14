# 3.run_moltemplate — YAML-driven `system.lt` Builder for Moltemplate/LAMMPS

This directory provides a **robust, YAML-configurable workflow** to generate a `system.lt` file (Moltemplate),
then run **Moltemplate** to produce LAMMPS-ready inputs (`system.data`, `system.in.init`, `system.in.settings`, ...).

- **All molecule/ion/solvent/slab LT files live in one place:** `input_files_lt/`
- **Geometry comes from an XYZ** (typically from PACKMOL / ASE): `input_files_structure/*.xyz`
- **System composition & instantiation order are controlled by YAML:** `config/molecules.yaml`
- **Global LAMMPS styles/settings can be injected via YAML (`config/settings.yaml`) or imported LT (`ff_custom.lt`)**

> **Note on monatomic ions**
>  
> LigParGen/BOSS-based LT generation is often not practical for monatomic ions.
> For ions such as `K_ion` and `Zn_ion`, you can generate minimal LT fragments using:
> `2.Monatomic_ion_2_lt/`

---

## Directory Layout

```text
3.run_moltemplate/
├── config/
│   ├── molecules.yaml              # system composition + LT paths + count rules + XYZ path
│   ├── molecules_yaml_help.md      # YAML guide (see also this README)
│   └── settings.yaml               # optional: global LAMMPS settings to inject into system.lt
│
├── input_files_lt/                 # ALL .lt fragments (molecules/ions/solvent/ff_custom)
│   ├── tip3p_2004_oplsaa2024.lt
│   ├── Methane.lt
│   └── ff_custom.lt                # optional: global styles in LT form (example)
│
├── input_files_structure/
│   └── waterTIP3P+methane.xyz      # XYZ coordinates (PACKMOL/ASE output)
│
├── make_system_lt.py               # generates system.lt from YAML + XYZ
├── README_run.sh                   # example end-to-end command sequence
└── README.md
```

---

## Quick Start

### 1) Prepare geometry (XYZ)
Put your packed structure in:
```bash
input_files_structure/<system>.xyz
```

### 2) Prepare LT fragments
Put all `.lt` fragments (molecules/ions/solvents/slabs and optional `ff_custom.lt`) in:
```bash
input_files_lt/
```

### 3) Configure `config/molecules.yaml`
Set:
- `global.xyz_file`
- molecule list (order matters!)
- `lt_path` and `class_name` for each component

### 4) Generate `system.lt`
```bash
python make_system_lt.py
```

### 5) Run Moltemplate
Make sure file path for `.xyz` is compatiable with yours.
```bash
moltemplate.sh -xyz input_files_structure/waterTIP3P+methane.xyz -atomstyle "full" system.lt
```

### 6) Copy outputs to your LAMMPS run directory
Following files are required to run `LAMMPS` MD simulation: `system.data`, `system.in.init`, `system.in.settings`, etc. 

---

## Configuration

### `config/molecules.yaml`

Key ideas:
- **Order-preserving**: the order under `molecules:` is used as the instantiation order in `system.lt`.
- `count_rule` is a Python expression evaluated with:
  - `elem`: element counts in the XYZ (e.g., `elem['S']`, `elem['Zn']`)
  - `mol`: molecule counts already resolved (to support dependencies)

Example (simplified):

```yaml
global:
  xyz_file: "input_files_structure/waterTIP3P+methane.xyz" 
  output_lt: "system.lt"
  extra_imports:
    - "input_files_lt/ff_custom.lt"

molecules:
  TIP3P_water:
    instance_name: water
    lt_path: "input_files_lt/tip3p_2004_oplsaa2024.lt"  
    class_name: "TIP3P"                           
    count_rule: "elem['O']"

  Methane:
    instance_name: Methane
    lt_path: "input_files_lt/Methane.lt"         
    class_name: "Methane"                        
    count_rule: "elem['C']"
```

> **Important:** `charge` is currently a **note field** (not automatically enforced).  
> Always verify net charge / counter-ions manually.

---

## Global Force Field Settings via `ff_custom.lt`

You can import a custom LT fragment that defines global styles:

- Place `ff_custom.lt` in `input_files_lt/`
- Add it to `global.extra_imports` in `molecules.yaml`

Example (`input_files_lt/ff_custom.lt`):

```lt
write_once("In Init") {
  units           real
  atom_style      full
  bond_style      harmonic
  angle_style     harmonic
  dihedral_style  opls
  improper_style  cvff
  pair_style      lj/cut/coul/long 11.0 11.0
  pair_modify     mix geometric
  special_bonds   lj/coul 0.0 0.0 0.5
  kspace_style    pppm 1.0e-4
}
```

---

## Critical: Molecule Order Must Match XYZ Order

Moltemplate assigns coordinates **strictly in sequence**:
1) takes the **first** instantiated object in `system.lt`,
2) consumes the first block of atoms from the XYZ,
3) then moves to the next object, and so on.

If the order in `config/molecules.yaml` differs from the order in your XYZ,
atoms get mapped to the wrong templates → errors or nonsense structures.

### Safe workflow
- Keep your XYZ-generation script and `molecules.yaml` in the same commit.
- After repacking/reordering species, update YAML immediately.

---

## Outputs (Generated Files)

After running:
1) `python make_system_lt.py`
2) `moltemplate.sh ... system.lt`

you will see generated outputs such as:

- `system.lt` — generated by `make_system_lt.py`
- `system.data` — generated by Moltemplate
- `system.in.init`, `system.in.settings` — generated by Moltemplate
- `output_ttree/` — Moltemplate intermediate directory (templates/assignments)

These files are considered **build artifacts** and may be overwritten on rerun.

---

## Troubleshooting

- **Moltemplate “file not found”**
  - Check `import "input_files_lt/..."` paths in `system.lt`
  - Run Moltemplate from the directory where those relative paths are valid

- **Wrong mapping / weird chemistry**
  - 99% of the time it's **XYZ ordering vs YAML ordering** mismatch

- **Counts look wrong**
  - `count_rule` must return an integer
  - Verify element keys match XYZ (e.g., `Zn`, `K`, `S`)

---

## Credits

Please cite or acknowledge the following tools as appropriate:

- LigParGen
- Moltemplate
- ltemplify.py
- Packmol
- ASE (Atomic Simulation Environment)

Custom workflow scripting and post-processing are repository-specific.

---

## License

The original code and workflow assembly in this repository are distributed under the **MIT License**.

Copyright (c) 2025 Gibeom Kim, THEMMES Group

This repository may invoke or rely on third-party software distributed under their own licenses, including Moltemplate, LigParGen, Packmol, and ASE. Those components remain the property of their respective authors and are subject to their original license terms.

- Moltemplate — MIT License  
  Copyright (c) 2013, Andrew Jewett, University of California Santa Barbara

- LigParGen — MIT License  
  Copyright (c) 2020 Israel Cabeza de Vaca Lopez

- Packmol — MIT License  
  Please cite the Packmol reference(s) below when the software is used in published work.

- ASE (Atomic Simulation Environment) — GNU LGPL v2.1 or later  
  Please cite the ASE reference below when the software is used in published work.
