# molecules.yaml Guide

This file defines how to generate a system.lt for moltemplate automation.
Each molecule (or slab) can be specified flexibly.

---

## Top-level Keys

- **global**
  - `xyz_file`      : Path to the PACKMOL-generated XYZ coordinates file.
  - `output_lt`     : Name of the output system.lt file.

- **molecules**
  - Each key is a molecule "nickname" (arbitrary, e.g., `CO2`, `Sulfate`, `AgSlab`).
  - Values are molecule-specific configuration dictionaries.

---

## Per-Molecule Options

| Key           | Required | Type      | Description                                                                                   |
|---------------|----------|-----------|-----------------------------------------------------------------------------------------------|
| lt_path       | Yes      | str       | Relative path to the molecule's LT file.                                                      |
| class_name    | Yes      | str       | The class name defined in the LT file (used in instantiation).                                |
| adsorbent     | No       | bool      | Set `true` if the molecule is a slab/adsorbent (special count rules will be applied).         |
| fixed_group   | No       | str       | Atom id range for LAMMPS group fix (e.g., "1:32"). Used for fixing bottom slab layers.        |
| count_rule    | No\*     | str       | Python expression for counting number of molecules. Required for all **non-adsorbents**.      |
| charge        | No       | int/float | For notes or charge-neutrality calculation (not used directly in system.lt generation).       |
| force_count   | No       | int       | Explicitly force number of this molecule (overrides all other rules, rarely needed).          |

\* **adsorbent: true** entries ignore `count_rule` and auto-count based on atom numbers.

---

## count_rule Expression

- **elem**: Python dictionary of element counts from the XYZ (e.g., `elem['C']`, `elem['O']`).
- **mol**: Dictionary of molecule counts already determined (e.g., `mol['CO2']`).
- Use valid Python expressions; result must be integer.

### Examples:
- For CO₂:      `elem['C']`
- For SO₄²⁻:    `elem['S']`
- For H₂O:      `elem['O'] - 2*mol['CO2'] - 4*mol['Sulfate']`

---

## Notes

- **Ordering**: The order in `molecules:` determines instantiation and (by convention) should match atom order in the XYZ file.
- **Class Names**: Must match exactly what's defined in each .lt file (case-sensitive).
- **Flexibility**: You can add more molecules by copying the same block format and setting the appropriate rules.

---

## Example Structure

```yaml
global:
  xyz_file: "input_files_structure/Ag_sulfate_CO2_solvated.xyz"
  output_lt: "system.lt"

molecules:
  AgSlab:
    lt_path: "input_files_lt_adsorbent/Ag.lt"
    class_name: "Ag"
    adsorbent: true
    fixed_group: "1:32"

  CO2:
    lt_path: "input_files_lt/CO2.lt"
    class_name: "CO2"
    count_rule: "elem['C']"

  Sulfate:
    lt_path: "input_files_lt/sulfate.lt"
    class_name: "sulfate"
    count_rule: "elem['S']"
    charge: -2

  TIP3P_2004:
    lt_path: "input_files_lt/tip3p_2004_oplsaa2024.lt"
    class_name: "TIP3P"
    count_rule: "elem['O'] - 2*mol['CO2'] - 4*mol['Sulfate']"

