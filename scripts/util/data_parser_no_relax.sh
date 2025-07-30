#!/usr/bin/env bash
# debug_data_parser_static.sh — non-interactive parser for static VASP calculations

set -u  # error on unset variables
shopt -s nullglob

RED="\033[0;31m"; GREEN="\033[0;32m"; CYAN="\033[0;36m"; RESET="\033[0m"

scaled_dirs=(POSCAR_scaled_*/)
if [[ ${#scaled_dirs[@]} -eq 0 ]]; then
    echo -e "${RED}❌  No POSCAR_scaled_* subdirectories found.${RESET}"
    exit 1
fi

FUNC="$(basename "$(dirname "$PWD")")"
CALC="$(basename "$PWD")"
echo -e "${CYAN}Detected FUNC=${FUNC}  CALC=${CALC}${RESET}\n"

# Pre-answered prompts: No relaxation, Copy XML
IS_RELAX=0
COPY_XML=1
echo "Configuration: Static calculations (no relaxation), copying vasprun.xml files"

out_dir="${FUNC}_${CALC}"
mkdir -p "$out_dir"
(( COPY_XML )) && mkdir -p "$out_dir/vasprun"
out_abs="$(pwd)/$out_dir"

echo -e "Directory\tA(Å)\tB(Å)\tC(Å)\tEnergy(eV)" > "$out_abs/energies.dat"
echo -e "Directory\tA(Å)\tB(Å)\tC(Å)\tGap_eV\tFermi_E_eV" > "$out_abs/electronic_band.dat"
mag_file="$out_abs/magnetization.dat"; : > "$mag_file"
atom_counts_file="$out_abs/atom_counts.dat"; : > "$atom_counts_file"

get_lengths() {
    local f=$1
    echo "Reading lattice vectors from $f"
    if [[ ! -f $f ]]; then
        echo -e "${RED}ERROR: Structural file $f not found.${RESET}"
        a_len=b_len=c_len="NA"
        return 1
    fi
    
    local ax ay az bx by bz cx cy cz
    if ! { read -r ax ay az < <(awk 'NR==3{print $1,$2,$3}' "$f") &&
          read -r bx by bz < <(awk 'NR==4{print $1,$2,$3}' "$f") &&
          read -r cx cy cz < <(awk 'NR==5{print $1,$2,$3}' "$f"); }; then
        echo -e "${RED}ERROR: Could not read lattice vectors from $f.${RESET}"
        a_len=b_len=c_len="NA"
        return 1
    fi

    a_len=$(awk -v x=$ax -v y=$ay -v z=$az 'BEGIN{printf "%.4f", sqrt(x*x+y*y+z*z)}')
    b_len=$(awk -v x=$bx -v y=$by -v z=$bz 'BEGIN{printf "%.4f", sqrt(x*x+y*y+z*z)}')
    c_len=$(awk -v x=$cx -v y=$cy -v z=$cz 'BEGIN{printf "%.4f", sqrt(x*x+y*y+z*z)}')
    echo "Lattice lengths: A=$a_len, B=$b_len, C=$c_len"
}

total=0
converged=0
failed=()

for pos_dir in "${scaled_dirs[@]%/}"; do
    echo -e "\n${CYAN}Checking $pos_dir/...${RESET}"
    calc_path="$pos_dir"
    outcar="$calc_path/OUTCAR"
    ((total++))

    # Skip if OUTCAR missing
    if [[ ! -f $outcar ]]; then
        echo -e "${RED}No OUTCAR found in $calc_path. Skipping.${RESET}"
        failed+=("$calc_path (No OUTCAR)")
        continue
    fi

    # Convergence check
    if (( IS_RELAX )); then
        if grep -q "reached required accuracy" "$outcar"; then
            echo "Convergence: Ionic relaxation successful"
        else
            echo -e "${RED}Convergence not reached, skipping $pos_dir${RESET}"
            failed+=("$calc_path (Ionic not converged)")
            continue
        fi
    else
        if grep -q "EDIFF is reached" "$outcar"; then
            echo "Convergence: Electronic convergence reached"
        else
            echo -e "${RED}Convergence not reached, skipping $pos_dir${RESET}"
            failed+=("$calc_path (Electronic not converged)")
            continue
        fi
    fi

    # Structural file selection
    struct="$calc_path/POSCAR"
    [[ $IS_RELAX -eq 1 && -f $calc_path/CONTCAR ]] && struct="$calc_path/CONTCAR"
    echo "Using structure file: $struct"

    # Read atom counts
    symbols_line=$(awk 'NR==6{print}' "$struct")
    counts_line=$(awk 'NR==7{print}' "$struct")
    read -ra syms <<< "$symbols_line"
    read -ra cnts <<< "$counts_line"
    
    # Write atom counts header (once)
    if ! grep -q "^# Directory" "$atom_counts_file"; then
        echo -ne "# Directory\t" >> "$atom_counts_file"
        for sym in "${syms[@]}"; do echo -ne "${sym}\t" >> "$atom_counts_file"; done
        echo "Total" >> "$atom_counts_file"
    fi
    
    # Calculate and write atom counts
    total_atoms=0
    for num in "${cnts[@]}"; do ((total_atoms += num)); done
    echo -ne "$pos_dir\t" >> "$atom_counts_file"
    for num in "${cnts[@]}"; do echo -ne "$num\t" >> "$atom_counts_file"; done
    echo "$total_atoms" >> "$atom_counts_file"

    # Write magnetization header (once)
    if ! grep -q "^# Species" "$mag_file"; then
        echo "# Species and atom index ranges (1-based):" >> "$mag_file"
        start=1
        for i in "${!syms[@]}"; do
            end=$((start + cnts[i] - 1))
            echo "# ${syms[i]}: ${start}-${end}" >> "$mag_file"
            start=$((end + 1))
        done
        echo -e "\n" >> "$mag_file"
    fi

    # Copy vasprun.xml if requested
    if ((COPY_XML)) && [[ -f $calc_path/vasprun.xml ]]; then
        mkdir -p "$out_abs/vasprun/$pos_dir"
        cp "$calc_path/vasprun.xml" "$out_abs/vasprun/$pos_dir/"
        echo "Copied vasprun.xml for $pos_dir"
    fi

    # Extract energy - FIXED REGEX
    energy_line=$(grep -E "free  energy" "$outcar" | tail -1)
    if [[ $energy_line =~ TOTEN[[:space:]]*=[[:space:]]*([+-]?[0-9]+\.?[0-9]*) ]]; then
        energy=${BASH_REMATCH[1]}
        echo "Parsed energy: $energy eV"
    else
        echo -e "${RED}Energy extraction failed for $pos_dir. Skipping.${RESET}"
        echo "Debug: energy_line = '$energy_line'"
        failed+=("$calc_path (Energy extraction failed)")
        continue
    fi

    # Get lattice lengths
    get_lengths "$struct" || continue

    # Write energy data
    echo -e "$pos_dir\t$a_len\t$b_len\t$c_len\t$energy" >> "$out_abs/energies.dat"
    ((converged++))

    # Extract magnetization - get the last magnetization block
    mag_block=$(awk '
        /magnetization \(x\)/ {
            found=1
            buf=""
            getline  # skip header line
            getline  # skip dashes line
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
            echo "Directory: $pos_dir"
            echo "Lattice: A=${a_len} B=${b_len} C=${c_len}"
            echo "$mag_block"
            echo
        } >> "$mag_file"
    else
        echo "No magnetization data found"
    fi

    # Band structure and Fermi energy extraction
    gap_val="NA"; fermi_val="NA"
    if command -v vaspkit &>/dev/null && [[ -f "$calc_path/EIGENVAL" ]]; then
        echo "Running vaspkit for band structure analysis..."
        pushd "$calc_path" >/dev/null || continue
        
        # Step 1: Generate KPATH.in
        echo -e "303" | vaspkit >/dev/null 2>&1
        
        if [[ -f KPATH.in ]]; then
            # Step 2: Backup original KPOINTS and use KPATH.in
            [[ -f KPOINTS ]] && mv KPOINTS KPOINTS.tmp
            mv KPATH.in KPOINTS
            
            # Step 3: Generate band structure
            echo -e "211" | vaspkit >/dev/null 2>&1
            
            # Step 4: Restore original KPOINTS
            mv KPOINTS KPATH.in
            [[ -f KPOINTS.tmp ]] && mv KPOINTS.tmp KPOINTS
            
            # Step 5: Extract band gap and Fermi energy
            if [[ -f BAND_GAP ]]; then
                gap_val=$(awk '/Band Gap \(eV\):/   {print $6; exit}' BAND_GAP 2>/dev/null || echo "NA")
                fermi_val=$(awk '/Fermi Energy \(eV\):/{print $6; exit}' BAND_GAP 2>/dev/null || echo "NA")
                [[ $gap_val ]] || gap_val="NA"
                [[ $fermi_val ]] || fermi_val="NA"
                
                # Append BAND_GAP to combined file with directory header
                {
                    echo "=== $pos_dir ==="
                    cat BAND_GAP
                    echo
                } >> "$out_abs/combined_band_gaps.dat"
                
                echo "Band gap: ${gap_val}eV, Fermi: ${fermi_val}eV"
            else
                echo "vaspkit failed to generate BAND_GAP"
            fi
        else
            echo "vaspkit failed to generate KPATH.in"
        fi
        
        popd >/dev/null || exit
    else
        echo "Skipping band analysis (vaspkit/EIGENVAL missing)"
    fi

    # Write electronic band data
    echo -e "$pos_dir\t$a_len\t$b_len\t$c_len\t$gap_val\t$fermi_val" >> "$out_abs/electronic_band.dat"
done

# Final summary
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

# Final report
echo -e "${GREEN}\n✓ Finished gathering results for ${FUNC}/${CALC}${RESET}"
echo -e "   → Energy         : ${CYAN}$out_abs/energies.dat${RESET}"
echo -e "   → Electronic band: ${CYAN}$out_abs/electronic_band.dat${RESET}"
echo -e "   → Band gaps      : ${CYAN}$out_abs/combined_band_gaps.dat${RESET}"
echo -e "   → Magnetization  : ${CYAN}$mag_file${RESET}"
echo -e "   → Atom counts    : ${CYAN}$atom_counts_file${RESET}"
echo -e "   → Summary        : ${CYAN}$summary${RESET}"
(( COPY_XML )) && echo -e "   → vasprun.xml    : ${CYAN}$out_abs/vasprun/${RESET}"

# Archive results
if tar -zcf "${out_abs}.tar.gz" -C "$(dirname "$out_abs")" "$(basename "$out_abs")"; then
    echo -e "   📦 Archived      : ${CYAN}${out_abs}.tar.gz${RESET}"
else
    echo -e "${RED}   ⚠ Archive creation failed${RESET}"
fi

shopt -u nullglob
exit 0
