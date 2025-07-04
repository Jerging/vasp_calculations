#!/usr/bin/env bash
# copy_incar_jobscript.sh
# Detect source dirs with both INCAR and jobscript, let the user pick one,
# then propagate those two files to all analogous POSCAR_scaled_* dirs.

set -euo pipefail

shopt -s nullglob

# ──────────────────────────────────────────────────────────────────────────────
# 1. Collect candidate source directories
#    POSCAR_scaled_*/FUNCTIONAL/CALC  that have *both* INCAR & jobscript
# ──────────────────────────────────────────────────────────────────────────────
declare -a candidates=()
while IFS= read -r d; do
    [[ -f "$d/INCAR" && -f "$d/jobscript" ]] && candidates+=("$d")
done < <(find POSCAR_scaled_* -type f -name INCAR -printf '%h\n' | sort -u)

if ((${#candidates[@]} == 0)); then
    echo "❌ No directories containing both INCAR and jobscript were found."
    exit 1
fi

echo "Detected directories with both INCAR and jobscript:"
PS3=$'\n↳ Choose the source directory by number (or Ctrl-C to quit): '
select SRC_DIR in "${candidates[@]}"; do
    [[ -n "${SRC_DIR:-}" ]] && break
done
echo   # newline for readability

# ──────────────────────────────────────────────────────────────────────────────
# 2. Parse POSCAR_scaled / FUNCTIONAL / CALC from chosen path
# ──────────────────────────────────────────────────────────────────────────────
IFS='/' read -r poscar_scaled functional calc <<<"$SRC_DIR"

if [[ -z "$poscar_scaled" || -z "$functional" || -z "$calc" ]]; then
    echo "❌ Could not parse POSCAR_scaled, FUNCTIONAL, CALC from: $SRC_DIR"
    echo "Expected pattern: POSCAR_scaled_xxx/FUNCTIONAL/CALC"
    exit 1
fi

echo "🔍 Source selected: $SRC_DIR"
echo "🔄 Will copy to all */$functional/$calc directories under POSCAR_scaled_* …"
echo

# ──────────────────────────────────────────────────────────────────────────────
# 3. Propagate INCAR + jobscript
# ──────────────────────────────────────────────────────────────────────────────
for scale_dir in POSCAR_scaled_*; do
    target_dir="$scale_dir/$functional/$calc"

    # skip non-existent dirs and the source itself
    [[ ! -d "$target_dir"        ]] && { echo "⚠️  Missing: $target_dir — skipping."; continue; }
    [[ "$target_dir" == "$SRC_DIR" ]] && { echo "⏭️  Skipping source itself: $target_dir"; continue; }

    for f in INCAR jobscript; do
        cp "$SRC_DIR/$f" "$target_dir/$f"
        echo "✅ Copied $f → $target_dir/$f"
    done
done

echo -e "\n🎉 All done!"

