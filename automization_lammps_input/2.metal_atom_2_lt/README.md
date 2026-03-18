# 2.metal_atom_2_lt — UFF-Based Monatomic Metal LT Generator

This directory provides a small utility workflow to generate **monatomic metal `.lt` files** for Moltemplate/LAMMPS using the **UFF parameter table (`UFF.prm`) distributed with Open Babel**.

The workflow is intentionally simple:

1. **Extract metal entries** from `UFF.prm`
2. **Build a local canonical table** (`data/metals.yaml`)
3. **Generate one `.lt` file per metal** into `output_lt/`

This makes it easy to keep a reproducible set of **generic metal LT fragments** that can be reused in other workflows, including `3.run_moltemplate`.

---

## Directory structure

```text
2.metal_atom_2_lt/
├─ data/
│  └─ metals.yaml
├─ output_lt/
│  ├─ Ag.lt
│  ├─ Au.lt
│  ├─ Pt.lt
│  └─ ...
├─ Extract_All_UFF_Metals.py
├─ Make_Metal_LT.py
└─ README.md
```

---

## What each file does

### `Extract_All_UFF_Metals.py`
Reads the Open Babel `UFF.prm` file and extracts **metal-related UFF entries** into a local YAML table.
- **Output:** `data/metals.yaml`
- This YAML file stores:
  - element symbol
  - atomic number
  - selected UFF atom type
  - original UFF parameter row
  - source metadata

### `Make_Metal_LT.py`
Reads `data/metals.yaml` and generates **one monatomic `.lt` file per metal**.
- **Output:** `output_lt/*.lt`
- Each generated LT file contains:
  - Data Masses
  - Data Atoms
  - optional self `pair_coeff`

### `data/metals.yaml`
A canonical local table of metal entries extracted from `UFF.prm`.
This file is intended to separate **parameter extraction** from **LT generation**, so that LT generation can be repeated without reparsing `UFF.prm` every time.

### `output_lt/`
Pre-generated monatomic metal LT files.
These can be used directly, copied into another workflow, or regenerated when needed.

---

## Intended use

These files are meant to be used as **generic monatomic metal LT fragments** for Moltemplate-based LAMMPS workflows.

A typical use case is:
1. generate or reuse `Ag.lt`, `Au.lt`, `Pt.lt`, etc.
2. copy the needed file(s) into: `3.run_moltemplate/input_files_lt/`
3. include them in a Moltemplate system

For example, `Ag.lt` can be used as a simple reusable LT building block when constructing a slab, cluster, or placeholder metal object in an automated workflow.

---

## Important limitations

These LT files are **UFF-based generic metal placeholders**.

They may be useful for:
- quick prototyping
- initial system construction
- automated workflow testing
- simple placeholder metal definitions

However, they are **not a substitute for carefully validated metal force fields** for production simulations involving:
- metallic bulk systems
- metal surfaces
- adsorption energetics
- electrode models
- quantitatively reliable interfacial simulations

In particular, users should be cautious when applying these files to surface science or electrochemical systems where metal interactions require more specialized parameterizations.

---

## Parameter source and interpretation

The source of the parameters is the Open Babel `UFF.prm` file.
This workflow uses:
- the **UFF atom typing / parameter definitions** from `UFF.prm`
- a local extracted table (`data/metals.yaml`)
- generated LT files based on that table

The generated YAML preserves the **original UFF parameter columns as-is**. For convenience, LT generation may also include self `pair_coeff` values inferred from UFF parameters. These should be treated as **default placeholders, not universally validated production parameters.**

---

## Pair coefficient note

If `Make_Metal_LT.py` is run with self `pair_coeff` output enabled, the script writes a default self-interaction line for each metal. This is only a convenience feature.

Users should review or modify these parameters depending on:
- the chosen LAMMPS `pair_style`
- mixing rules
- cross interaction strategy
- the actual physical target system

In many real workflows, the generated self `pair_coeff` may need to be replaced by a more appropriate parameterization.

---

### Cross interaction caution

Even when self `pair_coeff` values are generated automatically for metal atom types,
the **cross interaction terms** between metal atoms and other force-field types
(e.g., LigParGen / OPLS-AA organic atoms, ions, or solvent atoms)
still require careful review.

In many workflows, these cross terms may be assigned through a LAMMPS mixing rule.
While this is convenient for automation, it should not be assumed to provide
physically reliable metal–molecule or metal–ion interactions in all cases.

Users should therefore treat automatically mixed cross terms as **default placeholders**
and consider replacing or overriding them when:
- metal–adsorbate interactions are important
- interfacial energetics matter
- coordination behavior is relevant
- quantitatively reliable metal–molecule interactions are needed

---

## How the workflow works

### Step 1. Extract all metal entries from `UFF.prm`

```bash
python Extract_All_UFF_Metals.py --output data/metals.yaml
```
This creates a local canonical table of metal entries.

### Step 2. Generate LT files from the YAML table

Example:
```bash
python Make_Metal_LT.py \
  --input data/metals.yaml \
  --output-dir output_lt \
  --atom-style full \
  --default-charge 0.0 \
  --emit-pair-coeff
```
This generates monatomic LT files in `output_lt/`.

---

## Example output

A generated file such as `Ag.lt` contains a minimal monatomic LT object, for example:
- one atom type
- one mass entry
- one atom entry
- an optional self `pair_coeff`

This makes the file easy to reuse in Moltemplate-based workflows.

---

## Reuse in `3.run_moltemplate`

A simple reuse pattern is:
1. choose the metal LT file(s) you need from `output_lt/`
2. copy them into: `3.run_moltemplate/input_files_lt/`
3. include them in your Moltemplate system

This keeps the metal LT generation step separate from the final system-building workflow.

---

## Design choice

This directory intentionally separates the workflow into two layers:
- **Layer 1: canonical metal table** (`UFF.prm` → `data/metals.yaml`)
- **Layer 2: LT generation** (`data/metals.yaml` → `output_lt/*.lt`)

This design improves:
- reproducibility
- readability
- maintainability
- ease of regeneration

It also allows the generated LT files to be version-controlled as reusable assets.

---

## Reference

Please cite or acknowledge the original UFF reference as appropriate:

> Rappé, A. K.; Casewit, C. J.; Colwell, K. S.; Goddard, W. A. III; Skiff, W. M.  
> **UFF, a full periodic table force field for molecular mechanics and molecular dynamics simulations.** > *J. Am. Chem. Soc.* 1992, 114, 10024–10035.

This workflow uses the `UFF.prm` implementation distributed with **Open Babel**.

---

## Notes

- `output_lt/` contains **generated files**, but they are intentionally kept as reusable reference assets.
- `data/metals.yaml` is the main intermediate table for reproducibility.
- If needed, users can regenerate the entire set from the scripts in this directory.

---

## Summary

This directory is a lightweight utility for generating and storing **generic UFF-based monatomic metal LT files** for Moltemplate/LAMMPS workflows.

Use it when you want:
- a reproducible metal LT table
- pre-generated generic metal `.lt` files
- a simple bridge between Open Babel UFF data and Moltemplate input generation