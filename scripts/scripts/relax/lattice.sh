#!/usr/bin/bash

USERNAME="jerging27"

# Jobscript parameters
RQUEUE="vm-small"
RNODE="1"
RCORE="4"
RTIME="00:15:00"

# Prepare jobscript
sed -e "s/QUEUE/$RQUEUE/" -e "s/NODE/$RNODE/" -e "s/CORE/$RCORE/" -e "s/TIME/$RTIME/" -e "s/relax/lat_rlx/" jobscript.tmp > jobscript
echo "mv CONTCAR POSCAR" >> jobscript
echo "cp POSCAR ../POSCAR" >> jobscript
echo "cp KPOINTS ../KPOINTS" >> jobscript
echo "touch lat_finish" >> jobscript

# Debug: Show the final jobscript
echo "Generated jobscript:"
cat jobscript

# Create lattice relaxation INCAR file and submit jobscript
echo -e "101\nLR" | vaspkit

# Submit lattice relaxation jobscript
sbatch jobscript

# Wait for the "lat_finish" file to indicate completion
while [ ! -f "lat_finish" ]; do
    echo "Waiting for lattice relaxation calculation to finish..."
    sleep 10
done

# Cleanup and final message
rm lat_finish
echo "Lattice relaxation calculation finished."

