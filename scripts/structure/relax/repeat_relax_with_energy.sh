#!/bin/bash
# VASP relaxation script with proper convergence breaking
MAX_ITER=50
ITER=0
LOG_FILE="relaxation.log"
OUTPUT_DIR="relaxation_outputs"
result="false"  # Initialize result variable

# Energy convergence parameters
ENERGY_TOLERANCE=1e-8  # Energy difference threshold (eV)
MIN_SAME_ENERGY_COUNT=5  # Minimum consecutive identical energies to trigger convergence

# Check for previous run and restore if found
if [[ -f "$LOG_FILE" && -d "$OUTPUT_DIR" ]]; then
    # Find the last completed iteration
    last_iter=$(ls -1 "$OUTPUT_DIR" 2>/dev/null | grep "^iter_" | sed 's/iter_//' | sort -n | tail -1)
    if [[ -n "$last_iter" && "$last_iter" -gt 0 ]]; then
        # Check if already converged (FIXED: column 4, not 3)
        last_status=$(grep "^$last_iter " "$LOG_FILE" | tail -1 | awk '{print $4}')
        if [[ "$last_status" == "CONVERGED" || "$last_status" == "ENERGY_CONVERGED" ]]; then
            echo "Previous run already converged at iteration $last_iter"
            exit 0
        fi
        # Restore from last iteration
        last_iter_dir="$OUTPUT_DIR/iter_$last_iter"
        if [[ -f "$last_iter_dir/CONTCAR" ]]; then
            cp "$last_iter_dir/CONTCAR" POSCAR
            ITER=$last_iter
        fi
    fi
fi

# Initialize logging and directories (only if new run)
mkdir -p "$OUTPUT_DIR"
if [[ $ITER -eq 0 ]]; then
    {
        echo "VASP Relaxation Log - $(date)"
        echo "----------------------------------------"
        printf "%-6s %-15s %-15s %s\n" "Iter" "Energy(eV)" "Time(sec)" "Status"
        echo "----------------------------------------"
    } > "$LOG_FILE"
fi

# Function to check energy convergence
check_energy_convergence() {
    local current_iter=$1
    local current_energy=$2
    
    # Need at least MIN_SAME_ENERGY_COUNT iterations to check
    if [[ $current_iter -lt $MIN_SAME_ENERGY_COUNT ]]; then
        return 1
    fi
    
    # Get the last few energies from the log
    local energies=($(tail -n $MIN_SAME_ENERGY_COUNT "$LOG_FILE" | awk '{print $2}' | grep -v "Energy(eV)" | grep -v "^$"))
    
    # Check if we have enough energies
    if [[ ${#energies[@]} -lt $MIN_SAME_ENERGY_COUNT ]]; then
        return 1
    fi
    
    # Check if all recent energies are identical (within tolerance)
    local first_energy=${energies[0]}
    for energy in "${energies[@]}"; do
        if [[ "$energy" != "N/A" && "$first_energy" != "N/A" ]]; then
            local diff=$(echo "$energy - $first_energy" | bc -l | sed 's/^-//')
            if (( $(echo "$diff > $ENERGY_TOLERANCE" | bc -l) )); then
                return 1
            fi
        else
            return 1
        fi
    done
    
    return 0
}

# Main relaxation loop
while (( ITER < MAX_ITER )); do
    ((ITER++))
    
    # Run VASP
    ibrun vasp_std > relax.out 2>&1
    if [[ $? -ne 0 ]]; then
        echo "$ITER VASP failed" >> "$LOG_FILE"
        break
    fi
    
    # Check for CONTCAR
    if [[ ! -f CONTCAR ]]; then
        echo "$ITER CONTCAR missing" >> "$LOG_FILE"
        break
    fi
    
    # Create iteration directory
    iter_dir="$OUTPUT_DIR/iter_$ITER"
    mkdir -p "$iter_dir"
    cp {POSCAR,CONTCAR,OUTCAR,OSZICAR} "$iter_dir/"
    
    # Extract energy
    energy=$(grep "free  energy   TOTEN" OUTCAR | tail -1 | awk '{print $5}')
    energy=${energy:-N/A}
    
    # Extract elapsed time
    elapsed_time=$(grep "Elapsed time (sec):" OUTCAR | tail -1 | awk '{print $4}')
    elapsed_time=${elapsed_time:-N/A}
    
    # Compare structures (FIXED: clean whitespace)
    result=$(bash ~/scripts/structure/relax/compare_poscar_contcar.sh | tr -d '[:space:]')
    if [[ "$result" != "true" && "$result" != "false" ]]; then
        echo "$ITER Comparison failed" >> "$LOG_FILE"
        result="false"  # Set result for final status
        break
    fi
    
    # Determine status
    status="CONTINUE"
    if [[ "$result" == "true" ]]; then
        status="CONVERGED"
    else
        # Check for energy convergence
        printf "%-6d %-15s %-15s %s\n" "$ITER" "$energy" "$elapsed_time" "$status" >> "$LOG_FILE"
        if check_energy_convergence "$ITER" "$energy"; then
            status="ENERGY_CONVERGED"
            result="true"  # Set result to break the loop
        fi
    fi
    
    # Log final status (update if energy converged)
    if [[ "$status" == "ENERGY_CONVERGED" ]]; then
        # Update the last line in the log file
        sed -i "$ s/CONTINUE/ENERGY_CONVERGED/" "$LOG_FILE"
    elif [[ "$status" != "CONTINUE" ]]; then
        printf "%-6d %-15s %-15s %s\n" "$ITER" "$energy" "$elapsed_time" "$status" >> "$LOG_FILE"
    fi
    
    # Break if converged
    if [[ "$result" == "true" ]]; then
        break
    fi
    
    # Update POSCAR for next iteration
    cp CONTCAR POSCAR
done

# Final status
{
    echo "----------------------------------------"
    if [[ "$result" == "true" ]]; then
        if [[ "$status" == "ENERGY_CONVERGED" ]]; then
            echo "Energy converged after $ITER iterations (same energy for $MIN_SAME_ENERGY_COUNT+ steps)"
        else
            echo "Structure converged after $ITER iterations"
        fi
    else
        echo "Stopped after $ITER iterations"
    fi
    echo "Final energy: $energy eV"
} | tee -a "$LOG_FILE"
