#!/usr/bin/env bash

set -euo pipefail

echo "Available POSCAR_scaled_* directories:"
ls -d POSCAR_scaled_* 2>/dev/null || { echo "No POSCAR_scaled_* directories found."; exit 1; }

read -rp "Enter the source directory path (e.g., POSCAR_scaled_0.8/HSE06/preconverged_scf): " SRC_DIR

if [ ! -d "$SRC_DIR" ]; then
  echo "❌ Directory does not exist: $SRC_DIR"
  exit 1
fi

# Extract parts from SRC_DIR path: POSCAR_scaled_xxx/FUNCTIONAL/CALC/
# Using parameter expansion:
IFS='/' read -r poscar_scaled functional calc <<< "$SRC_DIR"

if [[ -z "$poscar_scaled" || -z "$functional" || -z "$calc" ]]; then
  echo "❌ Could not parse POSCAR_scaled, FUNCTIONAL, and CALCULATION from source path."
  echo "Expected format: POSCAR_scaled_xxx/FUNCTIONAL/CALCULATION"
  exit 1
fi

# Check required files exist in source
for file in INCAR jobscript; do
  if [ ! -f "$SRC_DIR/$file" ]; then
    echo "❌ Required file '$file' not found in $SRC_DIR"
    exit 1
  fi
done

echo "Copying INCAR and jobscript from $SRC_DIR to all other directories matching $poscar_scaled/$functional/$calc ..."

# Loop over all POSCAR_scaled_* directories
for scale_dir in POSCAR_scaled_*; do
  target_dir="$scale_dir/$functional/$calc"

  # Skip if target directory doesn't exist or is the source directory itself
  if [ ! -d "$target_dir" ]; then
    echo "⚠️  Target directory does not exist: $target_dir — skipping."
    continue
  fi

  if [ "$target_dir" == "$SRC_DIR" ]; then
    echo "⏭️  Skipping source directory itself: $target_dir"
    continue
  fi

  # Copy files
  for file in INCAR jobscript; do
    cp "$SRC_DIR/$file" "$target_dir/$file"
    echo "✅ Copied $file → $target_dir/$file"
  done
done

echo "🎉 All done!"

