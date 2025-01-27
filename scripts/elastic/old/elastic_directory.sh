#!/bin/bash

eta=0.01

mkdir ./isoplus/
bash deform_poscar.sh ./isoplus $eta iso
cp ./INCAR ./isoplus/INCAR
cp ./POTCAR ./isoplus/POTCAR
cp ./KPOINTS ./isoplus/KPOINTS
cp ./jobscript ./isoplus/jobscript
mkdir ./isominus/
bsdash deform_poscar.sh ./isominus -$eta iso
cp ./INCAR ./isominus/INCAR
cp ./POTCAR ./isominus/POTCAR
cp ./KPOINTS ./isominus/KPOINTS
cp ./jobscript ./isominus/jobscript
mkdir ./tetraplus/
bash deform_poscar.sh ./tetraplus $eta tetra
cp ./INCAR ./tetraplus/INCAR
cp ./POTCAR ./tetraplus/POTCAR
cp ./KPOINTS ./tetraplus/KPOINTS
cp ./jobscript ./tetraplus/jobscript
mkdir ./tetraminus/
bash deform_poscar.sh ./tetraminus -$eta tetra
cp ./INCAR ./tetraminus/INCAR
cp ./POTCAR ./tetraminus/POTCAR
cp ./KPOINTS ./tetraminus/KPOINTS
cp ./jobscript ./tetraminus/jobscript

