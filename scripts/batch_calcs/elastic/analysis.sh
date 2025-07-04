#!/usr/bin/bash
TYPE="2"
DIM="3D"

sed -e "s/TYPE/$TYPE/" -e "s/DIM/$DIM/" ~/input_files/vaspkit/elastic_INPUT.in  > ./INPUT.in || { echo "Failed to modify INPUT.in for elastic calculation setup"; exit 1; }

if ! echo -e "02\n201" | vaspkit | awk '/Summary/,0' > README.tmp; then
    echo "Error: Failed to analyze elastic tensor."
    exit 1
fi

sed -e "s/meeted/met/" README.tmp > README
rm README.tmp

