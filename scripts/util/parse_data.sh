#!/usr/bin/env bash
# debug_data_parser_static.sh — non-interactive parser for static or relaxation VASP calculations

set -u
shopt -s nullglob

RED="\033[0;31m"; GREEN="\033[0;32m"; CYAN="\033[0;36m"; RESET="\033[0m"

# Default options
IS_RELAX=0
COPY_XML=0

print_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -r, --relax      Treat as relaxation calculation (check ionic convergence)"
    echo "  -x, --xml        Copy vasprun.xml files to output directory"
    echo "  -h, --help       Display this help message and exit"
    exit 0
}

# Parse options (support short and long)
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--relax)
            IS_RELAX=1
            shift
            ;;
        -x|--xml)
            COPY_XML=1
            shift
            ;;
        -h|--help)
            print_help
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${RESET}"
            print_help
            ;;
        *)
            break
            ;;
    esac
done

# Confirm config
if (( IS_RELAX )); then
    echo "Configuration: Relaxation calculation (ionic convergence checked)"
else
    echo "Configuration: Static calculation (electronic convergence checked)"
fi

if (( COPY_XML )); then
    echo "Option: vasprun.xml files will be copied"
else
    echo "Option: vasprun.xml files will NOT be copied"
fi

# Fixed get_lengths function
get_lengths() {
    local f="$1"

    if [[ ! -f "$f" ]]; then
        echo -e "❌ ERROR: File '$f' not found."
        a_len="NA"; b_len="NA"; c_len="NA"
        return 1
    fi

    # Read scale factor (line 2)
    local scale
    scale=$(sed -n '2p' "$f" | awk '{print $1}')

    if [[ -z "$scale" ]]; then
        echo -e "❌ ERROR: Could not read scale factor from '$f'"
        a_len="NA"; b_len="NA"; c_len="NA"
        return 1
    fi

    # Read lattice vectors (lines 3-5)
    local line3 line4 line5
    line3=$(sed -n '3p' "$f")
    line4=$(sed -n '4p' "$f") 
    line5=$(sed -n '5p' "$f")
    
    # Parse lattice vector components
    local ax ay az bx by bz cx cy cz
    read -r ax ay az <<< "$line3"
    read -r bx by bz <<< "$line4"
    read -r cx cy cz <<< "$line5"

    # Calculate lengths using the same method as the working debug script
    a_len=$(echo "$scale $ax $ay $az" | awk '{s=$1; x=$2; y=$3; z=$4; printf "%.6f", s * sqrt(x*x + y*y + z*z)}')
    b_len=$(echo "$scale $bx $by $bz" | awk '{s=$1; x=$2; y=$3; z=$4; printf "%.6f", s * sqrt(x*x + y*y + z*z)}')
    c_len=$(echo "$scale $cx $cy $cz" | awk '{s=$1; x=$2; y=$3; z=$4; printf "%.6f", s * sqrt(x*x + y*y + z*z)}')

    echo "Lattice lengths: A=${a_len} Å, B=${b_len} Å, C=${c_len} Å"
    return 0
}

# Discover OUTCARs
outcar_dirs=()
while IFS= read -r -d '' dir; do
    outcar_dirs+=("$(dirname "$dir")")
done < <(find . -maxdepth 2 -mindepth 2 -name "OUTCAR" -type f -print0)

