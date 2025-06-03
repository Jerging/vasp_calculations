#!/usr/bin/env bash

# Ensure correct number of arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <POSCARDIR> <KPR> <KSCHEME>"
    exit 1
fi

POSCARDIR="$1"
KPR="$2"
KSCHEME="$3"

mkdir -p "calculations" || { echo "Failed to create \"calculations\" directory."; exit 1; }

if [ ! -d "POSCARs/$POSCARDIR" ]; then
    echo "Error: $POSCARDIR directory not found."
    exit 1
fi

for poscar_file in "POSCARs/$POSCARDIR"/POSCAR_scaled_*; do
    fname=$(basename "$poscar_file")
    
    [[ "$fname" == "POSCAR" || "$fname" == "scales.txt" ]] && continue

    scaled_dir="calculations/$POSCARDIR/${fname}"
    mkdir -p "$scaled_dir" || exit 1
    cp "$poscar_file" "$scaled_dir/POSCAR" || exit 1

    for functional in LDA PBE PBEsol; do
        subdir="$scaled_dir/$functional/scf"
        mkdir -p "$subdir" || exit 1
        cp "$scaled_dir/POSCAR" "$subdir/POSCAR"

        # Write appropriate ~/.vaspkit file
        if [ "$functional" == "PBEsol" ]; then
            sed "s/PSEUDO/PBE/" ~/.vaspkitbase > ~/.vaspkit
        else
            sed "s/PSEUDO/$functional/" ~/.vaspkitbase > ~/.vaspkit
        fi

        # Run vaspkit for structure info
        (cd "$subdir" && echo -e "01\n103" | vaspkit | awk '/Summary/,EOF' > README) || {
            echo "Error: vaspkit structure info failed in $subdir"
            exit 1
        }

        # Run vaspkit for K-points
        (cd "$subdir" && echo -e "102\n$KSCHEME\n$KPR" | vaspkit | awk '/Summary/,/+---------------------------------------------------------------+/' >> README) || {
            echo "Error: K-points generation failed in $subdir"
            exit 1
        }

        # Clean up auto-generated INCAR
        (cd "$subdir" && rm -f INCAR) || {
            echo "Error: Failed to remove INCAR in $subdir"
            exit 1
        }
    done
done

echo "Setup complete for initial scaled scf calculations."

