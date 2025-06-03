#!/bin/bash

# Loop over all POSCAR-* files
for file in POSCAR-[0-9][0-9][0-9]; do
    # Extract the numeric suffix (e.g., 001)
    suffix="${file#POSCAR-}"
    
    # Create the directory if it doesn't exist
    mkdir -p "$suffix"
    
    # Copy fixed input files into the directory
    cp INCAR jobscript KPOINTS POTCAR "$suffix"/
    
    # Copy the numbered POSCAR file into the directory as "POSCAR"
    cp "$file" "$suffix/POSCAR"
    
    echo "Prepared directory: $suffix"
done
