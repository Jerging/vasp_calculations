#!/usr/bin/env bash

# Usage check
if [ "$#" -ne 6 ]; then
    echo "Usage: $0 <FUNC> <CALC> <NODE> <CORE> <QUEUE> <TIME>"
    exit 1
fi

FUNC="$1"
CALC="$2"
NODE="$3"
CORE="$4"
QUEUE="$5"
TIME="$6"

root_dir=$(pwd)

# Loop through all matching calculation directories
find -type d -path "*/${FUNC}/${CALC}" | while read -r job_dir; do
    if [ -d "$job_dir" ]; then
        (
            cd $job_dir
            echo "[Info] Creating job in $job_dir"
            bash ~/scripts/make_job.sh "$CALC" "$NODE" "$CORE" "$QUEUE" "$TIME"
        )
    else
        echo "[Skip] Directory $job_dir does not exist."
    fi
    cd $root_dir
done


