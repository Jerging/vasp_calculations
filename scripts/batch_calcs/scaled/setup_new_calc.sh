#!/usr/bin/env bash

set -euo pipefail

# --- 1. Descend into POSCAR_scaled* root if needed ---
function descend_to_poscar_scaled_root() {
  while true; do
    shopt -s nullglob
    dirs=(POSCAR_scaled_*/)
    shopt -u nullglob
    if (( ${#dirs[@]} > 0 )); then
      break
    fi
    mapfile -t subdirs < <(find . -maxdepth 1 -type d ! -name '.' | sed 's|^\./||' | sort)
    if (( ${#subdirs[@]} == 0 )); then
      echo "No subdirectories found. Cannot find POSCAR_scaled_* directories."
      exit 1
    fi
    echo "Current directory: $PWD"
    echo "No POSCAR_scaled_* directories found here."
    echo "Subdirectories:"
    for i in "${!subdirs[@]}"; do
      echo "  [$i] ${subdirs[i]}"
    done
    read -rp "Enter the number of the subdirectory to descend into: " idx
    if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 0 || idx >= ${#subdirs[@]} )); then
      echo "Invalid selection."
      exit 1
    fi
    cd "${subdirs[idx]}"
  done
}

descend_to_poscar_scaled_root

# --- 2. Scan for available FUNC and CALC in POSCAR_scaled_* dirs ---
declare -A FUNC_CALC_SET
for scale_dir in POSCAR_scaled_*; do
  for func in "$scale_dir"/*/; do
    [[ -d "$func" ]] || continue
    func_name=$(basename "$func")
    for calc in "$func"*/; do
      [[ -d "$calc" ]] || continue
      calc_name=$(basename "$calc")
      FUNC_CALC_SET["$func_name/$calc_name"]=1
    done
  done
done

# List unique FUNC/CALC pairs
FUNC_CALC_LIST=("${!FUNC_CALC_SET[@]}")
IFS=$'\n' FUNC_CALC_LIST=($(sort <<<"${FUNC_CALC_LIST[*]}"))
unset IFS

if (( ${#FUNC_CALC_LIST[@]} == 0 )); then
  echo "No FUNC/CALC directories found in POSCAR_scaled_* subdirectories."
  exit 1
fi

echo "Available calculation types:"
for i in "${!FUNC_CALC_LIST[@]}"; do
  echo "  [$i] ${FUNC_CALC_LIST[i]}"
done

read -rp "Select OLD calculation (FUNC/CALC) by number: " old_idx
if ! [[ "$old_idx" =~ ^[0-9]+$ ]] || (( old_idx < 0 || old_idx >= ${#FUNC_CALC_LIST[@]} )); then
  echo "Invalid selection."
  exit 1
fi
OLD_FUNC_CALC="${FUNC_CALC_LIST[old_idx]}"
OLD_FUNCTIONAL="${OLD_FUNC_CALC%%/*}"
OLD_CALC="${OLD_FUNC_CALC##*/}"

read -rp "Select NEW calculation (FUNC/CALC) by number: " new_idx
if ! [[ "$new_idx" =~ ^[0-9]+$ ]] || (( new_idx < 0 || new_idx >= ${#FUNC_CALC_LIST[@]} )); then
  echo "Invalid selection."
  exit 1
fi
NEW_FUNC_CALC="${FUNC_CALC_LIST[new_idx]}"
NEW_FUNCTIONAL="${NEW_FUNC_CALC%%/*}"
NEW_CALC="${NEW_FUNC_CALC##*/}"

# --- 3. Scan for available files in the first POSCAR_scaled_* old_calc_dir ---
FIRST_SCALE="POSCAR_scaled_*"
for d in $FIRST_SCALE; do
  if [ -d "$d/$OLD_FUNCTIONAL/$OLD_CALC" ]; then
    FIRST_OLD_DIR="$d/$OLD_FUNCTIONAL/$OLD_CALC"
    break
  fi
done

if [ -z "${FIRST_OLD_DIR:-}" ]; then
  echo "No $OLD_FUNCTIONAL/$OLD_CALC directory found in any POSCAR_scaled_*."
  exit 1
fi

mapfile -t FILES < <(find "$FIRST_OLD_DIR" -maxdepth 1 -type f -printf "%f\n" | sort)
if (( ${#FILES[@]} == 0 )); then
  echo "No files found in $FIRST_OLD_DIR."
  exit 1
fi

echo "Files available to copy from $FIRST_OLD_DIR:"
for i in "${!FILES[@]}"; do
  echo "  [$i] ${FILES[i]}"
done

read -rp "Enter numbers of files to copy (space-separated): " -a files_to_copy_indices

FILES_TO_COPY=()
for idx in "${files_to_copy_indices[@]:-}"; do
  if ! [[ "$idx" =~ ^[0-9]+$ ]] || (( idx < 0 || idx >= ${#FILES[@]} )); then
    echo "Invalid file index: $idx"
    exit 1
  fi
  FILES_TO_COPY+=("${FILES[idx]}")
done

echo "Copying files: ${FILES_TO_COPY[*]} from $OLD_FUNCTIONAL/$OLD_CALC to $NEW_FUNCTIONAL/$NEW_CALC in each POSCAR_scaled_* directory."

# --- 4. Copy files for each POSCAR_scaled_* directory ---
for scale_dir in POSCAR_scaled_*; do
  src_dir="$scale_dir/$OLD_FUNCTIONAL/$OLD_CALC"
  dst_dir="$scale_dir/$NEW_FUNCTIONAL/$NEW_CALC"

  if [ ! -d "$src_dir" ]; then
    echo "❌ Skipping: $src_dir does not exist."
    continue
  fi

  if [ -d "$dst_dir" ]; then
    read -rp "⚠️  Target directory $dst_dir already exists. Skip? [y/N]: " user_choice
    case "$user_choice" in
      [Yy]* ) echo "⏭️  Skipping $dst_dir"; continue ;;
      * ) echo "📂 Overwriting or adding to $dst_dir" ;;
    esac
  else
    mkdir -p "$dst_dir"
  fi

  for file in "${FILES_TO_COPY[@]}"; do
    src="$src_dir/$file"
    dst="$dst_dir/$file"

    if [ -f "$src" ]; then
      cp "$src" "$dst"
      echo "✅ Copied $src → $dst"
    else
      echo "⚠️  File not found: $src"
    fi
  done
done

echo "🎉 Setup complete: $NEW_FUNCTIONAL/$NEW_CALC with files:
