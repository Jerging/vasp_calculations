#!/bin/bash

# Check if the user provided all three arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 X Y Z"
    exit 1
fi

X=$1
Y=$2
Z=$3

# Loop over all directories matching POSCAR_scaled*/
for dir in POSCAR_scaled*/; do
    if [ -d "$dir" ]; then
        echo "🔍 Entering directory: $dir"
        cd "$dir" || continue

        python ~/scripts/structure/editor/scaling_factor_changer.py "$X" "$Y" "$Z"
        
        echo "✅ Finished with $dir"
        cd ..
    fi
done

