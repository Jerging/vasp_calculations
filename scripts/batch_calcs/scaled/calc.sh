#!/usr/bin/env bash

# Ensure correct number of arguments
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <POSCARDIR> <CALC> <KPR> <KSCHEME>"
    exit 1
fi

POSCARDIR="$1"
CALC="$2"
KPR="$3"
KSCHEME="$4"

# Prompt user to select functionals
echo "Available functionals: LDA, PBE, PBEsol"
read -p "Enter desired functionals (comma-separated, e.g., PBE,LDA): " user_input

# Convert input into array
IFS=',' read -ra SELECTED_FUNCTIONALS <<< "$user_input"

# Validate input
VALID_FUNCTIONALS=("LDA" "PBE" "PBEsol")
for f in "${SELECTED_FUNCTIONALS[@]}"; do
    if [[ ! " ${VALID_FUNCTIONALS[*]} " =~ " ${f} " ]]; then
        echo "Error: Invalid functional '$f'. Allowed values: ${VALID_FUNCTIONALS[*]}"
        exit 1
    fi
done

mkdir -p "calculations" || { echo "Failed to create \"calculations\" directory."; exit 1; }

if [ ! -d "POSCARs/$POSCARDIR" ]; then
    echo "Error: POSCARs/$POSCARDIR directory not found."
    exit 1
fi

for poscar_file in "POSCARs/$POSCARDIR"/POSCAR_scaled_*; do
    fname=$(basename "$poscar_file")

    [[ "$fname" == "POSCAR" || "$fname" == "scales.txt" ]] && continue

    scaled_dir="calculations/$POSCARDIR/${fname}"
    mkdir -p "$scaled_dir" || exit 1
    cp "$poscar_file" "$scaled_dir/POSCAR" || exit 1

    for functional in "${SELECTED_FUNCTIONALS[@]}"; do
        subdir="$scaled_dir/$functional/$CALC"
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

echo "Setup complete for initial scaled $CALC calculations."

