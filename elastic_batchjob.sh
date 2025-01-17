#!/usr/bin/bash

# Copy 'jobscript' to all directories matching the */*/ pattern and submit jobs.
for D in */*/; do
    if [ -d "$D" ]; then
        cp jobscript "$D" && cd "$D" || exit
        sbatch jobscript
        cd - > /dev/null || exit
    fi
done
