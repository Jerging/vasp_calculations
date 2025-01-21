#!/usr/bin/bash

# Create lattice relaxation INCAR file and submit jobscript
echo -e "101\nLR" | vaspkit

# Submit Lattice relaxation jobscript
NEWID=$(sbatch jobscript | awk 'END {print $NF}')

# Debugging: Print the captured job ID
echo "Submitted job with ID: ${NEWID}"

# Check if the job ID is valid
if [[ -z ${NEWID} ]]; then
         echo "Error: Job ID not captured. Exiting."
         exit 1
fi

# Wait for the SLURM output file
while [ ! -f "vasp.${NEWID}.out" ]; do
        echo "Waiting for lattice relaxation with job ID: ${NEWID}..."
        sleep 10
done

echo "Lattice relaxation with job ID: ${NEWID} completed."
sleep 5
if [[ -f "vasp.${NEWID}.out" ]]; then
    if [[ -f "CONTCAR" && -f "KPOINTS" ]]; then
        cp CONTCAR ../relaxedPOSCAR
        cp KPOINTS ../relaxedKPOINTS
    else
        echo "Error: CONTCAR or KPOINTS not found."
    fi
fi

