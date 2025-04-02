#!/bin/bash

# Check for required files
if [ ! -f "POSCAR" ]; then
    echo "Error: POSCAR file not found!"
    exit 1
fi

# Check if the user provided enough arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <output_directory> <eta> <deform>"
    exit 1
fi

# Parse input arguments
output_dir=$1
eta=$2
deform=$3

# Ensure the output directory exists
if [ ! -d "$output_dir" ]; then
    echo "Error: Directory $output_dir does not exist!"
    exit 1
fi

# Extract lattice vectors (assuming standard POSCAR format)
latvec1=$(awk 'NR==3 {print $1, $2, $3}' POSCAR)
latvec2=$(awk 'NR==4 {print $1, $2, $3}' POSCAR)
latvec3=$(awk 'NR==5 {print $1, $2, $3}' POSCAR)

# Call Python script to transform each lattice vector
new_latvec1=$(python3 $deform.py "$eta" $latvec1)
new_latvec2=$(python3 $deform.py "$eta" $latvec2)
new_latvec3=$(python3 $deform.py "$eta" $latvec3)

# Create a new POSCAR file with updated lattice vectors
awk -v A1="$new_latvec1" -v A2="$new_latvec2" -v A3="$new_latvec3" '
NR==3 {print A1; next}
NR==4 {print A2; next}
NR==5 {print A3; next}
{print $0}
' POSCAR > "$output_dir/POSCAR.new"

# Rename the updated file in the output directory
mv "$output_dir/POSCAR.new" "$output_dir/POSCAR"

echo "Updated POSCAR file has been saved to $output_dir/POSCAR"

