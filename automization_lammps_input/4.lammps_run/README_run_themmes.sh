#!/usr/bin/env bash
# Master SLURM LAMMPS workflow launcher

set -euo pipefail

# --------- User Settings ----------
LAMMPS=/opt/lammps/240829/bin/lmp_mpi    # Change to your LAMMPS mpi binary if needed
NNODES=1
NPROCS=32
PARTITION=long
WALLTIME="48:00:00"
BUILD_DIR=build
LOGDIR=logs
mkdir -p "$LOGDIR"
# ----------------------------------

submit_job () {
    STEP="$1"     # min, npt, nvt
    INFILE="$2"   # run.in.min ...
    JOBNAME="LAMMPS_${STEP}"
    OUTLOG="${LOGDIR}/${JOBNAME}.o.%j"
    ERRLOG="${LOGDIR}/${JOBNAME}.e.%j"

    cat > parallel_sh.lammps.slm <<EOF
#!/bin/bash
#SBATCH -J $JOBNAME
#SBATCH -N $NNODES
#SBATCH -n $NPROCS
#SBATCH -p $PARTITION
#SBATCH -o $OUTLOG
#SBATCH -e $ERRLOG
#SBATCH --time $WALLTIME

cd \$SLURM_SUBMIT_DIR

hostfile=\$(mktemp hostfile.XXXX)
srun hostname | sort -V > \$hostfile

echo Running on host \`hostname\`
echo Time is \`date\`
echo Directory is \`pwd\`
echo This jobs runs on the following processors:
echo \`cat \$hostfile\`

NPROCS=\`wc -l < \$hostfile\`
echo This job has allocated \$NPROCS cores

source /etc/profile.d/modules.sh
module purge >& /dev/null
module load slurm
module use /opt/intel/oneapi/modulefiles
module -s load debugger/latest
module -s load dpl/latest
module -s load compiler/latest
module -s load mkl/latest
module -s load vtune/latest
module -s load advisor/latest
export OMP_NUM_THREADS=1
module load ompi/5.0.6-ih

\$(which mpirun) -x OMP_NUM_THREADS -np \$NPROCS -machinefile \$hostfile $LAMMPS -in $INFILE >& lammps_${STEP}.log

[ -n "\$hostfile" -a  -e \$hostfile ] && rm -f \$hostfile
EOF

    echo "Submitting $STEP ..."
    JOBID=$(sbatch parallel_sh.lammps.slm | awk '{print $4}')
    echo "  → Submitted as SLURM JobID $JOBID"
}

# --- Main workflow ---
echo "== LAMMPS SLURM workflow launcher =="
echo "Logs will be stored in $LOGDIR/"

# 1. Minimization
submit_job min run.in.min

# 2. NPT equilibration
submit_job npt run.in.npt

# 3. NVT production
submit_job nvt run.in.nvt

echo "All jobs submitted! Check status with squeue or log files in $LOGDIR/"

