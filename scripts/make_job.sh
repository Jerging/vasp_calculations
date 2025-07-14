#!/usr/bin/env bash
#
# Usage: ./write_jobscript.sh <CALC_NAME> <NODES> <CORES> <QUEUE> <TIME>

set -euo pipefail

if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <CALC_NAME> <NODES> <CORES> <QUEUE> <TIME>"
    exit 1
fi

CALC="$1"
NODES="$2"
CORES="$3"
QUEUE="$4"
TIME="$5"

###############################################################################
# 1. Write the base jobscript --------------------------------------------------
###############################################################################
cat > jobscript <<EOF
#!/bin/bash
#SBATCH -J ${CALC}
#SBATCH -o ${CALC}.out
#SBATCH -e ${CALC}.err
#SBATCH -N ${NODES}
#SBATCH -n ${CORES}
#SBATCH -p ${QUEUE}
#SBATCH -t ${TIME}
#SBATCH -A PHY24018

module purge
module load intel/19.1.1 impi/19.0.9   # prerequisites
module load vasp/6.3.0
export OMP_NUM_THREADS=1

start_time=\$(date +%s)
ibrun vasp_std > vasp.out
status=\$?
end_time=\$(date +%s)
elapsed=\$((end_time - start_time))

# Extract NSW from INCAR
NSW=\$(awk '/^NSW/ {print \$3}' INCAR)
NSW=\${NSW:-0}  # Default to 0 if not present

# Determine convergence status based on NSW
if [[ "\$NSW" -gt 0 ]]; then
    # Relaxation run
    if grep -q "reached required accuracy" OUTCAR; then
        conv_status="ionic_converged"
        touch COMPLETED
    elif grep -q "General timing and accounting" OUTCAR; then
        conv_status="relax_complete_but_not_converged"
        touch COMPLETED
    else
        conv_status="failed"
    fi
else
    # Static run
    if grep -q "General timing and accounting" OUTCAR; then
        conv_status="static_completed"
        touch COMPLETED
    else
        conv_status="failed"
    fi
fi
EOF

###############################################################################
# 2. Offer optional snippet additions -----------------------------------------
###############################################################################
ADDITIONS_DIR="$HOME/scripts/jobscript_additions"

if [ -d "$ADDITIONS_DIR" ] && compgen -G "$ADDITIONS_DIR"/* >/dev/null; then
    echo
    echo "Optional jobscript additions found in: $ADDITIONS_DIR"
    mapfile -t ADDITION_FILES < <(ls -1 "$ADDITIONS_DIR"/*)

    # Show a numbered list
    for i in "${!ADDITION_FILES[@]}"; do
        printf "  %2d) %s\n" "$((i + 1))" "$(basename "${ADDITION_FILES[i]}")"
    done
    echo

    read -rp "Enter numbers to append (e.g. 1 3 4), or press <Enter> for none: " CHOICES
    echo

    for idx in $CHOICES; do
        if [[ "$idx" =~ ^[0-9]+$ ]] && (( idx>=1 && idx<=${#ADDITION_FILES[@]} )); then
            FILE="${ADDITION_FILES[idx-1]}"
            echo ">>> Appending $(basename "$FILE")"
            {
                printf "\n# ===== Begin %s =====\n" "$(basename "$FILE")"
                cat "$FILE"
                printf "\n# ===== End %s =====\n"   "$(basename "$FILE")"
            } >> jobscript
        else
            echo ">>> Skipping invalid selection: '$idx'"
        fi
    done
else
    echo "No snippet files found in $ADDITIONS_DIR – skipping optional additions."
fi

echo -e "\n✅ Jobscript written to ./jobscript"

