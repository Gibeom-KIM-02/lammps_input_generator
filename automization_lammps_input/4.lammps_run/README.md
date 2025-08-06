# How to Run LAMMPS Simulations

1. Make sure you have already run moltemplate.sh and created the files in `build/`:
    - system.data
    - system.in.init
    - system.in.settings
    - system.in.charges

2. To run simulations (minimization → NPT → NVT), run these commands:

```bash
lmp_mpi -in run.in.min
lmp_mpi -in run.in.npt
lmp_mpi -in run.in.nvt

```

(Replace lmp_mpi with your own LAMMPS executable.)

If you want to use MPI:

```bash
mpirun -np 4 lmp_mpi -in run.in.min
mpirun -np 4 lmp_mpi -in run.in.npt
mpirun -np 4 lmp_mpi -in run.in.nvt

```

