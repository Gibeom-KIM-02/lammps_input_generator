#!/bin/bash
# ---------------------------------------------------------
# Running LAMMPS: minimization, NPT, and NVT simulations
# ---------------------------------------------------------
# Before running, make sure you have generated these files:
#   build/system.data
#   build/system.in.init
#   build/system.in.settings
#   build/system.in.charges
# using moltemplate.sh.
# ---------------------------------------------------------
# Standard run (single process):
lmp_mpi -in run.in.min   # Minimization
lmp_mpi -in run.in.npt   # Constant pressure equilibration (NPT)
lmp_mpi -in run.in.nvt   # Constant volume production run (NVT)

# If you compiled LAMMPS with MPI, to run in parallel:
# mpirun -np 4 lmp_mpi -in run.in.min
# mpirun -np 4 lmp_mpi -in run.in.npt
# mpirun -np 4 lmp_mpi -in run.in.nvt

# (Replace "lmp_mpi" with your LAMMPS executable as needed.)

