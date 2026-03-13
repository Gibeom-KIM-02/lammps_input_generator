#!/bin/bash
# README_run.sh
# Example workflow for lt_2_system project

# 1. Prepare folders & input files (assume you have correct molecules.yaml, .lt files, and .xyz)
#    (Not shown: structure and .lt/.yaml prep)

# 2. Run the system.lt generator
python make_system_lt.py

# 3. Generate LAMMPS input/data files with moltemplate
moltemplate.sh -xyz input_files_structure/waterTIP3P+methane.xyz -atomstyle "full" system.lt

echo "DONE. Check system.lt, system.in, and system.data!"

