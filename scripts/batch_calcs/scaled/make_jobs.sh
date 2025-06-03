#!/usr/bin/env bash

# Ensure correct number of arguments
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <CALC> <SYSTEM> <NODE> <CORE> <QUEUE> <TIME>"
    exit 1
fi

# Assign the input arguments
CALC="$1"
SYSTEM="$2"
NODE="$3"
CORE="$4"
QUEUE="$5"
TIME="$6"

root_dir=$(pwd)

# Loop through all SCF calculation directories
find calculations -type d -path "calculations/$SYSTEM/*/$CALC" | while read -r calc_dir; do
    job_dir="$calc_dir"
    
    if [ -d "$job_dir" ]; then
        (
            cd "$job_dir" || { echo "Failed to enter $job_dir"; exit 1; }
            bash ~/scripts/make_job.sh "$CALC" "$SYSTEM" "$NODE" "$CORE" "$QUEUE" "$TIME"
        )
    else
        echo "Directory $job_dir does not exist, skipping."
    fi
done

