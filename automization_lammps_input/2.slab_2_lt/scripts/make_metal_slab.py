#!/usr/bin/env python3
"""
make_metal_slab.py

Generate an FCC (111) metal slab for LAMMPS, with customizable size and vacuum.
The output is a LAMMPS data file suitable for use with Moltemplate.

Example usage:
    python scripts/make_metal_slab.py --elem Ag --size 4 4 3 --vac 15.0
    python scripts/make_metal_slab.py --elem Cu --size 5 5 4           # vacuum defaults to 15.0 Å

By default, output is saved to data/<elem>_slab.data.
"""

import argparse
import numpy as np
from ase.build import fcc111
from ase.io import write
import pathlib

def main():
    # Argument parsing
    parser = argparse.ArgumentParser(description="Build FCC(111) metal slab for LAMMPS.")
    parser.add_argument("--elem", default="Ag",
                        help="Element symbol of FCC metal (default: Ag)")
    parser.add_argument("--size", nargs=3, type=int, default=[4, 4, 3], metavar=('NX', 'NY', 'NZ'),
                        help="Unit cell replication in x, y, z (default: 4 4 3)")
    parser.add_argument("--vac", type=float, default=15.0,
                        help="Vacuum thickness in z direction [angstrom] (default: 15.0)")
    parser.add_argument("--out", default=None,
                        help="Output filename (default: data/<elem>_slab.data)")
    args = parser.parse_args()

    # Build slab using ASE
    slab = fcc111(symbol=args.elem, size=tuple(args.size), orthogonal=True, periodic=True)
    # Add vacuum along z axis
    slab.center(axis=2, vacuum=args.vac)

    # Assign zero charge to all atoms (LAMMPS 'atom_style full' requires q column)
    slab.set_initial_charges(np.zeros(len(slab)))
    # Assign all atoms to mol-ID = 1 (LAMMPS 'atom_style full' requires mol-ID column)
    slab.set_tags(np.ones(len(slab), dtype=int))

    # Determine output file path
    outname = args.out or f"data/{args.elem}_slab.data"
    # Ensure the output directory exists
    pathlib.Path(outname).parent.mkdir(parents=True, exist_ok=True)

    # Write LAMMPS data file
    write(outname, slab, format='lammps-data', atom_style='full', units='metal')
    print(f"[ok] {outname} written")

if __name__ == "__main__":
    main()

