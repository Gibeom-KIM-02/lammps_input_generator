#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Make_Metal_LT.py

Purpose
-------
Generate monatomic Moltemplate .lt files from a canonical metals.yaml table.

Default behavior
----------------
- Read all metals from metals.yaml
- Write one LT file per metal
- Emit:
  * one atom type
  * one atom object
  * atomic mass
  * optional self pair_coeff
- Default atom_style is "full"

Important note on sigma conversion
----------------------------------
If self pair_coeff is emitted, this script uses:

    epsilon = D1
    sigma   = x1 / 2^(1/6)

This is an explicit inference that treats UFF x1 as the LJ minimum-distance
parameter, while LAMMPS LJ sigma is the zero-crossing distance.
If you do not want that conversion, disable pair_coeff output or change
--sigma-mode.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path
from typing import Dict

try:
    import yaml
except ImportError:
    print("ERROR: pyyaml is required.", file=sys.stderr)
    sys.exit(1)


# ----------------------------------------------------------------------
# Practical atomic masses for metals commonly relevant to MD workflows.
# If a metal is missing here, the script will stop and ask you to add it.
# ----------------------------------------------------------------------
ATOMIC_MASSES: Dict[str, float] = {
    "Li": 6.94,
    "Be": 9.0121831,
    "Na": 22.98976928,
    "Mg": 24.305,
    "Al": 26.9815385,
    "K": 39.0983,
    "Ca": 40.078,
    "Sc": 44.955908,
    "Ti": 47.867,
    "V": 50.9415,
    "Cr": 51.9961,
    "Mn": 54.938044,
    "Fe": 55.845,
    "Co": 58.933194,
    "Ni": 58.6934,
    "Cu": 63.546,
    "Zn": 65.38,
    "Ga": 69.723,
    "Rb": 85.4678,
    "Sr": 87.62,
    "Y": 88.90584,
    "Zr": 91.224,
    "Nb": 92.90637,
    "Mo": 95.95,
    "Tc": 98.0,
    "Ru": 101.07,
    "Rh": 102.9055,
    "Pd": 106.42,
    "Ag": 107.8682,
    "Cd": 112.414,
    "In": 114.818,
    "Sn": 118.71,
    "Cs": 132.90545196,
    "Ba": 137.327,
    "La": 138.90547,
    "Ce": 140.116,
    "Pr": 140.90766,
    "Nd": 144.242,
    "Pm": 145.0,
    "Sm": 150.36,
    "Eu": 151.964,
    "Gd": 157.25,
    "Tb": 158.92535,
    "Dy": 162.5,
    "Ho": 164.93033,
    "Er": 167.259,
    "Tm": 168.93422,
    "Yb": 173.045,
    "Lu": 174.9668,
    "Hf": 178.49,
    "Ta": 180.94788,
    "W": 183.84,
    "Re": 186.207,
    "Os": 190.23,
    "Ir": 192.217,
    "Pt": 195.084,
    "Au": 196.966569,
    "Hg": 200.592,
    "Tl": 204.38,
    "Pb": 207.2,
    "Bi": 208.9804,
    "Po": 209.0,
    "Fr": 223.0,
    "Ra": 226.0,
    "Ac": 227.0,
    "Th": 232.0377,
    "Pa": 231.03588,
    "U": 238.02891,
    "Np": 237.0,
    "Pu": 244.0,
    "Am": 243.0,
    "Cm": 247.0,
    "Bk": 247.0,
    "Cf": 251.0,
    "Es": 252.0,
    "Fm": 257.0,
    "Md": 258.0,
    "No": 259.0,
    "Lr": 266.0,
}


def format_float(value: float, digits: int = 8) -> str:
    """
    Compact float formatter for LT output.
    """
    return f"{value:.{digits}f}"


def infer_sigma_from_x1(x1: float) -> float:
    """
    Convert a UFF-like equilibrium distance parameter into
    a LAMMPS-style LJ sigma parameter by dividing by 2^(1/6).
    """
    return x1 / (2.0 ** (1.0 / 6.0))


def make_atoms_block(symbol: str, atom_style: str, charge: float) -> str:
    """
    Create the Data Atoms block for a single monatomic object.
    """
    if atom_style == "full":
        return (
            '  write("Data Atoms") {\n'
            f'    $atom:{symbol} $mol:. @atom:{symbol} {format_float(charge, 6)} 0.0 0.0 0.0\n'
            "  }\n"
        )

    if atom_style == "charge":
        return (
            '  write("Data Atoms") {\n'
            f'    $atom:{symbol} @atom:{symbol} {format_float(charge, 6)} 0.0 0.0 0.0\n'
            "  }\n"
        )

    raise ValueError(f"Unsupported atom_style: {atom_style}")