if [[ ${#outcar_dirs[@]} -eq 0 ]]; then
    echo -e "${RED}❌  No directories with OUTCAR files found.${RESET}"
    exit 1
fi

IFS=$'\n' outcar_dirs=($(printf '%s\n' "${outcar_dirs[@]}" | sort -u))

echo -e "${CYAN}Found ${#outcar_dirs[@]} directories with OUTCAR files:${RESET}"
printf '  • %s\n' "${outcar_dirs[@]}"
echo

FUNC="$(basename "$(dirname "$PWD")")"
CALC="$(basename "$PWD")"
echo -e "${CYAN}Detected FUNC=${FUNC}  CALC=${CALC}${RESET}\n"

out_dir="${FUNC}_${CALC}"
mkdir -p "$out_dir"
(( COPY_XML )) && mkdir -p "$out_dir/vasprun"
out_abs="$(pwd)/$out_dir"

echo -e "Directory\tA(Å)\tB(Å)\tC(Å)\tEnergy(eV)" > "$out_abs/energies.dat"
mag_file="$out_abs/magnetization.dat"; : > "$mag_file"
atom_counts_file="$out_abs/atom_counts.dat"; : > "$atom_counts_file"

total=0
converged=0
failed=()

for calc_dir in "${outcar_dirs[@]}"; do
    calc_dir="${calc_dir#./}"
    [[ -z "$calc_dir" ]] && calc_dir="."

    echo -e "\n${CYAN}Checking $calc_dir/...${RESET}"
    outcar="$calc_dir/OUTCAR"
    ((total++))

    if (( IS_RELAX )); then
        if grep -q "reached required accuracy" "$outcar"; then
            echo "Convergence: Ionic relaxation successful"
        else
            echo -e "${RED}Convergence not reached, skipping $calc_dir${RESET}"
            failed+=("$calc_dir (Ionic not converged)")
            continue
        fi
    else
        if grep -q "EDIFF is reached" "$outcar"; then
            echo "Convergence: Electronic convergence reached"
        else
            echo -e "${RED}Convergence not reached, skipping $calc_dir${RESET}"
            failed+=("$calc_dir (Electronic not converged)")
            continue
        fi
    fi

    struct="$calc_dir/POSCAR"
    [[ $IS_RELAX -eq 1 && -f $calc_dir/CONTCAR ]] && struct="$calc_dir/CONTCAR"

    if [[ ! -f $struct ]]; then
        echo -e "${RED}No structural file found in $calc_dir. Skipping.${RESET}"
        failed+=("$calc_dir (No POSCAR/CONTCAR)")
        continue
    fi

    echo "Using structure file: $struct"

    offset=0
    if grep -qi "Selective dynamics" "$struct"; then
        offset=1
    fi

    symbols_line=$(awk "NR==$((6 + offset)){print}" "$struct")
    counts_line=$(awk "NR==$((7 + offset)){print}" "$struct")

    readarray -t syms < <(echo "$symbols_line" | awk '{for(i=1;i<=NF;i++) print $i}')
    readarray -t cnts < <(echo "$counts_line" | awk '{for(i=1;i<=NF;i++) print $i}')

    if [[ ${#cnts[@]} -eq 0 ]]; then
        echo -e "${RED}Failed to read atom counts from $struct. Skipping.${RESET}"
        failed+=("$calc_dir (Failed to read atom counts)")
        continue
    fi

    if ! grep -q "^# Directory" "$atom_counts_file"; then
        echo -ne "# Directory\t" >> "$atom_counts_file"
        for sym in "${syms[@]}"; do echo -ne "${sym}\t" >> "$atom_counts_file"; done
        echo "Total" >> "$atom_counts_file"
    fi

    total_atoms=0
    for num in "${cnts[@]}"; do
        if [[ $num =~ ^[0-9]+$ ]]; then
            ((total_atoms += num))
        else
            echo -e "${RED}Invalid atom count '$num' in $struct. Skipping.${RESET}"
            failed+=("$calc_dir (Invalid atom count)")
            continue 2
        fi
    done
    echo -ne "$calc_dir\t" >> "$atom_counts_file"
    for num in "${cnts[@]}"; do echo -ne "$num\t" >> "$atom_counts_file"; done
    echo "$total_atoms" >> "$atom_counts_file"

    if ! grep -q "^# Species" "$mag_file"; then
        echo "# Species and atom index ranges (1-based):" >> "$mag_file"
        start=1
        for i in "${!syms[@]}"; do
            if [[ ${cnts[i]} =~ ^[0-9]+$ ]]; then
                end=$((start + cnts[i] - 1))
                echo "# ${syms[i]}: ${start}-${end}" >> "$mag_file"
                start=$((end + 1))
            fi
        done
        echo -e "\n" >> "$mag_file"
    fi

    if ((COPY_XML)) && [[ -f "$calc_dir/vasprun.xml" ]]; then
        mkdir -p "$out_abs/vasprun/$calc_dir"
        cp "$calc_dir/vasprun.xml" "$out_abs/vasprun/$calc_dir/"
        echo "Copied vasprun.xml for $calc_dir"
    fi

    energy_line=$(grep -E "free  energy" "$outcar" | tail -1)
    if [[ $energy_line =~ TOTEN[[:space:]]*=[[:space:]]*([+-]?[0-9]+\.?[0-9]*(e[+-]?[0-9]+)?) ]]; then
        energy=${BASH_REMATCH[1]}
        echo "Parsed energy: $energy eV"
    else
        echo -e "${RED}Energy extraction failed for $calc_dir. Skipping.${RESET}"
        echo "Debug: energy_line = '$energy_line'"
        failed+=("$calc_dir (Energy extraction failed)")
        continue
    fi

    # Call the corrected get_lengths function
    if get_lengths "$struct"; then
        # Variables a_len, b_len, c_len should now be set
        echo "Successfully extracted lattice parameters"
    else
        echo -e "${RED}Failed to read lattice vectors from $struct. Skipping.${RESET}"
        failed+=("$calc_dir (Lattice read failed)")
        continue
    fi

    echo -e "$calc_dir\t$a_len\t$b_len\t$c_len\t$energy" >> "$out_abs/energies.dat"
    ((converged++))

    mag_block=$(awk '
        /magnetization \(x\)/ {
            found=1
            buf=""
            getline; getline
            next
        }
        found && /^$/ {
            if (buf) last_buf = buf
            buf=""
            found=0
            next
        }
        found {
            buf = buf $0 ORS
        }
        END {
            if (buf) print buf
            else if (last_buf) print last_buf
        }
    ' "$outcar")

    if [[ -n $mag_block ]]; then
        echo "Magnetization data found"
        {
            echo "Directory: $calc_dir"
            echo "Lattice: A=${a_len} B=${b_len} C=${c_len}"
            echo "$mag_block"
            echo
        } >> "$mag_file"
    else
        echo "No magnetization data found"
    fi
done

summary="$out_abs/convergence_summary.txt"
{
    echo "Convergence summary  ($FUNC, $CALC)"
    echo "Generated: $(date)"
    echo
    printf "%-10s %10s %10s\n" "Total" "Converged" "Failed"
    printf "%-10d %10d %10d\n" $total $converged $((total - converged))

    if ((${#failed[@]} > 0)); then
        echo -e "\n--- Unconverged/Failed ---"
        printf '  • %s\n' "${failed[@]}"
    fi
} | tee "$summary"

echo -e "${GREEN}\n✓ Finished gathering results for ${FUNC}/${CALC}${RESET}"
echo -e "   → Energy         : ${CYAN}$out_abs/energies.dat${RESET}"
echo -e "   → Magnetization  : ${CYAN}$mag_file${RESET}"
echo -e "   → Atom counts    : ${CYAN}$atom_counts_file${RESET}"
echo -e "   → Summary        : ${CYAN}$summary${RESET}"
(( COPY_XML )) && echo -e "   → vasprun.xml    : ${CYAN}$out_abs/vasprun/${RESET}"

if tar -zcf "${out_abs}.tar.gz" -C "$(dirname "$out_abs")" "$(basename "$out_abs")"; then
    echo -e "   📦 Archived      : ${CYAN}${out_abs}.tar.gz${RESET}"
else
    echo -e "${RED}   ⚠ Archive creation failed${RESET}"
fi

shopt -u nullglob
exit 0
