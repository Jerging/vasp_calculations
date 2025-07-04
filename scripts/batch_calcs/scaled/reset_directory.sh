#!/usr/bin/env bash
#
# backup_and_reset.sh
# ---------------------------------------------------------------------------
# • Back up selected VASP calculation sub-directories under POSCAR_scaled_*
#   into a single .tar.gz archive.
# • Optionally exclude WAVECAR/CHGCAR from the archive.
# • After a successful backup, delete everything inside each selected
#   sub-directory except: INCAR, POTCAR, POSCAR, jobscript, KPOINTS, README.
# ---------------------------------------------------------------------------

set -euo pipefail
shopt -s nullglob         # patterns that match nothing expand to nothing

ALLOWED=(INCAR POTCAR POSCAR jobscript KPOINTS README)
BACKUP_ROOT="$(pwd)"

# ─── ANSI colours (for nicer prompts) ───────────────────────────────────────
RED=$(tput setaf 1)  GREEN=$(tput setaf 2)  YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6) RESET=$(tput sgr0)

trap 'echo -e "\n${RED}Aborted by user.${RESET}"; exit 1' INT

# ─── 1. Discover available functionals & calc-types ─────────────────────────
declare -A FUNC_MAP CALC_MAP

for d in POSCAR_scaled_*; do
    [[ -d $d ]] || continue
    for f in "$d"/*/; do
        func=$(basename "$f"); FUNC_MAP["$func"]=1
        for c in "$f"*/; do
            calc=$(basename "$c"); CALC_MAP["$calc"]=1
        done
    done
done

AVAILABLE_FUNCS=("${!FUNC_MAP[@]}")
AVAILABLE_CALCS=("${!CALC_MAP[@]}")

if [[ ${#AVAILABLE_FUNCS[@]} -eq 0 || ${#AVAILABLE_CALCS[@]} -eq 0 ]]; then
    echo "${RED}No valid calculation directories found. Exiting.${RESET}"
    exit 1
fi

# ─── 2. Let the user choose calc-types & functionals ────────────────────────
echo -e "${CYAN}Detected calculation types:${RESET} ${AVAILABLE_CALCS[*]}"
read -rp "Act on ALL calc-types? (y/n): " ans
if [[ $ans =~ ^[Yy]$ ]]; then
    SELECT_CALCS=("${AVAILABLE_CALCS[@]}")
else
    read -rp "Enter calc-types (comma-separated): " tmp
    IFS=',' read -ra SELECT_CALCS <<<"$tmp"
fi

echo -e "\n${CYAN}Detected functionals:${RESET} ${AVAILABLE_FUNCS[*]}"
read -rp "Act on ALL functionals? (y/n): " ans
if [[ $ans =~ ^[Yy]$ ]]; then
    SELECT_FUNCS=("${AVAILABLE_FUNCS[@]}")
else
    read -rp "Enter functionals (comma-separated): " tmp
    IFS=',' read -ra SELECT_FUNCS <<<"$tmp"
fi

# ─── 3. Ask about WAVECAR / CHGCAR ──────────────────────────────────────────
read -rp $'\nExclude WAVECAR and CHGCAR from the archive? (y/n): ' ans
if [[ $ans =~ ^[Yy]$ ]]; then
    EXCL_OPTS=(--exclude='*/WAVECAR' --exclude='*/CHGCAR')
    echo "⏭️  WAVECAR and CHGCAR will be excluded."
else
    EXCL_OPTS=()
fi

# ─── 4. Gather target sub-directories ───────────────────────────────────────
declare -a TARGET_DIRS

for poscar in POSCAR_scaled_*; do
  for func in "${SELECT_FUNCS[@]}"; do
    for calc in "${SELECT_CALCS[@]}"; do
        sub="$poscar/$func/$calc"
        [[ -d $sub ]] && TARGET_DIRS+=("$sub")
    done
  done
done

if [[ ${#TARGET_DIRS[@]} -eq 0 ]]; then
    echo "${YELLOW}No matching sub-directories found. Nothing to do.${RESET}"
    exit 0
fi

echo -e "\n${CYAN}Sub-directories to back up & reset:${RESET}"
printf '  • %s\n' "${TARGET_DIRS[@]}"
read -rp $'\nProceed? (y/n): ' confirm
[[ $confirm =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }

# ─── 5. Create archive ─────────────────────────────────────────────────────
timestamp=$(date +%Y%m%d_%H%M%S)
archive="vasp_backup_${timestamp}.tar.gz"

echo -e "\n${GREEN}📦 Creating archive:${RESET} $archive"
tar "${EXCL_OPTS[@]}" -czf "$archive" "${TARGET_DIRS[@]}"
echo "${GREEN}✔ Archive complete.${RESET}"

# ─── 6. Reset each directory (keep only ALLOWED files) ─────────────────────
echo -e "\n${CYAN}Resetting directories…${RESET}"
for sub in "${TARGET_DIRS[@]}"; do
    echo "  Cleaning $sub"
    for item in "$sub"/*; do
        base=$(basename "$item")
        if [[ ! " ${ALLOWED[*]} " =~ " $base " ]]; then
            rm -rf -- "$item"
        fi
    done
done
echo "${GREEN}✔ Reset finished.${RESET}"

echo -e "\n${GREEN}Done!${RESET}"
echo "  Archive: ${archive}"
echo "  Directories cleaned but remain in place for future runs."

