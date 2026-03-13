# molecules.yaml Guide (Updated)

This guide describes `config/molecules.yaml` used by `make_system_lt.py` to generate `system.lt`.

> **Update note**
>  
> This project no longer separates adsorbent/slab LT files into a dedicated folder.
> Put **all** `.lt` fragments (molecules/ions/solvents/slabs/custom FF fragments) in `input_files_lt/`
> and reference them via `lt_path`.

---

## Top-level Keys

### `global` (required)
- `xyz_file` (str)  
  Path to the XYZ coordinates file (PACKMOL/ASE output), e.g. `input_files_structure/system.xyz`
- `output_lt` (str)  
  Output filename for the generated LT file (usually `system.lt`)
- `extra_imports` (list[str], optional)  
  Extra LT files to import **before** molecule LT fragments (e.g., `ff_custom.lt`)

Example:

```yaml
global:
  xyz_file: "input_files_structure/1_6M_OTFTFE_1_1.xyz"
  output_lt: "system.lt"
  extra_imports:
    - "input_files_lt/ff_custom.lt"
```

### `molecules` (required)
An **order-preserving mapping** of components in your system.

- The **YAML order is the instantiation order** in `system.lt`
- This order should match the molecule blocks in your XYZ file (critical for correct mapping)

---

## Per-molecule Fields

| Key            | Required | Type        | Description |
|----------------|----------|-------------|-------------|
| `lt_path`      | Yes      | str         | Relative path to the molecule LT file (typically under `input_files_lt/`). |
| `class_name`   | Yes      | str         | Class name defined inside the LT file (case-sensitive). |
| `instance_name`| No       | str         | Variable name used in `system.lt` (defaults to the molecule key). |
| `count_rule`   | Yes*     | str         | Python expression for molecule count (see below). |
| `charge`       | No       | int/float   | Note field (not enforced automatically). |
| `force_count`  | No       | int         | Force a specific molecule count (overrides `count_rule`). |
| `adsorbent`    | No       | bool        | Optional: slab-like object auto-counting (script feature). |
| `fixed_group`  | No       | str         | Optional: group range (e.g. `"1:16"`) to generate `setforce` fix lines. |

\* For most molecules you must provide `count_rule`.  
If you use `adsorbent: true`, the script may auto-count based on LT atom counts.

---

## `count_rule` Expression

`count_rule` is evaluated as Python with:
- `elem`: dict of element counts in the XYZ, e.g. `elem['S']`, `elem['Zn']`
- `mol`: dict of already-resolved molecule counts, e.g. `mol['OTF']`

The result must be an integer.

### Examples

- **OTF**: `elem['S']`
- **Zn ion**: `elem['Zn']`
- **K ion**: `elem['K']`
- **Fixed number**: `"347"` or `"87"`

---

## Example molecules.yaml

```yaml
global:
  xyz_file: "input_files_structure/waterTIP3P+methane.xyz"   # Input XYZ coordinates file
  output_lt: "system.lt"                                     # Output LT file name
  extra_imports:
    - "input_files_lt/ff_custom.lt"    # If you want to import external forcefields, use "extra_imports (ff.lt)" (e.g. buckingham potential parameter)

# Typing order of molecules should be same with xyz structure file's molecular order.
molecules:
  TIP3P_water:
    instance_name: water
    lt_path: "input_files_lt/tip3p_2004_oplsaa2024.lt"
    class_name: "TIP3P"
    count_rule: "elem['O']"
    #count_rule: "512" # Also you can explicitly assgin number of waters.

  Methane:
    instance_name: Methane
    lt_path: "input_files_lt/Methane.lt"
    class_name: "Methane"
    count_rule: "27"
```

---

## Notes / Best Practices

- **Ordering matters**: keep `molecules:` order aligned with XYZ ordering.
- **Paths are relative** to where you run `moltemplate.sh`.
- `charge` is for human bookkeeping — verify neutrality manually.
- If you introduce slabs, you can still keep their LT in `input_files_lt/`
  and (optionally) use `adsorbent: true` / `fixed_group`.

