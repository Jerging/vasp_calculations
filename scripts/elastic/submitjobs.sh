#!/usr/bin/env bash
# submit_strains.sh – walk CIJ/strain_* trees and sbatch every jobscript that
# isn’t already marked COMPLETED.

set -euo pipefail
shopt -s nullglob   # empty globs disappear instead of staying literal

ROOT_PATH=$(pwd)
echo "Starting job submissions from: $ROOT_PATH"
echo

# ──────────────────────────────────────────────────────────────────────
# Loop over top-level CIJ directories
# ──────────────────────────────────────────────────────────────────────
for CIJ_DIR in "$ROOT_PATH"/*/; do
    [[ -d "$CIJ_DIR" ]] || continue
    echo "Entering: $(basename "$CIJ_DIR")"

    # ──────────────────────────────────────────────────────────────
    # Loop over strain_* subdirectories
    # ──────────────────────────────────────────────────────────────
    for STRAIN_DIR in "$CIJ_DIR"/strain_*/; do
        [[ -d "$STRAIN_DIR" ]] || continue
        echo "  Processing: $STRAIN_DIR"

        if [[ ! -f "$STRAIN_DIR/COMPLETED" ]]; then
            if [[ -f "$STRAIN_DIR/jobscript" ]]; then
                pushd "$STRAIN_DIR" >/dev/null        # cd in safely
                JOB_ID=$(sbatch jobscript | awk '{print $NF}')
                popd >/dev/null                       # always return
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

