#!/bin/bash
# VASP relaxation script with proper convergence breaking

MAX_ITER=50
ITER=0
LOG_FILE="relaxation.log"
OUTPUT_DIR="relaxation_outputs"

# Initialize logging and directories
mkdir -p "$OUTPUT_DIR"
{
    echo "VASP Relaxation Log - $(date)"
    echo "----------------------------------------"
    printf "%-6s %-15s %s\n" "Iter" "Energy(eV)" "Status"
    echo "----------------------------------------"
} > "$LOG_FILE"

# Main relaxation loop
while (( ITER < MAX_ITER )); do
    ((ITER++))
    
    # Run VASP
    ibrun vasp_std > vasp.out 2>&1
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

    # Compare structures
    result=$(bash ~/scripts/structure/relax/compare_poscar_contcar.sh)
    if [[ "$result" != "true" && "$result" != "false" ]]; then
        echo "$ITER Comparison failed" >> "$LOG_FILE"
        break
    fi

    # Log status
    status=$([[ "$result" == "true" ]] && echo "CONVERGED" || echo "CONTINUE")
    printf "%-6d %-15s %s\n" "$ITER" "$energy" "$status" >> "$LOG_FILE"

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
        echo "Converged after $ITER iterations"
    else
        echo "Stopped after $ITER iterations"
    fi
    echo "Final energy: $energy eV"
} | tee -a "$LOG_FILE"
