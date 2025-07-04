#!/usr/bin/env bash

set -euo pipefail

ROOT=$PWD

# Find all POSCAR_scaled_* directories, sorted
mapfile -t ALL_DIRS < <(find . -maxdepth 1 -type d -name "POSCAR_scaled_*" | sort)

if [[ ${#ALL_DIRS[@]} -eq 0 ]]; then
  echo "No POSCAR_scaled_* directories found in $ROOT"
  exit 1
fi

echo "Found POSCAR_scaled_* directories:"
for i in "${!ALL_DIRS[@]}"; do
  d="${ALL_DIRS[i]#./}"
  echo "  [$i] $d"
done

echo
read -rp "Enter the indices of directories to chain, in order (space-separated): " -a indices

# Validate indices
for idx in "${indices[@]}"; do
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 0 || idx >= ${#ALL_DIRS[@]} )); then
    echo "Invalid index: $idx"
    exit 1
  fi
done

read -rp "Enter functional (e.g. PBEsol+U): " FUNC
read -rp "Enter calculation type (e.g. ICHARG_scf): " CALC

read -rp "Enter number of nodes (e.g. 1): " NODES
read -rp "Enter number of cores (e.g. 128): " CORES
read -rp "Enter queue/partition (e.g. normal): " QUEUE
read -rp "Enter walltime in HH:MM:SS (e.g. 48:00:00): " TIME

# Build full paths for selected directories
DIRS=()
for idx in "${indices[@]}"; do
  d="${ALL_DIRS[idx]#./}"
  full_dir="$d/$FUNC/$CALC"
  if [[ ! -d "$full_dir" ]]; then
    echo "Error: Directory does not exist: $full_dir"
    exit 1
  fi
  DIRS+=("$full_dir")
done

echo
echo "Creating jobscript with the following chain:"
for d in "${DIRS[@]}"; do
  echo "  $d"
done

JOBSCRIPT="chain_vasp_jobscript.sh"

cat > "$JOBSCRIPT" << EOF
#!/usr/bin/env bash
#SBATCH -J chain_vasp
#SBATCH -o chain_vasp.%j.out
#SBATCH -e chain_vasp.%j.err
#SBATCH -N $NODES
#SBATCH -n $CORES
#SBATCH -p $QUEUE
#SBATCH -t $TIME
#SBATCH -A PHY24018

module purge
module load intel/19.1.1 impi/19.0.9
module load vasp/6.3.0
export OMP_NUM_THREADS=1

ROOT="\$PWD"

EOF

for ((i=0; i < ${#DIRS[@]}; i++)); do
  CUR="${DIRS[i]}"
  cat >> "$JOBSCRIPT" << EOF
echo "▶ Running step $((i+1)) / ${#DIRS[@]} : $CUR"
cd "$CUR"

ibrun vasp_std
rc=\$?
if (( rc != 0 )); then
  echo "❌ VASP failed with code \$rc at $CUR"
  exit \$rc
fi
touch COMPLETED

EOF
  if (( i + 1 < ${#DIRS[@]} )); then
    NEXT="${DIRS[i+1]}"
    cat >> "$JOBSCRIPT" << EOF
echo "Copying CHGCAR → \$ROOT/$NEXT/CHGCAR"
cp -f CHGCAR "\$ROOT/$NEXT/CHGCAR"

EOF
  fi
  cat >> "$JOBSCRIPT" << EOF
cd "\$ROOT"

EOF
done

cat >> "$JOBSCRIPT" << EOF
echo "🎉 All calculations finished successfully."
EOF

chmod +x "$JOBSCRIPT"

echo
echo "Jobscript '$JOBSCRIPT' created."
echo "Submitting jobscript with sbatch..."
sbatch "$JOBSCRIPT"