def render_lt(
    symbol: str,
    metal_entry: dict,
    atom_style: str,
    default_charge: float,
    emit_pair_coeff: bool,
    sigma_mode: str,
) -> str:
    """
    Render one monatomic metal LT file as a string.
    """
    if symbol not in ATOMIC_MASSES:
        raise KeyError(
            f"Atomic mass for '{symbol}' is not in ATOMIC_MASSES. "
            f"Please add it before generating LT files."
        )

    atomic_mass = ATOMIC_MASSES[symbol]
    params = metal_entry["params"]
    uff_type = metal_entry["uff_type"]
    atomic_number = metal_entry["atomic_number"]

    x1 = params["x1"]
    D1 = params["D1"]

    sigma_comment = ""
    pair_coeff_block = ""

    if emit_pair_coeff:
        if sigma_mode == "x1_over_2pow1_6":
            sigma = infer_sigma_from_x1(x1)
            sigma_note = (
                "sigma inferred as x1 / 2^(1/6), treating x1 as the LJ minimum-distance parameter"
            )
        elif sigma_mode == "x1_as_sigma":
            sigma = x1
            sigma_note = (
                "sigma set directly equal to x1 with no minimum-distance conversion"
            )
        else:
            raise ValueError(f"Unsupported sigma_mode: {sigma_mode}")

        epsilon = D1

        sigma_comment = f"# LJ mapping note: {sigma_note}\n"
        pair_coeff_block = (
            '\n  write_once("In Settings") {\n'
            f"    pair_coeff @atom:{symbol} @atom:{symbol} "
            f"{format_float(epsilon, 8)} {format_float(sigma, 8)}\n"
            "  }\n"
        )

    atoms_block = make_atoms_block(symbol, atom_style, default_charge)

    lt_text = (
        f"# Auto-generated monatomic metal LT for {symbol}\n"
        f"# Atomic number: {atomic_number}\n"
        f"# UFF type: {uff_type}\n"
        f"# UFF atom SMARTS rule: [{metal_entry['atom_rule_smarts']}]\n"
        f"# UFF raw params: r1={params['r1']}, theta0={params['theta0']}, "
        f"x1={params['x1']}, D1={params['D1']}, zeta={params['zeta']}, "
        f"Z1={params['Z1']}, Vi={params['Vi']}, Uj={params['Uj']}, "
        f"Xi={params['Xi']}, Hard={params['Hard']}, Radius={params['Radius']}\n"
        f"{sigma_comment}"
        "\n"
        f"{symbol} {{\n"
        f'  write_once("Data Masses") {{\n'
        f"    @atom:{symbol} {format_float(atomic_mass, 8)}\n"
        "  }\n"
        "\n"
        f"{atoms_block}"
        f"{pair_coeff_block}"
        "}\n"
    )

    return lt_text


def main():
    parser = argparse.ArgumentParser(
        description="Generate monatomic Moltemplate LT files from metals.yaml."
    )
    parser.add_argument(
        "--input",
        type=str,
        default="metals.yaml",
        help="Input YAML file. Default: metals.yaml",
    )
    parser.add_argument(
        "--output-dir",
        type=str,
        default="output_lt",
        help="Directory for generated LT files. Default: output_lt",
    )
    parser.add_argument(
        "--atom-style",
        type=str,
        default="full",
        choices=["full", "charge"],
        help="LAMMPS atom_style layout for Data Atoms block.",
    )
    parser.add_argument(
        "--default-charge",
        type=float,
        default=0.0,
        help="Default atomic charge written into the LT object.",
    )
    parser.add_argument(
        "--emit-pair-coeff",
        action="store_true",
        default=False,
        help="Emit self pair_coeff lines.",
    )
    parser.add_argument(
        "--sigma-mode",
        type=str,
        default="x1_over_2pow1_6",
        choices=["x1_over_2pow1_6", "x1_as_sigma"],
        help="How to convert UFF x1 into LAMMPS sigma if pair_coeff is emitted.",
    )
    args = parser.parse_args()

    in_path = Path(args.input).expanduser().resolve()
    if not in_path.exists():
        print(f"ERROR: Input YAML not found: {in_path}", file=sys.stderr)
        sys.exit(1)

    with in_path.open("r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    if "metals" not in data or not isinstance(data["metals"], dict):
        print("ERROR: Invalid metals.yaml format. Missing top-level 'metals' mapping.", file=sys.stderr)
        sys.exit(1)

    out_dir = Path(args.output_dir).expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    count = 0
    for symbol, metal_entry in data["metals"].items():
        lt_text = render_lt(
            symbol=symbol,
            metal_entry=metal_entry,
            atom_style=args.atom_style,
            default_charge=args.default_charge,
            emit_pair_coeff=args.emit_pair_coeff,
            sigma_mode=args.sigma_mode,
        )

        out_file = out_dir / f"{symbol}.lt"
        with out_file.open("w", encoding="utf-8") as f:
            f.write(lt_text)

        count += 1
        print(f"[OK] Wrote {out_file}")

    print(f"[DONE] Generated {count} LT files in: {out_dir}")


if __name__ == "__main__":
    main()
