# slab_2_lt Workflow

A simple pipeline for generating FCC metal slab structures as LAMMPS data files, and converting them to Moltemplate `.lt` files with auto-inserted forcefield parameters.

---

## Directory Structure

slab_2_lt/  
├─ config/  
│ └─ metals.yaml # Forcefield parameters for metals (mass, sigma, epsilon)  
│  
├─ scripts/  
│ ├─ make_metal_slab.py # Python script: Build a slab and write .data file  
│ └─ make_lt_from_data.sh # Bash script: Convert .data → .lt using metals.yaml  
│  
├─ data/ # Output: LAMMPS data files  
│ └─ Ag_slab.data  
│  
├─ lt/ # Output: Moltemplate .lt files  
│ └─ Ag.lt  
│  
├─ README_run_example.sh  
│  
└─ README.md  

---

## Workflow

1. **Edit or add metals in `config/metals.yaml`**  
   Each entry should define `mass`, `sigma`, and `epsilon` for a metal.

2. **Generate a LAMMPS data file for a slab**
   ```bash
   python scripts/make_metal_slab.py --elem Ag --size 4 4 3 --vac 15.0
   
   Output: data/Ag_slab.data
   ```

3. **Convert the data file to a Moltemplate .lt file**
   ```bash
   bash scripts/make_lt_from_data.sh data/Ag_slab.data
 
   Output: lt/Ag.lt
   ```
   
   **You can easily run whole workflow by using `README_run_example.sh`**
   ```bash
   bash README_run_example.sh

   ```

---

## Example: Build and Convert a Silver (Ag) Slab
### 1. Generate a 4x4x3 Ag(111) slab with 15 Å vacuum
```
python scripts/make_metal_slab.py --elem Ag --size 4 4 3 --vac 15.0
```
### 2. Convert to Moltemplate .lt format with proper forcefield parameters
```
bash scripts/make_lt_from_data.sh data/Ag_slab.data
```
