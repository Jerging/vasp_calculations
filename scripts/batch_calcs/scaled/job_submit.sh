#!/usr/bin/env bash

# Ensure correct number of arguments
if [ "$#" -ne 2 ]; then
	echo "Usage: $0 <CALC> <STRUCTURE> (./STRUCTURE/POSCAR_scaled_*/FUNCTIONAL/CALC/)"
    exit 1
fi

CALC="$1"
STRUCTURE="$2"
MAX_JOBS=20
root_dir=$(pwd)

# Define base structure directory
base_dir="calculations/$STRUCTURE"

if [ ! -d "$base_dir" ]; then
    echo "Error: $base_dir does not exist."
    exit 1
fi

# Find all calculation subdirectories matching the pattern
mapfile -t job_dirs < <(find "$base_dir" -type d -name "$CALC")

# Filter out jobs that already have a COMPLETED flag
pending_dirs=()
for dir in "${job_dirs[@]}"; do
    if [ ! -f "$dir/COMPLETED" ]; then
        pending_dirs+=("$dir")
    else
        echo "Skipping $dir (COMPLETED file found)"
    fi
done

submit_jobs() {
    local batch=("$@")
    for dir in "${batch[@]}"; do
        (
            cd "$dir" || exit 1
            if [ -f "jobscript" ]; then
                jobid=$(sbatch jobscript | awk '{print $NF}')
                echo "$jobid" > .jobid
                echo "Submitted job $jobid in $dir"
            else
                echo "No jobscript found in $dir"
            fi
        )
    done
}

wait_for_jobs() {
    local jobids=("$@")
    while true; do
        sleep 30
        still_running=0
        for id in "${jobids[@]}"; do
            if squeue -h -j "$id" &> /dev/null; then
                still_running=1
                break
            fi
        done
        if [ "$still_running" -eq 0 ]; then
            break
        fi
    done
}

# Submit in batches of MAX_JOBS
i=0
total=${#pending_dirs[@]}
while [ $i -lt $total ]; do
    batch=("${pending_dirs[@]:$i:$MAX_JOBS}")
    submit_jobs "${batch[@]}"

    # Gather job IDs
    jobids=()
    for dir in "${batch[@]}"; do
        if [ -f "$dir/.jobid" ]; then
            jobids+=("$(<"$dir/.jobid")")
        fi
    done

    echo "Waiting for ${#jobids[@]} job(s) to finish..."
    wait_for_jobs "${jobids[@]}"

    i=$((i + MAX_JOBS))
done

echo "Jobs are either submitted and/or completed."

