#!/usr/bin/env python3
"""
make_metal_slab.py

Generate a crystal surface slab for LAMMPS, with customizable size and vacuum.
The surface type (fcc, bcc, hcp, Miller index) is specified in metals.yaml.

Example usage:
    python scripts/make_metal_slab.py --elem Ag --size 4 4 3 --vac 15.0
    python scripts/make_metal_slab.py --elem Cu --size 5 5 4 --vac 10.0
    python scripts/make_metal_slab.py --elem Fe --size 3 3 6               # vacuum defaults to 15.0 Å
    python scripts/make_metal_slab.py --elem Zn --size 4 4 3
    python scripts/make_metal_slab.py --elem Au --size 4 4 3 --vac 0 --out data/Au_100.data

By default, output is saved to data/<elem>_slab.data.
"""

import argparse
import numpy as np
import yaml
from ase.build import surface  
from ase.lattice import bulk   
from ase.io import write
import pathlib

def main():
    # Argument parsing
    parser = argparse.ArgumentParser(description="Build a surface slab (fcc, hcp, bcc) for LAMMPS.")
    parser.add_argument("--elem", default="Ag",
                        help="Element symbol of metal (default: Ag)")
    parser.add_argument("--size", nargs=3, type=int, default=[4, 4, 3], metavar=('NX', 'NY', 'NZ'),
                        help="Unit cell replication in x, y, z (default: 4 4 3)")
    parser.add_argument("--vac", type=float, default=15.0,
                        help="Vacuum thickness in z direction [angstrom] (default: 15.0)")
    parser.add_argument("--yaml", default="config/metals.yaml",
                        help="Path to metals.yaml (default: config/metals.yaml)")
    parser.add_argument("--out", default=None,
                        help="Output filename (default: data/<elem>_slab.data)")
    args = parser.parse_args()

    # Read structure info from YAML
    with open(args.yaml) as f:
        metals = yaml.safe_load(f)
    metal_info = metals[args.elem]
    structure = metal_info.get("structure", "fcc")
    miller = metal_info.get("miller", [1, 1, 1])   # Default: [1,1,1] for fcc

    # Prepare Miller index: hcp may use 3 or 4 indices, ASE surface handles both
    if not isinstance(miller, list):
        raise ValueError(f"Miller index for {args.elem} must be a list, e.g., [1,1,1]")

    # Build bulk crystal using ASE
    # This bulk lattice is passed to ase.build.surface for slab construction
    atoms_bulk = bulk(args.elem, structure)

    # Build surface slab (universal for fcc, bcc, hcp)
    slab = surface(atoms_bulk, miller, args.size[2])  # nx, ny will be tiled below
    # Expand slab to desired size in x/y (surface() builds 1x1 slab by default)
    slab = slab.repeat((args.size[0], args.size[1], 1))

    # Center slab & add vacuum along z
    slab.center(axis=2, vacuum=args.vac)

    # Assign zero charge and mol-ID columns for LAMMPS "full" atom style
    slab.set_initial_charges(np.zeros(len(slab)))
    slab.set_tags(np.ones(len(slab), dtype=int))

    # Determine output file path
    outname = args.out or f"data/{args.elem}_slab.data"
    pathlib.Path(outname).parent.mkdir(parents=True, exist_ok=True)

    # Write LAMMPS data file
    write(outname, slab, format='lammps-data', atom_style='full', units='metal')
    print(f"[ok] {outname} written")

if __name__ == "__main__":
    main()
