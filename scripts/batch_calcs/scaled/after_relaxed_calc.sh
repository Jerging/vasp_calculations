#!/usr/bin/env bash

# Ensure correct number of arguments
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <OLD_FUNCTIONAL> <NEW_FUNCTIONAL> <NEWCALC> <POTCAR> <KPR> <KSCHEME>"
    echo "Example: $0 PBEsol HSE06 hybrid PBE 0.03 1"
    exit 1
fi

OLD_FUNCTIONAL="$1"
NEW_FUNCTIONAL="$2"
NEWCALC="$3"
POTCAR="$4"
KPR="$5"        # e.g., 1000 (k-points per reciprocal atom)
KSCHEME="$6"    # e.g., 1 for Monkhorst-Pack

# Find all CONTCAR files from relaxation calculations
find . -type f -path "./POSCAR_scaled_*/${OLD_FUNCTIONAL}/relax/CONTCAR" | while read -r contcar_path; do
    relax_dir=$(dirname "$contcar_path")
    old_func_dir=$(dirname "$relax_dir")
    scale_dir=$(dirname "$old_func_dir")
    scale_base=$(basename "$scale_dir")

    # Define new target directory for the follow-up calculation
    target_dir="$scale_dir/$NEW_FUNCTIONAL/$NEWCALC"
    mkdir -p "$target_dir" || {
        echo "❌ Failed to create $target_dir"
        exit 1
    }

    # Copy and rename CONTCAR → POSCAR
    cp "$contcar_path" "$target_dir/POSCAR" || {
        echo "❌ Failed to copy $contcar_path to $target_dir/POSCAR"
        exit 1
    }

    # Set up POTCAR selection for VASPKIT
    sed "s/PSEUDO/$POTCAR/" ~/.vaspkitbase > ~/.vaspkit

    # Run VASPKIT for structure info and KPOINTS
    (
        cd "$target_dir" || exit 1

        # Structure info
        echo -e "01\n103" | vaspkit | awk '/Summary/,EOF' > README || {
            echo "Error: vaspkit structure info failed in $target_dir"
            exit 1
        }

        # KPOINTS generation
        echo -e "102\n$KSCHEME\n$KPR" | vaspkit | awk '/Summary/,/+---------------------------------------------------------------+/' >> README || {
            echo "Error: K-points generation failed in $target_dir"
            exit 1
        }

        # Remove default INCAR if generated
        rm -f INCAR
    )

    echo "✅ Created: $target_dir/POSCAR from $contcar_path"
done

echo "🎉 All CONTCARs from $OLD_FUNCTIONAL migrated to $NEW_FUNCTIONAL/$NEWCALC with KPOINTS and structure summary."

