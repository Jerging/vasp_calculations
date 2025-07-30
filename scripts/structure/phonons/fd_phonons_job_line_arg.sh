#!/usr/bin/env bash
# fd_phonon_job.sh
# Automatically runs VASP in all subdirectories via SLURM (non-interactive version)

set -euo pipefail

# Default SLURM configuration
NODES=1
CORES=128
QUEUE="normal"
TIME="48:00:00"
ACCOUNT="PHY24018"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -n|--nodes)
            NODES="$2"
            shift 2
            ;;
        -c|--cores)
            CORES="$2"
            shift 2
            ;;
        -q|--queue)
            QUEUE="$2"
            shift 2
            ;;
        -t|--time)
            TIME="$2"
            shift 2
            ;;
        -a|--account)
            ACCOUNT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -n, --nodes    Number of nodes (default: 1)"
            echo "  -c, --cores    Number of cores (default: 128)"
            echo "  -q, --queue    Queue/partition (default: normal)"
            echo "  -t, --time     Walltime (default: 48:00:00)"
            echo "  -a, --account  Account name (default: PHY24018)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Job configuration
ROOT=$PWD
JOBSCRIPT="phonons_vasp_jobscript.sh"

###############################################################################
# 1. Discover all subdirectories
###############################################################################
mapfile -t DIRS < <(find . -maxdepth 1 -type d ! -name "." | sort | sed 's|^./||')

if [[ ${#DIRS[@]} -eq 0 ]]; then
  echo "No subdirectories found in $ROOT"
  exit 1
fi

echo "Found ${#DIRS[@]} subdirectories:"
printf '  %s\n' "${DIRS[@]}"
echo

###############################################################################
# 2. Generate SLURM jobscript with phonopy integration
###############################################################################
cat > "$JOBSCRIPT" << EOF
#!/usr/bin/env bash
#SBATCH -J phonons_vasp
#SBATCH -o phonons_vasp.%j.out
#SBATCH -e phonons_vasp.%j.err
#SBATCH -N $NODES
#SBATCH -n $CORES
#SBATCH -p $QUEUE
#SBATCH -t $TIME
#SBATCH -A $ACCOUNT

module purge
module intel/19.1.1  impi/19.0.9
module load vasp/6.3.0

export OMP_NUM_THREADS=1

ROOT="\$PWD"
DIRS=($(printf '"%s" ' "${DIRS[@]}"))

# Run VASP calculations
for DIR in "\${DIRS[@]}"; do
  echo "▶ Running VASP in \$DIR"
  cd "\$DIR"
  
  if [ -f "COMPLETED" ]; then
    echo "↪ Already completed - skipping"
    cd "\$ROOT"
    continue
  fi

  ibrun vasp_std || exit \$?
  touch COMPLETED
  cd "\$ROOT"
done

# Run phonopy after all VASP calculations complete
echo "⏳ Running phonopy to collect force constants..."
PHONOPY_FILES=()
for DIR in "\${DIRS[@]}"; do
  if [ -f "\$DIR/vasprun.xml" ]; then
    PHONOPY_FILES+=("\$DIR/vasprun.xml")
  else
    echo "⚠️ Warning: vasprun.xml not found in \$DIR"
  fi
done

if [ \${#PHONOPY_FILES[@]} -gt 0 ]; then
  echo "Processing \${#PHONOPY_FILES[@]} vasprun.xml files:"
  printf '  %s\n' "\${PHONOPY_FILES[@]}"
  
  # Run phonopy command
  phonopy -f "\${PHONOPY_FILES[@]}"
  
  if [ \$? -eq 0 ]; then
    echo "✅ Phonopy completed successfully"
  else
    echo "❌ Phonopy encountered an error"
    exit 1
  fi
else
  echo "❌ No vasprun.xml files found for phonopy processing"
  exit 1
fi

echo "🎉 All calculations and phonopy processing finished successfully."
EOF

###############################################################################
# 3. Submit job
###############################################################################
echo "Submitting job with:"
echo "  Nodes: $NODES  Cores: $CORES  Queue: $QUEUE  Time: $TIME"
sbatch "$JOBSCRIPT"
echo "Job submitted. Use 'squeue -u \$USER' to check status."
