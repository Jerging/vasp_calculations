#!/usr/bin/env bash

# Ask for calculation type
read -p "Enter the calculation type (e.g., scf, relax, nscf): " CALC_TYPE
[[ -z "$CALC_TYPE" ]] && echo "Error: calculation type required." && exit 1

output_dir="${CALC_TYPE}_energies"
mkdir -p "$output_dir"

# Detect functionals from all POSCAR_scaled_* directories
declare -A functionals_map

for poscar_dir in POSCAR_scaled_*; do
    for func_dir in "$poscar_dir"/*/; do
        [[ -d "$func_dir" ]] || continue
        func_name=$(basename "$func_dir")
        functionals_map["$func_name"]=1
    done
done

# Convert associative array to array
AVAILABLE_FUNCTIONALS=("${!functionals_map[@]}")

echo "Detected functionals: ${AVAILABLE_FUNCTIONALS[*]}"
read -p "Do you want to collect energies for all of them? (y/n): " choice

if [[ "$choice" =~ ^[Yy]$ ]]; then
    SELECTED_FUNCTIONALS=("${AVAILABLE_FUNCTIONALS[@]}")
else
    echo "Enter desired functionals from the list above (comma-separated): "
    read -r user_input
    IFS=',' read -ra SELECTED_FUNCTIONALS <<< "$user_input"
fi

# Confirm selection
echo "Collecting energies for: ${SELECTED_FUNCTIONALS[*]}"

# Create functional-specific output files
for functional in "${SELECTED_FUNCTIONALS[@]}"; do
    echo -e "Directory\tA(Å)\tB(Å)\tC(Å)\tEnergy(eV)" > "${output_dir}/${functional}_energies.dat"
    echo -e "Directory\tA(Å)\tB(Å)\tC(Å)" > "${output_dir}/CONTCAR_lattice_vectors_${functional}.dat"
done

# POSCAR vectors are functional-independent
poscar_vecs="${output_dir}/POSCAR_lattice_vectors.dat"
echo -e "Directory\tA(Å)\tB(Å)\tC(Å)" > "$poscar_vecs"

# Function to get lattice vector magnitudes
get_lengths() {
    local file="$1"
    read -r ax ay az < <(awk 'NR==3 {print $1, $2, $3}' "$file")
    read -r bx by bz < <(awk 'NR==4 {print $1, $2, $3}' "$file")
    read -r cx cy cz < <(awk 'NR==5 {print $1, $2, $3}' "$file")
    a_len=$(awk -v x="$ax" -v y="$ay" -v z="$az" 'BEGIN{printf "%.4f", sqrt(x^2 + y^2 + z^2)}')
    b_len=$(awk -v x="$bx" -v y="$by" -v z="$bz" 'BEGIN{printf "%.4f", sqrt(x^2 + y^2 + z^2)}')
    c_len=$(awk -v x="$cx" -v y="$cy" -v z="$cz" 'BEGIN{printf "%.4f", sqrt(x^2 + y^2 + z^2)}')
}

# Process each structure
for poscar_dir in POSCAR_scaled_*; do
    dir_name=$(basename "$poscar_dir")

    for functional in "${SELECTED_FUNCTIONALS[@]}"; do
        calc_dir="$poscar_dir/$functional/$CALC_TYPE"
        outcar="$calc_dir/OUTCAR"
        poscar="$calc_dir/POSCAR"
        contcar="$calc_dir/CONTCAR"
        output_file="${output_dir}/${functional}_energies.dat"
        contcar_vecs="${output_dir}/CONTCAR_lattice_vectors_${functional}.dat"

        [[ ! -f "$outcar" || ! -f "$poscar" ]] && echo "Skipping missing $calc_dir" && continue

        # Extract final energy
        energy=$(grep "free  energy" "$outcar" | tail -1 | awk '{print $5}')
        [[ -z "$energy" ]] && echo "Warning: No energy in $outcar" && continue

        get_lengths "$poscar"
        echo -e "${dir_name}\t$a_len\t$b_len\t$c_len\t$energy" >> "$output_file"
        echo -e "${dir_name}\t$a_len\t$b_len\t$c_len" >> "$poscar_vecs"

        if [[ -f "$contcar" ]]; then
            get_lengths "$contcar"
            echo -e "${dir_name}\t$a_len\t$b_len\t$c_len" >> "$contcar_vecs"
        fi
    done
done

echo "Energy and lattice vector collection complete in '$output_dir'."

