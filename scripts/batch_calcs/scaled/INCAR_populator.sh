#!/usr/bin/env bash

# Ensure correct number of arguments
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <CALC>"
    exit 1
fi

CALC="$1"
INCAR_TEMPLATE="INCARs/${CALC}_INCAR"

# Check that the INCAR template exists
if [ ! -f "$INCAR_TEMPLATE" ]; then
    echo "Error: INCAR template '$INCAR_TEMPLATE' not found."
    exit 1
fi

# Use find to get all scf directories
find calculations -type d -path "*/scf" | while read -r scf_dir; do
    functional=$(basename "$(dirname "$scf_dir")")
    incar_dest="${scf_dir}/INCAR"

    cp "$INCAR_TEMPLATE" "$incar_dest" || {
        echo "Failed to copy INCAR to $incar_dest"
        exit 1
    }

    if [ "$functional" = "PBEsol" ]; then
        echo "GGA  =  PS           (PBEsol exchange-correlation)" >> "$incar_dest"
    fi

    echo "INCAR copied to $incar_dest"
done

