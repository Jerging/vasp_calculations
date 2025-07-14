#!/usr/bin/env bash
# debug_data_parser.sh
# Same functionality but with verbose debug info

set -u  # unset variables are errors; disable -e so we see all errors

RED="\033[0;31m"; GREEN="\033[0;32m"; CYAN="\033[0;36m"; RESET="\033[0m"

shopt -s nullglob
scaled_dirs=(POSCAR_scaled_*/)
shopt -u nullglob

if [[ ${#scaled_dirs[@]} -eq 0 ]]; then
    echo -e "${RED}❌  No POSCAR_scaled_* subdirectories found here.${RESET}"
    exit 1
fi

FUNC="$(basename "$(dirname "$PWD")")"
CALC="$(basename "$PWD")"
echo -e "${CYAN}Detected FUNC=${FUNC}  CALC=${CALC}${RESET}\n"

read -rp "Copy vasprun.xml files to summary folder? (y/n): " keep_xml
[[ $keep_xml =~ ^[Yy]$ ]] && COPY_XML=1 || COPY_XML=0

out_dir="${FUNC}_${CALC}"
mkdir -p "$out_dir/BAND_GAPS"
(( COPY_XML )) && mkdir -p "$out_dir/vasprun"
out_abs=$(realpath "$out_dir")

echo -e "Directory\tA(Å)\tB(Å)\tC(Å)\tEnergy(eV)" > "$out_abs/energies.dat"
echo -e "Directory\tA(Å)\tB(Å)\tC(Å)\tGap_eV\tFermi_E_eV" > "$out_abs/band_gaps.dat"
mag_file="$out_abs/magnetization.dat"; : > "$mag_file"

get_lengths () {
    local f=$1
    echo "Reading lattice vectors from $f"
    if [[ ! -f $f ]]; then
        echo -e "${RED}ERROR: Structural file $f not found.${RESET}"
        a_len=b_len=c_len="NA"
        return
    fi
    read -r ax ay az < <(awk 'NR==3{print $1,$2,$3}' "$f")
    read -r bx by bz < <(awk 'NR==4{print $1,$2,$3}' "$f")
    read -r cx cy cz < <(awk 'NR==5{print $1,$2,$3}' "$f")

    if [[ -z $ax || -z $bx || -z $cx ]]; then
        echo -e "${RED}ERROR: Could not read lattice vectors properly from $f.${RESET}"
        a_len=b_len=c_len="NA"
        return
    fi

    a_len=$(awk -v x=$ax -v y=$ay -v z=$az 'BEGIN{printf "%.4f",sqrt(x*x+y*y+z*z)}')
    b_len=$(awk -v x=$bx -v y=$by -v z=$bz 'BEGIN{printf "%.4f",sqrt(x*x+y*y+z*z)}')
    c_len=$(awk -v x=$cx -v y=$cy -v z=$cz 'BEGIN{printf "%.4f",sqrt(x*x+y*y+z*z)}')

    echo "Lattice lengths: A=$a_len, B=$b_len, C=$c_len"
}

total=0
converged=0
failed=()

for pos_dir in "${scaled_dirs[@]%/}"; do
    echo -e "\n${CYAN}Checking $pos_dir/...${RESET}"
    calc_path="$pos_dir"
    outcar="$calc_path/OUTCAR"
    if [[ ! -f $outcar ]]; then
        echo -e "${RED}No OUTCAR found in $calc_path. Skipping.${RESET}"
        continue
    fi

    (( total++ ))

    # Convergence check
    ok=false
    if [[ $CALC == relax ]]; then
        if grep -q "reached required accuracy" "$outcar"; then
            ok=true
            echo "Convergence check: 'reached required accuracy' FOUND"
        else
            echo "Convergence check: 'reached required accuracy' NOT found"
        fi
    else
        if grep -q "EDIFF is reached" "$outcar"; then
            ok=true
            echo "Convergence check: 'EDIFF is reached' FOUND"
        else
            echo "Convergence check: 'EDIFF is reached' NOT found"
        fi
    fi

    if ! $ok; then
        echo -e "${RED}Convergence not reached, skipping $pos_dir${RESET}"
        rm -f "$calc_path/COMPLETED"
        failed+=("$calc_path")
        continue
    fi

    # Structural file selection
    struct="$calc_path/POSCAR"
    if [[ $CALC == relax && -f $calc_path/CONTCAR ]]; then
        struct="$calc_path/CONTCAR"
    fi

    # Print first few lines of structural file
    echo "Preview of structure file ($struct):"
    head -5 "$struct" || echo "ERROR: Could not read structure file."

    # Prepare magnetization file header if needed
    if ! grep -q "^# Species" "$mag_file"; then
        symbols_line=$(awk 'NR==6{print}' "$struct")
        counts_line=$(awk 'NR==7{print}' "$struct")
        read -ra syms  <<< "$symbols_line"
        read -ra cnts  <<< "$counts_line"
        echo "# Species and atom index ranges (1-based):" >> "$mag_file"
        start=1
        for i in "${!syms[@]}"; do
            sym=${syms[i]}
            num=${cnts[i]}
            end=$(( start + num - 1 ))
            echo "# ${sym}: ${start}-${end}" >> "$mag_file"
            start=$(( end + 1 ))
        done
        echo >> "$mag_file"
    fi

    # Copy vasprun.xml if requested
    if (( COPY_XML )) && [[ -f $calc_path/vasprun.xml ]]; then
        mkdir -p "$out_abs/vasprun/$pos_dir"
        cp "$calc_path/vasprun.xml" "$out_abs/vasprun/$pos_dir/vasprun.xml"
        echo "Copied vasprun.xml for $pos_dir"
    fi

    # Extract energy
    energy_line=$(grep "free  energy" "$outcar" | tail -1)
    echo "Energy line: $energy_line"
    energy=$(echo "$energy_line" | awk '{print $5}')
    echo "Parsed energy: $energy"
    if [[ -z $energy ]]; then
        echo -e "${RED}Energy extraction failed for $pos_dir. Skipping.${RESET}"
        failed+=("$calc_path")
        continue
    fi

    # Extract lattice lengths
    get_lengths "$struct"

    # Append energy data
    echo -e "${pos_dir}\t${a_len}\t${b_len}\t${c_len}\t${energy}" >> "$out_abs/energies.dat"
    (( converged++ ))

    # Magnetization block extraction
    mag_block=$(awk '
        /magnetization \(x\)/ {found=1;buf="";getline;getline;next}
        /^$/ && found         {last=buf;found=0}
        found                 {buf=buf $0 ORS}
        END                   {print last}' "$outcar")

    if [[ -n $mag_block ]]; then
        echo "Magnetization block found for $pos_dir, length: ${#mag_block}"
        {
            echo "Directory: $pos_dir"
            echo "Lattice: A=${a_len} B=${b_len} C=${c_len}"
            echo "$mag_block"
            echo
        } >> "$mag_file"
    else
        echo "No magnetization block found in $pos_dir"
    fi

    # Band gap extraction
    (
        cd "$calc_path" || { echo "Failed to cd into $calc_path"; exit 1; }
        echo "Running vaspkit in $pos_dir ..."
        echo -e "303" | vaspkit > /dev/null
        mv -f KPOINTS KPOINTS_old 2>/dev/null || true
        mv -f KPATH.in KPOINTS 2>/dev/null || true
        echo -e "211" | vaspkit > /dev/null
        gap_file="$out_abs/BAND_GAPS/BAND_GAP_${pos_dir}"
        if [[ -f BAND_GAP ]]; then
            cp BAND_GAP "$gap_file"
            gap_val=$(awk '/Band Gap \(eV\):/   {print $6}' BAND_GAP)
            fermi_val=$(awk '/Fermi Energy \(eV\):/{print $6}' BAND_GAP)
            echo -e "${pos_dir}\t${a_len}\t${b_len}\t${c_len}\t${gap_val:-NA}\t${fermi_val:-NA}" >> "$out_abs/band_gaps.dat"
            echo "Band gap and Fermi energy extracted for $pos_dir"
        else
            echo "No BAND_GAP file generated in $pos_dir"
        fi
        mv -f KPOINTS KPATH.in 2>/dev/null || true
        mv -f KPOINTS_old KPOINTS 2>/dev/null || true
    )

done

# Summary
summary="$out_abs/convergence_summary.txt"
{
    echo "Convergence summary  ($FUNC, $CALC)"
    echo "Generated on $(date)"
    echo
    printf "%-10s %10s %10s\n" "Total" "Converged" "Failed"
    printf "%-10d %10d %10d\n" "$total" "$converged" "$((total-converged))"
    if ((${#failed[@]})); then
        echo -e "\n--- Unconverged or incomplete ---"
        printf '%s\n' "${failed[@]}"
    fi
} | tee "$summary"

echo -e "${GREEN}✓ Finished gathering results for ${FUNC}/${CALC}${RESET}"
echo -e "   → Energy         : ${CYAN}$out_abs/energies.dat${RESET}"
echo -e "   → Band gaps      : ${CYAN}$out_abs/band_gaps.dat${RESET}"
echo -e "   → Magnetization  : ${CYAN}$mag_file${RESET}"
echo -e "   → Summary        : ${CYAN}$summary${RESET}"
if (( COPY_XML )); then
    echo -e "   → vasprun.xml    : ${CYAN}$out_abs/vasprun/${RESET}"
fi

tar -zcf "${out_abs}.tar.gz" -C "$(dirname "$out_abs")" "$(basename "$out_abs")"
echo -e "   📦 Archived      : ${CYAN}${out_abs}.tar.gz${RESET}\n"

