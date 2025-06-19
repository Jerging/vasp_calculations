#!/usr/bin/env bash

# Usage check
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <CALC> <FUNCTIONAL>"
    exit 1
fi

CALC="$1"
FUNC="$2"
INCAR_TEMPLATE="INCARs/${CALC}_${FUNC}_INCAR"
LOGFILE="incar_copy.log"

# Ensure the INCAR template exists
if [ ! -f "$INCAR_TEMPLATE" ]; then
    echo "Error: INCAR template '$INCAR_TEMPLATE' not found." | tee -a "$LOGFILE"
    exit 1
fi

echo "=== Copying INCARs for $FUNC/$CALC ===" | tee -a "$LOGFILE"

# Locate target calculation directories
find . -type d -path "*/${FUNC}/${CALC}" | while read -r calc_dir; do
    incar_dest="${calc_dir}/INCAR"

    # Backup existing INCAR if present
    if [ -f "$incar_dest" ]; then
        backup="${incar_dest}.bak"
        mv "$incar_dest" "$backup"
        echo "[Backup] Existing INCAR moved to $backup" | tee -a "$LOGFILE"
    fi

    # Copy the INCAR template
    cp "$INCAR_TEMPLATE" "$incar_dest" && echo "[Success] INCAR copied to $incar_dest" | tee -a "$LOGFILE" || {
        echo "[Error] Failed to copy INCAR to $incar_dest" | tee -a "$LOGFILE"
        exit 1
    }
done

echo "=== Done ===" | tee -a "$LOGFILE"

