#!/usr/bin/env bash

# ────────────────────────────── COLOR SETUP ──────────────────────────────
RED="\033[0;31m"; GREEN="\033[0;32m"; CYAN="\033[0;36m"; RESET="\033[0m"

# ───────────────────── DETECT FUNCTIONALS AND CALC TYPES ────────────────
declare -A FUNC_MAP CALC_MAP
for poscar in POSCAR_scaled_*; do
    [[ -d $poscar ]] || continue
    for func_dir in "$poscar"/*/; do
        func=$(basename "$func_dir") ; FUNC_MAP["$func"]=1
        for calc_dir in "$func_dir"*/; do
            calc=$(basename "$calc_dir") ; CALC_MAP["$calc"]=1
        done
    done
done

AVAILABLE_FUNCTIONALS=("${!FUNC_MAP[@]}")
AVAILABLE_CALCS=("${!CALC_MAP[@]}")

if [[ ${#AVAILABLE_FUNCTIONALS[@]} -eq 0 || ${#AVAILABLE_CALCS[@]} -eq 0 ]]; then
    echo -e "${RED}No valid POSCAR_scaled_* hierarchy found — nothing to do.${RESET}"
    exit 1
fi

# ────────────────────────────── USER INPUT ───────────────────────────────
echo -e "${CYAN}Detected calculation types:${RESET} ${AVAILABLE_CALCS[*]}"
read -rp "Collect ALL calc-types? (y/n): " ans
if [[ $ans =~ ^[Yy]$ ]]; then
    SELECTED_CALCS=("${AVAILABLE_CALCS[@]}")
else
    read -rp "Enter calc-types (comma-separated): " tmp
    IFS=',' read -ra SELECTED_CALCS <<< "$tmp"
fi

echo -e "\n${CYAN}Detected functionals:${RESET} ${AVAILABLE_FUNCTIONALS[*]}"
read -rp "Collect ALL functionals? (y/n): " ans
if [[ $ans =~ ^[Yy]$ ]]; then
    SELECTED_FUNCS=("${AVAILABLE_FUNCTIONALS[@]}")
else
    read -rp "Enter functionals (comma-separated): " tmp
    IFS=',' read -ra SELECTED_FUNCS <<< "$tmp"
fi

# ────────────────────────── USER INPUT FOR MAGNETIZATION GROUP SIZES ──────
read -rp "Enter number of atoms to sum for Group A magnetization (default 4): " groupA
groupA=${groupA:-4}
read -rp "Enter number of atoms to sum for Group B magnetization (default 4): " groupB
groupB=${groupB:-4}

# ────────────────────────── HELPER FUNCTION ──────────────────────────────
get_lengths () {
    local file=$1
    read -r ax ay az < <(awk 'NR==3{print $1,$2,$3}' "$file")
    read -r bx by bz < <(awk 'NR==4{print $1,$2,$3}' "$file")
    read -r cx cy cz < <(awk 'NR==5{print $1,$2,$3}' "$file")
    a_len=$(awk -v x=$ax -v y=$ay -v z=$az 'BEGIN{printf "%.4f",sqrt(x*x+y*y+z*z)}')
    b_len=$(awk -v x=$bx -v y=$by -v z=$bz 'BEGIN{printf "%.4f",sqrt(x*x+y*y+z*z)}')
    c_len=$(awk -v x=$cx -v y=$cy -v z=$cz 'BEGIN{printf "%.4f",sqrt(x*x+y*y+z*z)}')
}

# ────────────────────────────── MAIN LOOP ────────────────────────────────
for CALC in "${SELECTED_CALCS[@]}"; do
    for FUNC in "${SELECTED_FUNCS[@]}"; do
        out_dir="${FUNC}_${CALC}"
        mkdir -p "$out_dir/BAND_GAPS"
        mkdir -p "$out_dir/vasprun"
        vasprun_path="$out_dir/vasprun"
        out_dir_abs=$(realpath "$out_dir")

        echo -e "Directory\tA(Å)\tB(Å)\tC(Å)\tEnergy(eV)" > "$out_dir_abs/energies.dat"
        echo -e "Directory\tA(Å)\tB(Å)\tC(Å)\tGap_eV\tFermi_E_eV" > "$out_dir_abs/band_gaps.dat"
        
        # Write header with group sizes to magnetization.dat for parsing
        echo -e "# Group A atoms: $groupA" > "$out_dir_abs/magnetization.dat"
        echo -e "# Group B atoms: $groupB" >> "$out_dir_abs/magnetization.dat"
        echo "" >> "$out_dir_abs/magnetization.dat"

        total=0; converged=0; failed=()

        for poscar in POSCAR_scaled_*; do
            calc_path="$poscar/$FUNC/$CALC"
            outcar="$calc_path/OUTCAR"
            [[ -f $outcar ]] || continue
            total=$((total+1))

            ok=false
            if [[ $CALC == relax ]]; then
                grep -q "reached required accuracy" "$outcar" && ok=true
            else
                grep -q "EDIFF is reached" "$outcar" && ok=true
            fi
            if ! $ok; then
                rm -f "$calc_path/COMPLETED"
                failed+=("$calc_path")
                continue
            fi

            mkdir -p "$vasprun_path/$poscar"
            cp "$calc_path/vasprun.xml" "$vasprun_path/$poscar/vasprun.xml"
            struct="$calc_path/POSCAR"
            [[ $CALC == relax && -f $calc_path/CONTCAR ]] && struct="$calc_path/CONTCAR"
            energy=$(grep "free  energy" "$outcar" | tail -1 | awk '{print $5}') || true
            [[ -z $energy ]] && { failed+=("$calc_path"); continue; }

            get_lengths "$struct"
            tag=$(basename "$poscar")
            echo -e "${tag}\t${a_len}\t${b_len}\t${c_len}\t${energy}" >> "$out_dir_abs/energies.dat"
            converged=$((converged+1))

            fermi_line=$(grep "BZINTS: Fermi energy" "$outcar" | tail -1 || true)
            band_line=$(grep "Band energy" "$outcar" | tail -1 || true)
            fermi_energy=$(awk '{for(i=1;i<NF;i++) if($i=="energy:") {print $(i+1); exit}}' <<<"$fermi_line")

            # Append magnetization block
            mag_block=$(awk '
                /magnetization \(x\)/ {found=1;buf="";getline;getline;next}
                /^$/ && found {last=buf;found=0}
                found {buf=buf $0 ORS}
                END {print last}' "$outcar")

            if [[ -n $mag_block ]]; then
                {
                    echo "Directory: $tag"
                    echo "Lattice: A=${a_len} B=${b_len} C=${c_len}"
                    echo "$mag_block"
                    echo
                } >> "$out_dir_abs/magnetization.dat"
            fi

            (
                cd "$calc_path"
                echo -e "303" | vaspkit >/dev/null 2>&1
                mv -f KPOINTS KPOINTS_old 2>/dev/null || true
                mv -f KPATH.in KPOINTS

                echo -e "211" | vaspkit >/dev/null 2>&1
                gap_file="$out_dir_abs/BAND_GAPS/BAND_GAP_${tag}"
                [[ -f BAND_GAP ]] && cp BAND_GAP "$gap_file"

                if [[ -f BAND_GAP ]]; then
                    gap_val=$(awk '/Band Gap \(eV\):/ {print $6}' BAND_GAP)
                    fermi_val=$(awk '/Fermi Energy \(eV\):/ {print $6}' BAND_GAP)
                    echo -e "${tag}\t${a_len}\t${b_len}\t${c_len}\t${gap_val:-NA}\t${fermi_val:-NA}" >> "$out_dir_abs/band_gaps.dat"
                fi
                mv -f KPOINTS KPATH.in
                mv -f KPOINTS_old KPOINTS
            )
        done

        summary="$out_dir_abs/convergence_summary.txt"
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

        echo -e "${GREEN}✓ Finished ${FUNC}/${CALC}${RESET}"
        echo -e "   → Energy         : ${CYAN}$out_dir_abs/energies.dat${RESET}"
        echo -e "   → Band gaps      : ${CYAN}$out_dir_abs/band_gaps.dat${RESET}"
        echo -e "   → Magnetization  : ${CYAN}$out_dir_abs/magnetization.dat${RESET}"
        echo -e "   → Summary        : ${CYAN}$summary${RESET}"

        tar -zcf "${out_dir_abs}.tar.gz" -C "$(dirname "$out_dir_abs")" "$(basename "$out_dir_abs")"
        echo -e "   📆 Archived      : ${CYAN}${out_dir_abs}.tar.gz${RESET}"
        echo -e "   📂 Kept directory: ${CYAN}${out_dir_abs}/${RESET}\n"
    done
done

