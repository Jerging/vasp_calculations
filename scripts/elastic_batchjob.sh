#!/usr/bin/bash

#Jobscript parameters
RQUEUE="vm-small"
RNODE="1"
RCORE="1"
RTIME="00:01:00"

sed -e "s/QUEUE/$RQUEUE/" -e "s/NODE/$RNODE/" -e "s/CORE/$RCORE/" -e "s/TIME/$RTIME/" jobscript > jobscript.tmp
mv jobscript.tmp jobscript

# Copy 'jobscript' to all directories matching the */*/ pattern and submit jobs.
for D in */*/; do
    if [ -d "$D" ]; then
        cp jobscript "$D" && cd "$D" || exit
        sbatch jobscript
        cd - > /dev/null || exit
    fi
done
