#!/bin/bash
root_path=`pwd`
for cij in `ls -F | grep /$`; do
  cd ${root_path}/$cij
  for s in strain_*; do
    cd ${root_path}/$cij/$s
    echo `pwd`
    sbatch jobscript
  done
done

