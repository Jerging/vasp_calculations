#!/usr/bin/bash
TYPE="1"
DIM="3D"

cp ../relaxedPOSCAR ./POSCAR || { echo "Failed to add POSCAR to directory"; exit 1; }
cp ../relaxedKPOINTS ./KPOINTS || { echo "Falied to add KPPOINTS to directory"; exit 1; }
echo -e "01\n101\nDC" | vaspkit
sed -e "s/TYPE/$TYPE/" -e "s/DIM/$DIM/" ~/input_files/vaspkit/elastic_INPUT.in  > ./INPUT.in || { echo "Failed to modify INPUT.in for elastic calculation setup"; exit 1; }
echo -e "02\n201" | vaspkit
