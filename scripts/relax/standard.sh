#!/usr/bin/bash
# Jobscript parameters
RQUEUE="vm-small"
RNODE="1"
RCORE="1"
RTIME="00:05:00"

# Generate jobscript with the appropriate parameters
sed -e "s/QUEUE/$RQUEUE/" -e "s/NODE/$RNODE/" -e "s/CORE/$RCORE/" -e "s/TIME/$RTIME/" -e "s/relax/std_rlx/" jobscript.tmp > jobscript
echo "mv CONTCAR POSCAR" >> jobscript
echo "touch std_finish" >> jobscript

# Submit standard relaxation jobscript
sbatch jobscript

# Wait for the "std_finish" file to indicate completion
while [ ! -f "std_finish" ]; do
    echo "Waiting for standard relaxation calculation to finish."
    sleep 10
done

# Cleanup and completion message
if [[ -f "std_finish" ]]; then
    rm std_finish
    echo "Standard relaxation calculation finished."
fi

