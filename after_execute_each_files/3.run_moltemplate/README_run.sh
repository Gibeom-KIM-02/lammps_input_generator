#!/bin/bash
# README_run.sh
# Example workflow for lt_2_system project

# 1. Prepare folders & input files (assume you have correct molecules.yaml, .lt files, and .xyz)
#    (Not shown: structure and .lt/.yaml prep)

# 2. Run the system.lt generator
python make_system_lt.py

# 3. Generate LAMMPS input/data files with moltemplate
moltemplate.sh -xyz input_files_structure/1_6M_OTFTFE_1_1.xyz -atomstyle "full" system.lt

# (Optional) 4. Visualize, check system.data, or run LAMMPS
# vmd system.data
# lmp_stable -in system.in

cp system.data system.in.init system.in.settings ../5.lammps_run/build/

echo "DONE. Check system.lt, system.in, and system.data!"

