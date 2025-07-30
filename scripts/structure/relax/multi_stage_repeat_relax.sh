#!/bin/bash
# VASP relaxation script with multi-stage ISIF/IBRION parameters
# Usage: bash repeat_relax.sh (ISIF1,IBRION1) (ISIF2,IBRION2) ... (ISIF_final,IBRION_final)
# Example: bash repeat_relax.sh (3,2) (1,3)

MAX_ITER=50
ITER=0
LOG_FILE="relaxation.log"
OUTPUT_DIR="relaxation_outputs"
STAGE=1

# Parse command line arguments for (ISIF,IBRION) pairs
STAGES=()
for arg in "$@"; do
    # Accept both (ISIF,IBRION) and ISIF:IBRION formats
    if [[ $arg =~ ^\(([0-9]+),([0-9]+)\)$ ]]; then
        isif="${BASH_REMATCH[1]}"
        ibrion="${BASH_REMATCH[2]}"
        STAGES+=("$isif,$ibrion")
    elif [[ $arg =~ ^([0-9]+):([0-9]+)$ ]]; then
        isif="${BASH_REMATCH[1]}"
        ibrion="${BASH_REMATCH[2]}"
        STAGES+=("$isif,$ibrion")
    else
        echo "Error: Invalid argument format '$arg'. Use (ISIF,IBRION) or ISIF:IBRION format."
        echo "Example: bash $0 \"(3,2)\" \"(1,3)\" or bash $0 3:2 1:3"
        exit 1
    fi
done

# Check if at least one stage is provided
if [[ ${#STAGES[@]} -eq 0 ]]; then
    echo "Error: No valid (ISIF,IBRION) pairs provided."
    echo "Usage: bash $0 \"(ISIF1,IBRION1)\" \"(ISIF2,IBRION2)\" ..."
    echo "Alternative: bash $0 ISIF1:IBRION1 ISIF2:IBRION2 ..."
    echo "Example: bash $0 \"(3,2)\" \"(1,3)\" or bash $0 3:2 1:3"
    exit 1
fi

# Backup original INCAR
cp INCAR INCAR.original

# Function to update INCAR with new ISIF and IBRION values
update_incar() {
    local isif=$1
    local ibrion=$2
    
    # Create temporary INCAR
    cp INCAR.original INCAR.tmp
    
    # Update or add ISIF
    if grep -q "^[[:space:]]*ISIF" INCAR.tmp; then
        sed -i "s/^[[:space:]]*ISIF[[:space:]]*=.*/ISIF   = $isif/" INCAR.tmp
    else
        echo "ISIF   = $isif" >> INCAR.tmp
    fi
    
    # Update or add IBRION
    if grep -q "^[[:space:]]*IBRION" INCAR.tmp; then
        sed -i "s/^[[:space:]]*IBRION[[:space:]]*=.*/IBRION = $ibrion/" INCAR.tmp
    else
        echo "IBRION = $ibrion" >> INCAR.tmp
    fi
    
    # Replace INCAR with updated version
    mv INCAR.tmp INCAR
}

# Initialize logging and directories
mkdir -p "$OUTPUT_DIR"
{
    echo "VASP Multi-Stage Relaxation Log - $(date)"
    echo "Stages: ${STAGES[*]}"
    echo "Final stage will be repeated until convergence"
    echo "========================================"
    printf "%-6s %-8s %-15s %-10s %s\n" "Iter" "Stage" "Energy(eV)" "ISIF/IBRION" "Status"
    echo "========================================"
} > "$LOG_FILE"

# Process all stages
for stage_idx in "${!STAGES[@]}"; do
    IFS=',' read -r current_isif current_ibrion <<< "${STAGES[$stage_idx]}"
    
    # Update INCAR for current stage
    update_incar "$current_isif" "$current_ibrion"
    
    echo "Stage $((stage_idx + 1)): ISIF=$current_isif, IBRION=$current_ibrion" | tee -a "$LOG_FILE"
    
    # Determine if this is the final stage (will be repeated)
    is_final_stage=$((stage_idx == ${#STAGES[@]} - 1))
    
    if [[ $is_final_stage -eq 1 ]]; then
        # Final stage: repeat until convergence
        stage_converged=false
        stage_iter=0
        
        while (( ITER < MAX_ITER && stage_converged == false )); do
            ((ITER++))
            ((stage_iter++))
            
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
            cp {POSCAR,CONTCAR,OUTCAR,OSZICAR,INCAR} "$iter_dir/"
            
            # Extract energy
            energy=$(grep "free  energy   TOTEN" OUTCAR | tail -1 | awk '{print $5}')
            energy=${energy:-N/A}
            
            # Compare structures for convergence
            result=$(bash ~/scripts/structure/relax/compare_poscar_contcar.sh)
            if [[ "$result" != "true" && "$result" != "false" ]]; then
                echo "$ITER Comparison failed" >> "$LOG_FILE"
                break
            fi
            
            # Log status
            status=$([[ "$result" == "true" ]] && echo "CONVERGED" || echo "CONTINUE")
            printf "%-6d %-8s %-15s %-10s %s\n" "$ITER" "$((stage_idx + 1))" "$energy" "$current_isif/$current_ibrion" "$status" >> "$LOG_FILE"
            
            # Check convergence for final stage
            if [[ "$result" == "true" ]]; then
                stage_converged=true
                break
            fi
            
            # Update POSCAR for next iteration
            cp CONTCAR POSCAR
        done
        
    else
        # Non-final stage: run once
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
        cp {POSCAR,CONTCAR,OUTCAR,OSZICAR,INCAR} "$iter_dir/"
        
        # Extract energy
        energy=$(grep "free  energy   TOTEN" OUTCAR | tail -1 | awk '{print $5}')
        energy=${energy:-N/A}
        
        # Log status (no convergence check for non-final stages)
        printf "%-6d %-8s %-15s %-10s %s\n" "$ITER" "$((stage_idx + 1))" "$energy" "$current_isif/$current_ibrion" "STAGE_COMPLETE" >> "$LOG_FILE"
        
        # Update POSCAR for next stage
        cp CONTCAR POSCAR
    fi
done

# Final status
{
    echo "========================================"
    if [[ "$result" == "true" ]]; then
        echo "Converged after $ITER total iterations"
    else
        echo "Stopped after $ITER total iterations"
    fi
    echo "Final energy: $energy eV"
    echo "Final parameters: ISIF=$current_isif, IBRION=$current_ibrion"
} | tee -a "$LOG_FILE"

# Restore original INCAR
mv INCAR.original INCAR

echo "Multi-stage relaxation completed. Check $LOG_FILE for details."
