# 2.Monatomic_ion_2_lt — Monatomic Ion → Moltemplate (.lt) Generator (Optional)

This directory provides a **minimal workflow** to generate **Moltemplate-ready `.lt` files** for **monatomic ions** (e.g., K⁺, Zn²⁺) from a simple YAML parameter table.

> **Why this exists**
>  
> For *monatomic ions*, generating LT files via **LigParGen/BOSS**-based pipelines is often **not practical / not meaningful**, because there is no bonded topology to parameterize and you typically want to **manually control charge and LJ parameters** (often from literature or your own convention).  
> So you should either:
> 1) **Write the ion `.lt` manually**, or  
> 2) Use this folder (`2.Monatomic_ion_2_lt`) to **auto-generate** clean `.lt` files from `config/ions.yaml`.

---

## Directory Structure

```text
2.Monatomic_ion_2_lt/
├── config/
│   └── ions.yaml          # ion parameters (mass/charge/LJ)
├── input_files/
│   ├── K_ion.mol2
│   └── Zn_ion.mol2        # simple 1-atom mol2 placeholders
├── lt/
│   ├── K_ion.lt
│   └── Zn_ion.lt          # generated outputs
├── scripts/
│   └── make_monatomic_ion_2_lt.py
└── README_run.sh
```

---

## Quick Start

1) Put ion `.mol2` files in `input_files/`
- The file should contain **exactly one atom** (no bonds).
- Filename (without extension) must match the YAML key in `config/ions.yaml`.
  - Example: `input_files/K_ion.mol2` ↔ `ions: K_ion: ...`

2) Edit `config/ions.yaml`
- Required: `atom_label`, `mass`, `charge`
- Optional: `lj.sigma_A`, `lj.epsilon_kcal`

3) Run:

```bash
bash README_run.sh
```

4) Output `.lt` files will be created in `lt/`.

---

## Config Format (`config/ions.yaml`)

Example:

```yaml
ions:
  K_ion:
    res: K_ion
    atom_label: K
    mass: 39.0983
    charge: 0.8
    lj:
      sigma_A: 5.17
      epsilon_kcal: 0.0005

  Zn_ion:
    res: Zn_ion
    atom_label: Zn
    mass: 65.38
    charge: 1.6
    lj:
      sigma_A: 1.960
      epsilon_kcal: 0.0125
```

**Notes**
- `ions.<key>` must match `input_files/<key>.mol2`
- Units:
  - `mass`: amu  
  - `charge`: e  
  - `lj.sigma_A`: Å  
  - `lj.epsilon_kcal`: kcal/mol  

---

## What Gets Generated

Each ion `.lt` contains:
- `Data Masses` entry for the ion
- `Data Atoms` with a single atom at `(0,0,0)` and the specified charge
- `pair_coeff` **only if** both `sigma_A` and `epsilon_kcal` are provided  
  - If LJ is omitted in YAML, the script skips `pair_coeff` (assume an upper-level force field provides it)

Example output pattern:

```lt
K_ion {
  write_once("In Settings") {
    pair_coeff @atom:K @atom:K 0.000500 5.170000
  }
  write_once("Data Masses") {
    @atom:K 39.098300
  }
  write("Data Atoms") {
    $atom:K  $mol:.  @atom:K   0.800000     0.0  0.0  0.0
  }
}
```

---

## Adding a New Ion

1) Add `input_files/<NewIon>.mol2` (one atom only)  
2) Add an entry to `config/ions.yaml`:

```yaml
ions:
  NewIon:
    atom_label: X
    mass: ...
    charge: ...
    lj:
      sigma_A: ...
      epsilon_kcal: ...
```

3) Run:

```bash
bash README_run.sh
```

---

## Tips / Troubleshooting

- **Skipped because no YAML entry**
  - Add the ion under `ions:` with the same key as the `.mol2` filename stem.
- **Want to omit LJ here**
  - Remove the `lj:` block (then `pair_coeff` is omitted).
- **Pair style compatibility**
  - If you emit `pair_coeff`, ensure the parent system uses a compatible LJ form (e.g., `lj/cut`, `lj/cut/coul/long`, etc.).

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
- Custom generator: `scripts/make_monatomic_ion_2_lt.py`

This repository may invoke or rely on third-party software distributed under their own licenses, including Moltemplate and LigParGen. Those components remain the property of their respective authors and are subject to their original license terms.

- Moltemplate — MIT License  
  Copyright (c) 2013, Andrew Jewett, University of California Santa Barbara

- LigParGen — MIT License  
  Copyright (c) 2020 Israel Cabeza de Vaca Lopez

