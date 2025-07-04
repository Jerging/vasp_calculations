#!/usr/bin/env bash
# setup_calculations.sh
# Interactively choose a POSCAR set, then prepare calculation folders.

set -euo pipefail
shopt -s nullglob      # empty globs vanish

# ──────────────────────────
# 1. Parse remaining args
#    (POSCAR directory is chosen interactively, so 5 args now)
# ──────────────────────────
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <SYSTEM> <CALC> <KPR> <KSCHEME> <FUNCTIONAL>"
    exit 1
fi

SYS="$1"          # Designation to identify system studied
CALC="$2"         # Calculation type, e.g. scf, phonons, etc.
KPR="$3"          # K-point mesh, Gamma only: 0; Low: 0.06~0.04; Med: 0.04~0.03; High: 0.03~0.01
KSCHEME="$4"      # e.g. 1 for Monkhorst, 2 for Gamma centered, 3 for Irr. K-Points with Gamma Scheme
FUNC="$5"         # e.g. LDA, PBEsol+U, etc.

# ──────────────────────────
# 2. Discover candidate POSCAR sets
# ──────────────────────────
POSCAR_ROOT="POSCARs"
[[ -d "$POSCAR_ROOT" ]] || { echo "Error: '$POSCAR_ROOT' directory not found."; exit 1; }

declare -a CANDIDATES=()
for d in "$POSCAR_ROOT"/*/; do
    [[ -d "$d"        ]] || continue
    [[ -n $(find "$d" -maxdepth 1 -type f -name 'POSCAR*' -print -quit) ]] || continue
    CANDIDATES+=("$(basename "$d")")
done

if ((${#CANDIDATES[@]} == 0)); then
    echo "Error: No non-empty POSCAR sets found under '$POSCAR_ROOT/'."
    exit 1
fi

# ──────────────────────────
# 3. Let user choose
# ──────────────────────────
echo "Available POSCAR sets:"
PS3=$'\n↳ Select a POSCAR directory by number (or Ctrl-C to abort): '
select POSCARDIR in "${CANDIDATES[@]}"; do
    [[ -n "${POSCARDIR:-}" ]] && break
done
echo    # newline

echo "▶ Using POSCAR set: $POSCARDIR"
POSCAR_SOURCE="$POSCAR_ROOT/$POSCARDIR"

# ──────────────────────────
# 4. Choose POTCAR flavours
# ──────────────────────────
echo "Available POTCAR: LDA, PBE"
read -rp "Enter desired POTCAR (comma-separated, e.g., PBE,LDA): " user_input
IFS=',' read -ra SELECTED_POTCAR <<<"$user_input"

VALID_POTCAR=(LDA PBE)
for f in "${SELECTED_POTCAR[@]}"; do
    if [[ ! " ${VALID_POTCAR[*]} " =~ " ${f} " ]]; then
        echo "Error: Invalid POTCAR '$f'. Allowed: ${VALID_POTCAR[*]}"
        exit 1
    fi
done

# ──────────────────────────
# 5. Build calculation tree (FUNC/CALC/POSCAR_scaled*)
# ──────────────────────────
CALC_ROOT="${SYS}"
mkdir -p "$CALC_ROOT"

cp "$POSCAR_SOURCE/POSCAR" "$CALC_ROOT/${POSCARDIR}_POSCAR"

for poscar_file in "$POSCAR_SOURCE"/POSCAR_scaled_*; do
    fname=$(basename "$poscar_file")
    [[ "$fname" == "POSCAR" || "$fname" == "scales.txt" ]] && continue

    for potcar in "${SELECTED_POTCAR[@]}"; do
        subdir="$CALC_ROOT/$FUNC/$CALC/$fname"
        mkdir -p "$subdir"
        cp "$poscar_file" "$subdir/POSCAR"

        # Update ~/.vaspkit with chosen POTCAR
        sed "s/PSEUDO/$potcar/" ~/.vaspkitbase > ~/.vaspkit

        # ① vaspkit structure summary
        (cd "$subdir" && echo -e "01\n103" | vaspkit | awk '/Summary/,EOF' > STRUCTURE_INFO)

        # ② vaspkit K-points
        (cd "$subdir" && echo -e "102\n$KSCHEME\n$KPR" | vaspkit | \
            awk '/Summary/,/+---------------------------------------------------------------+/' >> STRUCTURE_INFO)

        # Remove auto INCAR (if any)
        rm -f "$subdir/INCAR"
    done
done

echo "🎉 Setup complete for initial scaled $CALC calculations of the $SYS system."
