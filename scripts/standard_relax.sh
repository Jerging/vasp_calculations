#!/usr/bin/bash

# Submit Standard relaxation jobscript
JOBID=$(sbatch jobscript | awk 'END {print $NF}')

# Debugging: Print the captured job ID
echo "Submitted job with ID: ${JOBID}"

# Check if the job ID is valid
if [[ -z ${JOBID} ]]; then
         echo "Error: Job ID not captured. Exiting."
         exit 1
fi

# Wait for the SLURM output file
while [ ! -f "vasp.${JOBID}.out" ]; do
        echo "Waiting for standard relaxation with job ID: ${JOBID}..."
        sleep 10
done

echo "Standard relaxation with job ID: ${JOBID} completed."

