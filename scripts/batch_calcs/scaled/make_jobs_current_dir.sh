#!/usr/bin/env bash

# Prompt for SYSTEM, NODE, CORE, QUEUE, TIME
read -p "Enter system name (e.g., SrTiO3): " SYSTEM
read -p "Enter node count: " NODE
read -p "Enter cores per node: " CORE
read -p "Enter queue name: " QUEUE
read -p "Enter job time (HH:MM:SS): " TIME

# Detect functionals
echo "Scanning functionals in POSCAR_scaled_*..."
mapfile -t FUNCTIONALS < <(find POSCAR_scaled_* -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort -u)

if [ ${#FUNCTIONALS[@]} -eq 0 ]; then
    echo "❌ No functionals found."
    exit 1
fi

echo "Available functionals:"
select FUNC in "${FUNCTIONALS[@]}"; do
    if [ -n "$FUNC" ]; then
        break
    else
        echo "Invalid choice. Try again."
    fi
done

# Detect calculations
echo "Scanning calculations under $FUNC..."
mapfile -t CALCS < <(find POSCAR_scaled_*/"$FUNC"/* -mindepth 0 -maxdepth 0 -type d -exec basename {} \; | sort -u)

if [ ${#CALCS[@]} -eq 0 ]; then
    echo "❌ No calculation directories found under $FUNC."
    exit 1
fi

echo "Available calculations:"
select CALC in "${CALCS[@]}"; do
    if [ -n "$CALC" ]; then
        break
    else
        echo "Invalid choice. Try again."
    fi
done

# Submit jobs
echo "Submitting jobs for functional [$FUNC], calculation [$CALC]..."

find . -type d -path "./POSCAR_scaled_*/$FUNC/$CALC" | while read -r job_dir; do
    if [ -d "$job_dir" ]; then
        (
            cd "$job_dir" || { echo "[Error] Cannot enter $job_dir"; exit 1; }
            echo "[Info] Creating job in $job_dir"
            bash ~/scripts/make_job.sh "$CALC" "$SYSTEM" "$NODE" "$CORE" "$QUEUE" "$TIME" || {
                echo "[Error] Job creation failed in $job_dir"
            }
        )
    fi
done

echo "✅ Job creation complete."

