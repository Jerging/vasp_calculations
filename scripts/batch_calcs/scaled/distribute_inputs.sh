#!/usr/bin/env bash
# distribute_inputs_to_scaled.sh
# Run this script from within a CALC directory to copy selected files
# into all POSCAR_scaled_* subdirectories.

set -euo pipefail

ROOT=$PWD

###############################################################################
# 1. Discover files in current CALC directory (non-recursive)
###############################################################################
mapfile -t FILES < <(find . -maxdepth 1 -type f -printf "%f\n" | sort)

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No files found in $ROOT"
  exit 1
fi

echo "Files found in current directory ($ROOT):"
for i in "${!FILES[@]}"; do
  echo "  [$i] ${FILES[i]}"
done

read -rp "Enter numbers of files to copy (space-separated, blank = none): " -a files_to_copy_indices

if [[ ${#files_to_copy_indices[@]} -eq 0 ]]; then
  echo "No files selected. Exiting."
  exit 0
fi

# Validate indices
FILES_TO_COPY=()
for idx in "${files_to_copy_indices[@]}"; do
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 0 || idx >= ${#FILES[@]} )); then
    echo "Invalid file index: $idx"
    exit 1
  fi
  FILES_TO_COPY+=("${FILES[idx]}")
done

echo
echo "Selected files to copy: ${FILES_TO_COPY[*]}"
echo

###############################################################################
# 2. Find POSCAR_scaled_* directories
###############################################################################
mapfile -t TARGET_DIRS < <(find . -maxdepth 1 -type d -name "POSCAR_scaled_*" | sort)

if [[ ${#TARGET_DIRS[@]} -eq 0 ]]; then
  echo "No POSCAR_scaled_* directories found in $ROOT"
  exit 1
fi

echo "Copying selected files to the following directories:"
for d in "${TARGET_DIRS[@]}"; do
  echo "  $d"
done
echo

###############################################################################
# 3. Copy files into each POSCAR_scaled_* directory
###############################################################################
for d in "${TARGET_DIRS[@]}"; do
  for file in "${FILES_TO_COPY[@]}"; do
    echo "Copying $file → $d/$file"
    cp -f "$file" "$d/"
  done
done

echo
echo "✅ Files successfully copied to all POSCAR_scaled_* directories."

