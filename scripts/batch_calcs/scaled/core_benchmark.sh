#!/bin/bash
# benchmark.sh — submit VASP HSEsol scaling test on multiple core counts

CORE_COUNTS=(32 64 96 128)
BASE_DIR=$(pwd)

for NCORES in "${CORE_COUNTS[@]}"; do
    RUNDIR="run_${NCORES}"
    mkdir -p "$RUNDIR"
    cp INCAR POSCAR POTCAR KPOINTS "$RUNDIR/"
    
    cd "$RUNDIR"

    cat > jobscript <<EOF
#!/bin/bash
#SBATCH -J CuO_HSE_${NCORES}
#SBATCH -o vasp.%j.out
#SBATCH -e vasp.%j.err
#SBATCH -N 1
#SBATCH -n ${NCORES}
#SBATCH -p normal
#SBATCH -t 01:00:00
#SBATCH -A PHY24018

module load vasp/6.3.0
export OMP_NUM_THREADS=1

echo "Running on \${SLURM_NTASKS} cores"

ibrun vasp_std > HSEsol.out
EOF

    sbatch jobscript
    cd "$BASE_DIR"
done
