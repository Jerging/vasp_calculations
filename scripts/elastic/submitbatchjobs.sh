#!/bin/bash

# Save root path
ROOT_PATH=$(pwd)

echo "Starting job submissions from: $ROOT_PATH"
echo

# Loop over all subdirectories (e.g., cij directories)
for CIJ_DIR in */; do
    # Skip if not a directory
    [ -d "$CIJ_DIR" ] || continue

    echo "Entering: $CIJ_DIR"
    cd "$ROOT_PATH/$CIJ_DIR"

    # Loop over strain_* subdirectories
    for STRAIN_DIR in strain_*/; do
        [ -d "$STRAIN_DIR" ] || continue

        cd "$ROOT_PATH/$CIJ_DIR/$STRAIN_DIR"
        echo "  Processing: $(pwd)"

        if [ ! -f COMPLETED ]; then
            if [ -f jobscript ]; then
                JOB_ID=$(sbatch jobscript | awk '{print $NF}')
                echo "    → Submitted (Job ID: $JOB_ID)"
            else
                echo "    ✗ No jobscript found. Skipping."
            fi
        else
            echo "    ✓ Skipping — COMPLETED file found."
        fi
    done
    echo
done

echo "All submissions attempted."
