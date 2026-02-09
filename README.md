# lammps_input_generator
By using **Moltemplate** and **LigParGen**, this repository automates generating **LAMMPS-ready input files**.

## 📁 Directory Structure

```text
automization_lammps_input/
├── 0.create_conda_env/        # Create conda env (ligpargen_run) & install LigParGen deps
│
├── 1.mol2_2_lt/               # Generate .lt files from .mol2 (LigParGen + postprocess)
│
├── 2.Monatomic_ion_2_lt/      # Generate minimal .lt files for monatomic ions (K+, Zn2+, ...)
│
├── 3.run_moltemplate/         # Generate system.lt and run moltemplate.sh (system.data / system.in.*)
│
├── 4.lammps_run/              # LAMMPS run directory (MD/FEP inputs, jobs, etc.)
│
└── README.md
