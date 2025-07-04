#!/usr/bin/env bash

# Usage:
# ./setup_followup_calcs.sh <OLD_FUNCTIONAL> <OLD_CALC> <NEW_FUNCTIONAL> <NEW_CALC> <FILES...>

if [ "$#" -lt 5 ]; then
  echo "Usage: $0 <OLD_FUNCTIONAL> <OLD_CALC> <NEW_FUNCTIONAL> <NEW_CALC> <FILES_TO_COPY...>"
  echo "Example: $0 HSE06 scf HSE06 nscf POSCAR KPOINTS POTCAR"
  exit 1
fi

OLD_FUNCTIONAL="$1"
OLD_CALC="$2"
NEW_FUNCTIONAL="$3"
NEW_CALC="$4"
shift 4
FILES_TO_COPY=("$@")

for scale_dir in POSCAR_scaled_*; do
  old_calc_dir="$scale_dir/$OLD_FUNCTIONAL/$OLD_CALC"
  new_calc_dir="$scale_dir/$NEW_FUNCTIONAL/$NEW_CALC"

  if [ ! -d "$old_calc_dir" ]; then
    echo "❌ Skipping: $old_calc_dir does not exist."
    continue
  fi

  if [ -d "$new_calc_dir" ]; then
    read -rp "⚠️  Target directory $new_calc_dir already exists. Skip? [y/N]: " user_choice
    case "$user_choice" in
      [Yy]* ) echo "⏭️  Skipping $new_calc_dir"; continue ;;
      * ) echo "📂 Overwriting or adding to $new_calc_dir" ;;
    esac
  else
    mkdir -p "$new_calc_dir"
  fi

  for file in "${FILES_TO_COPY[@]}"; do
    src="$old_calc_dir/$file"
    dst="$new_calc_dir/$file"

    if [ -f "$src" ]; then
      cp "$src" "$dst"
      echo "✅ Copied $src → $dst"
    else
      echo "⚠️  File not found: $src"
    fi
  done
done

echo "🎉 Setup complete: $NEW_FUNCTIONAL/$NEW_CALC with files: ${FILES_TO_COPY[*]}"

