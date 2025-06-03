#!/bin/bash

usage() {
    echo "Usage: $0 <sub-directory-name> [--submit]"
    echo "  --submit   Submit jobscript via sbatch for each scale_* subdirectory"
    exit 1
}

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
    usage
fi

SUBDIR="$1"
SUBMIT=false
if [ $# -eq 2 ]; then
    if [ "$2" == "--submit" ]; then
        SUBMIT=true
    else
        usage
    fi
fi

BASEDIR=$(pwd)
REQUIRED_FILES=("INCAR" "jobscript" "KPOINTS" "POSCAR-unitcell" "POTCAR")

# Check required tools
for tool in phonopy vaspkit python3; do
    command -v $tool >/dev/null 2>&1 || { echo "Error: $tool not found in PATH."; exit 1; }
done

# Check if sub-directory exists
if [ ! -d "$SUBDIR" ]; then
    echo "Error: Directory '$SUBDIR' does not exist."
    exit 1
fi

# Check for required input files
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$SUBDIR/$file" ]; then
        echo "Error: Required file '$file' not found in '$SUBDIR'."
        exit 1
    fi
done

# User inputs
read -p "Enter percentage change (e.g., 5 for ±5%): " PERCENT
read -p "Enter number of increments (e.g., 5 for 5 increments on either side): " INCREMENTS
read -p "Enter supercell size (e.g., 2 2 2 for 2x2x2 supercells): " SUPERCELL

# Calculate percentage as float
PERCENT_FLOAT=$(echo "$PERCENT / 100" | bc -l)

for i in $(seq -$INCREMENTS $INCREMENTS); do
    SCALE=$(echo "1 + $i * ($PERCENT_FLOAT / $INCREMENTS)" | bc -l)
    SCALE_DIR=$(printf "%s/scale_%05.3f" "$SUBDIR" "$SCALE")

    mkdir -p "$SCALE_DIR"

    # Copy input files to new subdirectory
    for file in "${REQUIRED_FILES[@]}"; do
        cp "$SUBDIR/$file" "$SCALE_DIR/"
    done

    mv "$SCALE_DIR/POSCAR-unitcell" "$SCALE_DIR/POSCAR"

    python3 ~/scripts/structure_editor/scale_poscar.py "$SCALE_DIR/POSCAR" "$SCALE"

    echo "Created: $SCALE_DIR (scale factor: $SCALE)"

    pushd "$SCALE_DIR" > /dev/null

    phonopy -d --dim "$SUPERCELL" --pa auto -c POSCAR

    echo -e "03\n305\n3" | vaspkit > vaspkit_output.txt 2>&1

    if grep -q "Summary" vaspkit_output.txt; then
        echo "==== Scale Factor: $SCALE ====" >> README
        grep -A 10 "Summary" vaspkit_output.txt >> README
        echo "" >> README
    else
        echo "==== Scale Factor: $SCALE ====" >> README
        echo "No Summary found in VASPKIT output." >> README
        echo "" >> README
    fi

    if [ -f SPOSCAR ]; then
        mv POSCAR POSCAR-unitcell
        mv SPOSCAR POSCAR
    else
        echo "Warning: SPOSCAR not found. POSCAR was not replaced."
    fi

    # Optional: submit jobscript if --submit was given
    if [ "$SUBMIT" = true ]; then
        if [ -f jobscript ]; then
            JOB_SUBMIT_OUTPUT=$(sbatch jobscript 2>&1)
            if [[ "$JOB_SUBMIT_OUTPUT" =~ Submitted\ batch\ job\ ([0-9]+) ]]; then
                echo "Submitted job in $SCALE_DIR with Job ID: ${BASH_REMATCH[1]}"
            else
                echo "Failed to submit job in $SCALE_DIR: $JOB_SUBMIT_OUTPUT"
            fi
        else
            echo "Warning: jobscript not found in $SCALE_DIR, skipping submission."
        fi
    fi

    popd > /dev/null
done

# Generate summary README.master listing all scale directories
echo "Scale factors generated:" > "$SUBDIR/README.master"
for dir in "$SUBDIR"/scale_*/; do
    echo "- $(basename "$dir")" >> "$SUBDIR/README.master"
done

echo "✅ All structures generated inside: $SUBDIR"
if [ "$SUBMIT" = true ]; then
    echo "Jobs submitted for all scale directories where jobscript was present."
else
    echo "Run with --submit option to submit jobs automatically."
fi

