#!/usr/bin/bash

# POSCAR system to study
SYSTEM="STO"
PSEUDO="PBE"

# KPOINTS
KPR="0.04"
KSCHEME="2"

# Setup directory architecture for future calculations
if ! mkdir -p "$SYSTEM"; then
    echo "Error: Failed to create directory $SYSTEM."
    exit 1
fi
cd "$SYSTEM" || { echo "Error: Failed to enter directory $SYSTEM."; exit 1; }

# Modify jobscript and copy initial POSCAR
if ! sed "s/SYSTEM/$SYSTEM/" ~/scripts/jobscript > jobscript.tmp; then
    echo "Error: Failed to modify jobscript for $SYSTEM."
    exit 1
fi
if ! cp ~/POSCARs/"$SYSTEM" POSCAR; then
    echo "Error: Failed to copy POSCAR for $SYSTEM."
    exit 1
fi

# Run vaspkit to initialize and append summary to README
if ! echo -e "01\n103" | vaspkit | awk '/Summary/,EOF' >> README; then
    echo "Error: Failed to generate VASPkit summary."
    exit 1
fi
mv POSCAR unrelaxedPOSCAR

# Setup subdirectories for different calculation types
for CALC in bands elastic phonons relax; do
    if ! mkdir -p "$CALC"; then
        echo "Error: Failed to create directory $CALC."
        exit 1
    fi
    if ! sed "s/CALC/$CALC/" jobscript.tmp > "$CALC/jobscript.tmp"; then
        echo "Error: Failed to modify jobscript for $CALC."
        exit 1
    fi
    if ! cp POTCAR "$CALC/"; then
        echo "Error: Failed to copy POTCAR file to $CALC."
        exit 1
    fi
done
rm -f jobscript.tmp

# Copy/create input files in relax subdirectory
if ! cp unrelaxedPOSCAR relax/POSCAR; then
    echo "Error: Failed to copy POSCAR file to relax directory."
    exit 1
fi

cd relax || { echo "Error: Failed to enter relax directory."; exit 1; }

# Run vaspkit for K-space generation
if ! echo -e "102\n$KSCHEME\n$KPR" | vaspkit | awk '/Summary/,/+---------------------------------------------------------------+/' >> README; then
    echo "Error: Failed to generate K-space using vaspkit."
    exit 1
fi
