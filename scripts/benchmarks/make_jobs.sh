#!/usr/bin/env bash

# Usage: ./write_jobscript.sh <DIR> <CALC_NAME> <NODES> <CORES> <QUEUE> <TIME>
if [ "$#" -ne 6 ]; then
  echo "Usage: $0 <DIR> <CALC_NAME> <NODES> <CORES> <QUEUE> <TIME>"
  exit 1
fi

DIR="$1"
CALC="$2"
NODES="$3"
CORES="$4"
QUEUE="$5"
TIME="$6"

cat > "${DIR}/jobscript" <<EOF
#!/bin/bash
#SBATCH -J ${CALC}
#SBATCH -o ${CALC}.out
#SBATCH -e ${CALC}.err
#SBATCH -N ${NODES}
#SBATCH -n ${CORES}
#SBATCH -p ${QUEUE}
#SBATCH -t ${TIME}
#SBATCH -A PHY24018

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
