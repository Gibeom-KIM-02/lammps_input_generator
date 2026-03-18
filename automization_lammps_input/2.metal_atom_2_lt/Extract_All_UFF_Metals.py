#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Extract_All_UFF_Metals.py

Purpose
-------
Build a canonical local metal table from Open Babel's UFF.prm.

Main idea
---------
1. Read all "atom" typing rules from UFF.prm.
2. Read all "param" rows from UFF.prm.
3. Keep only metal elements.
4. Prefer the generic rule "[#Z]" for each element when multiple
   coordination-specific rules exist.
5. Write a clean YAML file: metals.yaml

Why generic rules are preferred here
------------------------------------
For a bare monatomic metal LT fragment, a generic element-level UFF type
is usually more appropriate than a coordination-specific SMARTS rule
such as [#22D3].
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml is required.", file=sys.stderr)
    sys.exit(1)


# ----------------------------------------------------------------------
# Periodic table
# ----------------------------------------------------------------------
ELEMENTS = [
    None,
    "H", "He",
    "Li", "Be", "B", "C", "N", "O", "F", "Ne",
    "Na", "Mg", "Al", "Si", "P", "S", "Cl", "Ar",
    "K", "Ca", "Sc", "Ti", "V", "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn",
    "Ga", "Ge", "As", "Se", "Br", "Kr",
    "Rb", "Sr", "Y", "Zr", "Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd",
    "In", "Sn", "Sb", "Te", "I", "Xe",
    "Cs", "Ba", "La", "Ce", "Pr", "Nd", "Pm", "Sm", "Eu", "Gd", "Tb", "Dy",
    "Ho", "Er", "Tm", "Yb", "Lu",
    "Hf", "Ta", "W", "Re", "Os", "Ir", "Pt", "Au", "Hg",
    "Tl", "Pb", "Bi", "Po", "At", "Rn",
    "Fr", "Ra", "Ac", "Th", "Pa", "U", "Np", "Pu", "Am", "Cm", "Bk", "Cf",
    "Es", "Fm", "Md", "No", "Lr"
]

SYMBOL_TO_Z = {sym: z for z, sym in enumerate(ELEMENTS) if sym is not None}
Z_TO_SYMBOL = {z: sym for sym, z in SYMBOL_TO_Z.items()}

# Conventional metals only.
# Metalloids such as B, Si, Ge, As, Sb, Te are intentionally excluded.
METAL_SYMBOLS = {
    "Li", "Be", "Na", "Mg", "Al", "K", "Ca", "Sc", "Ti", "V", "Cr", "Mn",
    "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Rb", "Sr", "Y", "Zr", "Nb", "Mo",
    "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn", "Cs", "Ba", "La", "Ce",
    "Pr", "Nd", "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb",
    "Lu", "Hf", "Ta", "W", "Re", "Os", "Ir", "Pt", "Au", "Hg", "Tl", "Pb",
    "Bi", "Po", "Fr", "Ra", "Ac", "Th", "Pa", "U", "Np", "Pu", "Am", "Cm",
    "Bk", "Cf", "Es", "Fm", "Md", "No", "Lr"
}

PARAM_KEYS = [
    "r1",
    "theta0",
    "x1",
    "D1",
    "zeta",
    "Z1",
    "Vi",
    "Uj",
    "Xi",
    "Hard",
    "Radius",
]

ATOM_RE = re.compile(r"^\s*atom\s+\[([^\]]+)\]\s+(\S+)")
PARAM_RE = re.compile(r"^\s*param\s+(\S+)\s+(.+?)\s*$")
SMARTS_Z_RE = re.compile(r"#(\d+)")


def autodetect_uff_prm() -> Path:
    """
    Find UFF.prm from the currently active Python environment.
    """
    try:
        import openbabel as ob_mod
    except Exception as exc:
        raise FileNotFoundError(
            "Could not import openbabel for auto-detection. "
            "Please pass --uff-prm explicitly."
        ) from exc

    ob_init = Path(ob_mod.__file__).resolve()

    for parent in ob_init.parents:
        matches = list(parent.rglob("UFF.prm"))
        if matches:
            return matches[0]

    raise FileNotFoundError(
        "Could not auto-detect UFF.prm from the current environment."
    )


def parse_uff_prm(uff_prm_path: Path) -> Tuple[Dict[int, List[dict]], Dict[str, dict]]:
    """
    Parse UFF.prm into:
    1. atom_rules_by_z: Z -> list of atom typing rules
    2. params_by_type: UFF atom type -> parameter dict
    """
    atom_rules_by_z: Dict[int, List[dict]] = {}
    params_by_type: Dict[str, dict] = {}

    with uff_prm_path.open("r", encoding="utf-8") as f:
        for line in f:
            stripped = line.strip()

            if not stripped or stripped.startswith("#"):
                continue

            atom_match = ATOM_RE.match(line)
            if atom_match:
                smarts_content = atom_match.group(1).strip()
                uff_type = atom_match.group(2).strip()

                z_match = SMARTS_Z_RE.search(smarts_content)
                if not z_match:
                    continue

                atomic_number = int(z_match.group(1))
                atom_rules_by_z.setdefault(atomic_number, []).append(
                    {
                        "smarts": smarts_content,
                        "uff_type": uff_type,
                    }
                )
                continue

            param_match = PARAM_RE.match(line)
            if param_match:
                uff_type = param_match.group(1).strip()
                raw_values = param_match.group(2).split()

                if len(raw_values) != len(PARAM_KEYS):
                    raise ValueError(
                        f"Unexpected column count for '{uff_type}'. "
                        f"Expected {len(PARAM_KEYS)}, got {len(raw_values)}.\n"
                        f"Line: {line.rstrip()}"
                    )

                params_by_type[uff_type] = {
                    key: float(value)
                    for key, value in zip(PARAM_KEYS, raw_values)
                }
                continue

    return atom_rules_by_z, params_by_type


def choose_generic_rule(
    atomic_number: int,
    rules: List[dict],
) -> Optional[dict]:
    """
    Prefer the exact generic rule "[#Z]" if present.
    Otherwise fall back to the first rule found.
    """
    exact_generic = f"#{atomic_number}"

    for rule in rules:
        if rule["smarts"] == exact_generic:
            return rule

    return rules[0] if rules else None


def build_output_dict(
    atom_rules_by_z: Dict[int, List[dict]],
    params_by_type: Dict[str, dict],
    uff_prm_path: Path,
) -> dict:
    """
    Build the final YAML structure.
    """
    result = {
        "metadata": {
            "ff_family": "UFF",
            "primary_reference": (
                "Rappe, A. K.; Casewit, C. J.; Colwell, K. S.; "
                "Goddard, W. A. III; Skiff, W. M. "
                "UFF, a full periodic table force field for molecular mechanics "
                "and molecular dynamics simulations. "
                "J. Am. Chem. Soc. 1992, 114, 10024-10035."
            ),
            "implementation_source": "Open Babel UFF.prm",
            "implementation_file": str(uff_prm_path.resolve()),
            "note": (
                "This table preserves original UFF.prm values. "
                "Generic element-level SMARTS rules [#Z] are preferred "
                "when available."
            ),
        },
        "metals": {},
    }

    for atomic_number in sorted(atom_rules_by_z):
        symbol = Z_TO_SYMBOL.get(atomic_number)
        if symbol is None:
            continue
        if symbol not in METAL_SYMBOLS:
            continue

        chosen_rule = choose_generic_rule(atomic_number, atom_rules_by_z[atomic_number])
        if chosen_rule is None:
            continue

        uff_type = chosen_rule["uff_type"]
        if uff_type not in params_by_type:
            print(
                f"WARNING: No parameter row found for {symbol} ({uff_type}). Skipping.",
                file=sys.stderr,
            )
            continue

        result["metals"][symbol] = {
            "atomic_number": atomic_number,
            "atom_rule_smarts": chosen_rule["smarts"],
            "uff_type": uff_type,
            "params": params_by_type[uff_type],
        }

    return result


def main():
    parser = argparse.ArgumentParser(
        description="Extract all metal entries from Open Babel UFF.prm into YAML."
    )
    parser.add_argument(
        "--uff-prm",
        type=str,
        default=None,
        help="Path to UFF.prm. If omitted, auto-detection is attempted.",
    )
    parser.add_argument(
        "--output",
        type=str,
        default="metals.yaml",
        help="Output YAML filename. Default: metals.yaml",
    )
    args = parser.parse_args()

    if args.uff_prm is None:
        uff_prm_path = autodetect_uff_prm()
    else:
        uff_prm_path = Path(args.uff_prm).expanduser().resolve()

    if not uff_prm_path.exists():
        print(f"ERROR: UFF.prm not found: {uff_prm_path}", file=sys.stderr)
        sys.exit(1)

    atom_rules_by_z, params_by_type = parse_uff_prm(uff_prm_path)
    output_data = build_output_dict(atom_rules_by_z, params_by_type, uff_prm_path)

    out_path = Path(args.output).expanduser().resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with out_path.open("w", encoding="utf-8") as f:
        yaml.safe_dump(
            output_data,
            f,
            sort_keys=False,
            allow_unicode=True,
            default_flow_style=False,
        )

    print(f"[OK] Wrote: {out_path}")
    print(f"[INFO] UFF source: {uff_prm_path}")
    print(f"[INFO] Metal entries: {len(output_data['metals'])}")


if __name__ == "__main__":
    main()
