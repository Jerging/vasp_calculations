#!/usr/bin/env bash
#
# collect_energy.sh — Extract VASP energy and lattice constants
# from POSCAR_scaled_*/<functional>/<calc_type>/ directories

set -eu
shopt -s nullglob

read -rp "Enter the calculation type (e.g., scf, relax, nscf): " CALC_TYPE
[[ -z "$CALC_TYPE" ]] && echo "Error: calculation type required." && exit 1

# Detect available functionals
declare -A functionals_map
for poscar_dir in POSCAR_scaled_*; do
    for func_dir in "$poscar_dir"/*/; do
        [[ -d "$func_dir" ]] || continue
        func_name=$(basename "$func_dir")
        functionals_map["$func_name"]=1
    done
done
AVAILABLE_FUNCTIONALS=("${!functionals_map[@]}")

echo "Detected functionals: ${AVAILABLE_FUNCTIONALS[*]}"
read -rp "Do you want to collect energies for all of them? (y/n): " choice

if [[ "$choice" =~ ^[Yy]$ ]]; then
    SELECTED_FUNCTIONALS=("${AVAILABLE_FUNCTIONALS[@]}")

else
    echo "Enter desired functionals from the list above (comma-separated): "
    read -r user_input
    IFS=',' read -ra SELECTED_FUNCTIONALS <<< "$user_input"
fi

echo "Collecting energies for: ${SELECTED_FUNCTIONALS[*]}"

# Prepare energy output files
for functional in "${SELECTED_FUNCTIONALS[@]}"; do
	output_dir="${functional}_${CALC_TYPE}_energies"
	mkdir -p "$output_dir"

    echo -e "Directory\tA(Å)\tB(Å)\tC(Å)\tEnergy(eV)" > "${output_dir}/${functional}_energies.dat"

	# Function to compute lattice vector magnitudes
	get_lengths() {
    	local file="$1"
    	read -r ax ay az < <(awk 'NR==3{print $1,$2,$3}' "$file")
    	read -r bx by bz < <(awk 'NR==4{print $1,$2,$3}' "$file")
    	read -r cx cy cz < <(awk 'NR==5{print $1,$2,$3}' "$file")
    	a_len=$(awk -v x="$ax" -v y="$ay" -v z="$az" 'BEGIN{printf "%.4f", sqrt(x*x+y*y+z*z)}')
    	b_len=$(awk -v x="$bx" -v y="$by" -v z="$bz" 'BEGIN{printf "%.4f", sqrt(x*x+y*y+z*z)}')
    	c_len=$(awk -v x="$cx" -v y="$cy" -v z="$cz" 'BEGIN{printf "%.4f", sqrt(x*x+y*y+z*z)}')
	}

	# Tracking associative arrays for counts and unconverged dirs
	declare -A total_ct
	declare -A converged_ct
	declare -A unconverged_dirs

	# Loop through structures
	for poscar_dir in POSCAR_scaled_*; do
    		dir_name=$(basename "$poscar_dir")

        	calc_dir="$poscar_dir/$functional/$CALC_TYPE"
        	outcar="$calc_dir/OUTCAR"
       		poscar="$calc_dir/POSCAR"
        	contcar="$calc_dir/CONTCAR"
        	output_file="${output_dir}/${functional}_energies.dat"

        	[[ -f "$outcar" ]] || { echo "Missing OUTCAR in $calc_dir"; continue; }

        	# Increment total count for this functional
        	total_ct["$functional"]=$(( ${total_ct["$functional"]:-0} + 1 ))

        	# Check for convergence in OUTCAR
        	if ! grep -q "reached required accuracy" "$outcar"; then
            		unconverged_dirs["$functional"]+=$'\n'"$calc_dir"
            	continue
        	fi

        	# Use CONTCAR if relax, else POSCAR
        	if [[ "$CALC_TYPE" == "relax" ]]; then
            		structure_file="$contcar"
        	else
            		structure_file="$poscar"
        	fi

        	[[ -f "$structure_file" ]] || { echo "Missing structure file ($structure_file) in $calc_dir"; continue; }

        	# Extract last free energy (TOTEN) from OUTCAR
        	energy=$(grep "free  energy" "$outcar" | tail -1 | awk '{print $5}')
        	[[ -z "$energy" ]] && { echo "No energy found in $outcar"; continue; }

        	get_lengths "$structure_file"
        	echo -e "${dir_name}\t${a_len}\t${b_len}\t${c_len}\t${energy}" >> "$output_file"

        	# Increment converged count
        	converged_ct["$functional"]=$(( ${converged_ct["$functional"]:-0} + 1 ))
    		done
		done

		# Write convergence summary
		summary_file="${output_dir}/convergence_summary.txt"
		{
    		echo "Convergence Summary for CALC_TYPE = $CALC_TYPE"
    		echo "Generated on $(date)"
    		echo
    		printf "%-15s %10s %12s %12s\n" "Functional" "Total" "Converged" "Failed"
    		printf "%-15s %10s %12s %12s\n" "-----------" "-----" "---------" "------"
        	total=${total_ct["$functional"]:-0}
        	ok=${converged_ct["$functional"]:-0}
        	fail=$(( total - ok ))
        	printf "%-15s %10d %12d %12d\n" "$functional" "$total" "$ok" "$fail"

    		echo -e "\n--- Unconverged Directories ---"
    		for unconverged in "${!unconverged_dirs[@]}"; do
        		echo -e "\n[$unconverged]${unconverged_dirs[$unconverged]}"
		done
		} | tee "$summary_file"

echo
echo "✅ All done. Results in: $output_dir/"
echo "📄 Convergence summary: $summary_file"

