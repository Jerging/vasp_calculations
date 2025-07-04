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
echo "Choose input method:"
echo "1) Choose individual indices"
echo "2) Choose range (start..end)"
read -rp "Select input method (1 or 2): " method

indices=()

if [[ "$method" == "1" ]]; then
  read -rp "Enter the indices of directories to chain, in order (space-separated): " -a indices
elif [[ "$method" == "2" ]]; then
  read -rp "Enter start index: " start_idx
  read -rp "Enter end index: " end_idx
  # Validate indices
  if ! [[ "$start_idx" =~ ^[0-9]+$ ]] || ! [[ "$end_idx" =~ ^[0-9]+$ ]]; then
    echo "Start and end must be integers."
    exit 1
  fi
  if (( start_idx < 0 || start_idx >= ${#ALL_DIRS[@]} )) || (( end_idx < 0 || end_idx >= ${#ALL_DIRS[@]} )); then
    echo "Indices out of range."
    exit 1
  fi
  # Build inclusive range (ascending or descending)
  if (( start_idx <= end_idx )); then
    for ((i=start_idx; i<=end_idx; i++)); do
      indices+=("$i")
    done
  else
    for ((i=start_idx; i>=end_idx; i--)); do
      indices+=("$i")
    done
  fi
else
  echo "Invalid input method selected."
  exit 1
fi

# Validate indices again for safety
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
echo

# Detect files in first directory and ask which to copy forward
FIRST_DIR="${DIRS[0]}"
echo "Files found in first directory ($FIRST_DIR):"
mapfile -t FILES < <(find "$FIRST_DIR" -maxdepth 1 -type f -printf "%f\n" | sort)

for i in "${!FILES[@]}"; do
  echo "  [$i] ${FILES[i]}"
done

read -rp "Enter numbers of files to copy forward (space-separated, blank = none): " -a files_to_copy_indices

# Validate file indices
for idx in "${files_to_copy_indices[@]:-}"; do
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 0 || idx >= ${#FILES[@]} )); then
    echo "Invalid file index: $idx"
    exit 1
  fi
done

FILES_TO_COPY=()
for idx in "${files_to_copy_indices[@]:-}"; do
  FILES_TO_COPY+=("${FILES[idx]}")
done

echo
echo "Files that will be copied forward: ${FILES_TO_COPY[*]:-(none)}"
echo

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
EOF

  # Copy selected files from previous step except for first step
  if (( i > 0 && ${#FILES_TO_COPY[@]} > 0 )); then
    for file in "${FILES_TO_COPY[@]}"; do
      cat >> "$JOBSCRIPT" << EOF
echo "Copying $file from previous directory"
cp -f "\$ROOT/${DIRS[i-1]}/$file" "$file"
EOF
    done
  fi

  cat >> "$JOBSCRIPT" << EOF

ibrun vasp_std
rc=\$?
if (( rc != 0 )); then
  echo "❌ VASP failed with code \$rc at $CUR"
  exit \$rc
fi
touch COMPLETED

cd "\$ROOT"

EOF
done

cat >> "$JOBSCRIPT" << EOF
echo "🎉 All calculations finished successfully."
EOF

chmod +x "$JOBSCRIPT"

echo "Jobscript '$JOBSCRIPT' created."
echo "Submitting jobscript with sbatch..."
sbatch "$JOBSCRIPT"

