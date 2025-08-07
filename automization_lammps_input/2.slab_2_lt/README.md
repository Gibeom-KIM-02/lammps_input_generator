# 2.slab_2_lt Workflow

A simple pipeline for generating metal slab structures (FCC, BCC, HCP, etc.) as LAMMPS data files, and converting them to Moltemplate `.lt` files with auto-inserted forcefield parameters and crystal face (Miller index) selection.

---

## 📁 Directory Structure

slab_2_lt/  
├─ config/  
│ └─ metals.yaml # Forcefield parameters for metals (mass, sigma, epsilon), and structure with miller index
│  
├─ scripts/  
│ ├─ make_metal_slab.py # Python script: Build any slab (crystal type + Miller) and write .data file
│ └─ make_lt_from_data.sh # Bash script: Convert .data → .lt using metals.yaml  
│  
├─ data/ # Output: LAMMPS data files  
│ └─ Ag_slab.data  
│  
├─ lt/ # Output: Moltemplate .lt files  
│ └─ Ag.lt  
│  
├─ README_run_example.sh # Example end-to-end workflow script 
│  
└─ README.md 

---

## Workflow

1. **Edit or add metals in `config/metals.yaml`**  
   Each entry defines:
   - `structure`: crystal type (`fcc`, `bcc`, `hcp`, ...)
   - `miller`: surface orientation, e.g., `[1,1,1]` (FCC), `[1,1,0]` (BCC), `[0,0,0,1]` (HCP)
   - `mass`, `sigma`, `epsilon`: forcefield parameters

3. **Generate a LAMMPS data file for a slab**
   ```bash
   python scripts/make_metal_slab.py --elem Cu --size 4 4 3 --vac 12.0
   # or: python scripts/make_metal_slab.py --elem Fe --size 3 3 6
   #      python scripts/make_metal_slab.py --elem Zn --size 5 5 3 --vac 8
   # Structure, Miller index, and FF params are all read from config/metals.yaml

   # Output: data/<Elem>_slab.data
   ```

4. **Convert the data file to a Moltemplate .lt file**
   ```bash
   bash scripts/make_lt_from_data.sh data/Ag_slab.data
 
   Output: lt/Ag.lt
   ```
   
   **You can easily run the entire workflow (for Ag by default) by using `README_run_example.sh`**
   ```bash
   bash README_run_example.sh
   ```

---

## Example: Build and Convert a Silver (Ag) Slab
### 1. Generate a 4x4x3 Ag(111) slab (FCC, [1,1,1]) with 15 Å vacuum
```
python scripts/make_metal_slab.py --elem Ag --size 4 4 3 --vac 15.0
```
### 2. Convert to Moltemplate .lt format with proper forcefield parameters
```
bash scripts/make_lt_from_data.sh data/Ag_slab.data
```

---

### More Examples
### Cu(100) slab (FCC, [1,0,0])
```
python scripts/make_metal_slab.py --elem Cu --size 5 5 3 --vac 12.0
bash scripts/make_lt_from_data.sh data/Cu_slab.data
```
### Fe(110) slab (BCC, [1,1,0])
```
python scripts/make_metal_slab.py --elem Fe --size 3 3 6 --vac 10.0
bash scripts/make_lt_from_data.sh data/Fe_slab.data
```
### Zn(0001) slab (HCP, [0,0,0,1])
```
python scripts/make_metal_slab.py --elem Zn --size 4 4 3 --vac 8
bash scripts/make_lt_from_data.sh data/Zn_slab.data
```

---

### Notes
- All structural and forcefield parameters are managed in config/metals.yaml for easy extension.
- The slab construction is general: supports all lattices and faces that ASE and your metals.yaml define.
- You can add more metals, structures, or Miller indices by editing config/metals.yaml.
