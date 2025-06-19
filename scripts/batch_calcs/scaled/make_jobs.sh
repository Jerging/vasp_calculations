#!/usr/bin/env bash

# Usage check
if [ "$#" -ne 7 ]; then
    echo "Usage: $0 <CALC> <SYSTEM> <FUNCTIONAL> <NODE> <CORE> <QUEUE> <TIME>"
    exit 1
fi

CALC="$1"
SYSTEM="$2"
FUNC="$3"
NODE="$4"
CORE="$5"
QUEUE="$6"
TIME="$7"

root_dir=$(pwd)

# Loop through all matching calculation directories
find -type d -path "*/${FUNC}/${CALC}" | while read -r job_dir; do
    if [ -d "$job_dir" ]; then
        (
            cd "$job_dir" || { echo "[Error] Cannot enter $job_dir"; exit 1; }
            echo "[Info] Creating job in $job_dir"
            bash ~/scripts/make_job.sh "$CALC" "$SYSTEM" "$NODE" "$CORE" "$QUEUE" "$TIME"
        )
    else
        echo "[Skip] Directory $job_dir does not exist."
    fi
done


