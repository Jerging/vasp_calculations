#!/usr/bin/env bash
# chain_vasp_launcher.sh
# Run inside a directory that contains subdirectories with strain_* folders.
# The script builds and submits a SLURM job that executes VASP
# in ALL strain_* directories across ALL top-level directories, copying selected files forward.

set -euo pipefail

ROOT=$PWD                 # Absolute path to current directory
JOBSCRIPT="chain_vasp_jobscript.sh"

###############################################################################
# 1. Discover top-level directories (C11_C12_I, C11_C12_II, C44, etc.)
###############################################################################
mapfile -t TOP_DIRS < <(find . -maxdepth 1 -type d ! -name "." | sort)

if [[ ${#TOP_DIRS[@]} -eq 0 ]]; then
  echo "No subdirectories found in $ROOT"
  exit 1
fi

echo "Found top-level directories:"
for i in "${!TOP_DIRS[@]}"; do
  d="${TOP_DIRS[i]#./}"
  echo "  $d"
done
echo

###############################################################################
# 2. Will run all top-level directories (no selection needed)
###############################################################################
echo "Will run all top-level directories and their strain subdirectories."
echo

###############################################################################
# 3. Discover all strain_* directories in all top-level directories
###############################################################################
ALL_DIRS=()
for top_dir in "${TOP_DIRS[@]}"; do
  top_dir_clean="${top_dir#./}"
  mapfile -t strain_dirs < <(find "$top_dir_clean" -maxdepth 1 -type d -name "strain_*" | sort)
  if [[ ${#strain_dirs[@]} -gt 0 ]]; then
    ALL_DIRS+=("${strain_dirs[@]}")
    echo "Found strain_* directories in $top_dir_clean:"
    for d in "${strain_dirs[@]}"; do
      echo "  $d"
    done
    echo
  fi
done

if [[ ${#ALL_DIRS[@]} -eq 0 ]]; then
  echo "No strain_* directories found in any top-level directory"
  exit 1
fi

###############################################################################
# 4. Will run all strain directories (no selection needed)
###############################################################################
echo "Will run all strain directories in order."

###############################################################################
# 5. SLURM resource prompts
###############################################################################
read -rp "Enter number of nodes     (e.g. 1):        " NODES
read -rp "Enter number of cores     (e.g. 128):      " CORES
read -rp "Enter queue/partition     (e.g. normal):   " QUEUE
read -rp "Enter walltime HH:MM:SS   (e.g. 48:00:00): " TIME
echo

###############################################################################
# 6. Use all directories (no selection needed)
###############################################################################
DIRS=("${ALL_DIRS[@]}")

echo "Will run calculations in all directories (in order):"
printf '  %s\n' "${DIRS[@]}"
echo

###############################################################################
# 7. Ask which files to copy forward
###############################################################################
FILES_TO_COPY=()

read -rp "Copy CHGCAR between steps? [y/N]: " ans
[[ "$ans" =~ ^[Yy]$ ]] && FILES_TO_COPY+=("CHGCAR")

read -rp "Copy WAVECAR between steps? [y/N]: " ans
[[ "$ans" =~ ^[Yy]$ ]] && FILES_TO_COPY+=("WAVECAR")

read -rp "Copy any additional files? (space-separated, leave blank for none): " -a extra_files
FILES_TO_COPY+=("${extra_files[@]}")

echo
echo "✅ Files that will be copied forward: ${FILES_TO_COPY[*]:-(none)}"
echo

# Prepare literal array expansions for jobscript
FILES_TO_COPY_LITERAL=$(printf '"%s" ' "${FILES_TO_COPY[@]}")
DIRS_LITERAL=$(printf '"%s" ' "${DIRS[@]}")


###############################################################################
# 8. Construct the SLURM jobscript
###############################################################################
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
DIRS=($DIRS_LITERAL)
FILES_TO_COPY=($FILES_TO_COPY_LITERAL)

for ((i=0; i<\${#DIRS[@]}; i++)); do
  CUR="\${DIRS[i]}"
  echo "▶ Running step \$((i+1)) / \${#DIRS[@]} : \$CUR"
  cd "\$CUR"

  if (( i > 0 && \${#FILES_TO_COPY[@]} > 0 )); then
    echo "↪ Copying forward files from previous directory: \${DIRS[i-1]}"
    for file in "\${FILES_TO_COPY[@]}"; do
      cp -f "\$ROOT/\${DIRS[i-1]}/\$file" "\$file"
    done
  fi

  ibrun vasp_std
  rc=\$?
  if (( rc != 0 )); then
    echo "❌ VASP failed with code \$rc in \$CUR"
    exit \$rc
  fi
  touch COMPLETED
  cd "\$ROOT"
done

echo "🎉 All calculations finished successfully."
EOF

###############################################################################
# 9. Submit
###############################################################################
echo "Jobscript '$JOBSCRIPT' created."
echo "Submitting with sbatch..."
sbatch "$JOBSCRIPT"
