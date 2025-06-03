#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 6 ]; then
  echo "Usage: $0 <CALC> <SYSTEM> <NODE> <CORE> <QUEUE> <TIME>"
  exit 1
fi

# Assign input arguments to variables
CALC="$1"
SYSTEM="$2"
NODE="$3"
CORE="$4"
QUEUE="$5"
TIME="$6"

# Ask for an optional file with extra job commands
read -p "Enter path to extra commands file (or type 'none'): " EXTRAS_FILE

if [[ "$EXTRAS_FILE" != "none" && ! -f "$EXTRAS_FILE" ]]; then
  echo "Error: File '$EXTRAS_FILE' not found."
  exit 1
fi

# Write the main job script
cat > jobscript <<EOF
#!/bin/bash
#SBATCH -J ${CALC}_${SYSTEM}
#SBATCH -o vasp.%j.out
#SBATCH -e vasp.%j.err
#SBATCH -N ${NODE}
#SBATCH -n ${CORE}
#SBATCH -p ${QUEUE}
#SBATCH -t ${TIME}
#SBATCH -A PHY24018

module load vasp/6.3.0

echo "Job started on: \$(date)"
start_time=\$(date)

ibrun vasp_std > ${CALC}.out
vasp_exit_code=\$?

if [[ \$vasp_exit_code -ne 0 ]]; then
    echo "VASP exited with error code \$vasp_exit_code"
    echo "Job failed: \$(date)"
    exit 1
fi

if [[ -f OUTCAR ]] && grep -q "reached required accuracy" OUTCAR; then
    touch COMPLETED
    echo "VASP completed successfully and converged."
else
    echo "VASP finished but did not converge."
    exit 2
fi

end_time=\$(date)
echo "Job ended on: \$end_time"
EOF

# If a valid extras file was provided, append its contents
if [[ "$EXTRAS_FILE" != "none" ]]; then
  echo -e "\n# Additional user-supplied commands:" >> jobscript
  cat "$EXTRAS_FILE" >> jobscript
fi

echo "Robust job script with chosen parameters created!"
[[ "$EXTRAS_FILE" != "none" ]] && echo "Extra commands from '$EXTRAS_FILE' appended to jobscript."

