#!/bin/bash
# Update INCAR file with MAGMOM values from a MAGMOM file.
#
# This script:
# 1. Checks for presence of INCAR and MAGMOM files
# 2. Creates a backup of the original INCAR file
# 3. Updates INCAR with MAGMOM line from MAGMOM file
# 4. Overwrites existing MAGMOM line in INCAR if present

# Check for required files
if [[ ! -f "INCAR" ]]; then
    echo "Error: INCAR file not found in current directory"
    exit 1
fi

if [[ ! -f "MAGMOM" ]]; then
    echo "Error: MAGMOM file not found in current directory"
    exit 1
fi

echo "Found INCAR and MAGMOM files"

# Create backup of INCAR
timestamp=$(date +"%Y%m%d_%H%M%S")
backup_name="INCAR.backup_${timestamp}"

if ! cp "INCAR" "$backup_name"; then
    echo "Error creating backup"
    exit 1
fi
echo "Created backup: $backup_name"

# Read MAGMOM file content
if ! magmom_content=$(cat "MAGMOM"); then
    echo "Error reading MAGMOM file"
    exit 1
fi
echo "Read MAGMOM content: $magmom_content"

# Check if MAGMOM line exists in INCAR
if grep -qi "^MAGMOM" "INCAR"; then
    # Replace existing MAGMOM line
    if ! sed -i "/^[Mm][Aa][Gg][Mm][Oo][Mm]/c\\$magmom_content" "INCAR"; then
        echo "Error updating INCAR file"
        # Restore backup
        cp "$backup_name" "INCAR"
        echo "Restored INCAR from backup due to error"
        exit 1
    fi
    echo "Replaced existing MAGMOM line in INCAR"
else
    # Add new MAGMOM line at the end
    if ! echo "$magmom_content" >> "INCAR"; then
        echo "Error adding MAGMOM line to INCAR"
        # Restore backup
        cp "$backup_name" "INCAR"
        echo "Restored INCAR from backup due to error"
        exit 1
    fi
    echo "Added new MAGMOM line to INCAR"
fi

echo "INCAR update completed successfully"
