#!/bin/bash

# Usage check
if [ $# -ne 1 ]; then
    echo "Usage: $0 <parent-directory-containing-scale-dirs>"
    exit 1
fi

PARENT_DIR="$1"
LOG_FILE="$PARENT_DIR/job_submissions.log"

if [ ! -d "$PARENT_DIR" ]; then
    echo "Error: Directory '$PARENT_DIR' does not exist."
    exit 1
fi

# Find and loop through scale_* subdirectories
echo "Submitting jobs from subdirectories in: $PARENT_DIR"
echo "Job submissions started at $(date)" > "$LOG_FILE"

for SCALE_DIR in "$PARENT_DIR"/scale_*; do
    if [ -d "$SCALE_DIR" ]; then
        JOBSCRIPT="$SCALE_DIR/jobscript"

        if [ -f "$JOBSCRIPT" ]; then
            pushd "$SCALE_DIR" > /dev/null
            JOB_ID=$(sbatch "$JOBSCRIPT" | awk '{print $NF}')
            popd > /dev/null
            echo "[$(date)] Submitted job from $SCALE_DIR (Job ID: $JOB_ID)" >> "$LOG_FILE"
        else
            echo "[$(date)] Skipped $SCALE_DIR (jobscript not found)" >> "$LOG_FILE"
        fi
    fi
done

echo "All eligible jobs submitted. Log written to: $LOG_FILE"

