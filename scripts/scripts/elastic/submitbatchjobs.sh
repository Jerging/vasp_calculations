#!/bin/bash
root_path=`pwd`
for cij in `ls -F | grep /$`; do
  cd ${root_path}/$cij
  for s in strain_*; do
    cd ${root_path}/$cij/$s
    echo `pwd`
    if [ ! -f COMPLETED ]; then
      sbatch jobscript
    else
      echo "Skipping ${s}, COMPLETED file found."
    fi
  done
done

