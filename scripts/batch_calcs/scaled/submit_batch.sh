#!/usr/bin/env bash

MAX_JOBS=20
root_dir=$(pwd)

# Find all directories matching ./POSCAR_scaled_*/<FUNC>/<CALC> that contain a jobscript
mapfile -t job_paths < <(find ./POSCAR_scaled_* -mindepth 3 -type f -name "jobscript" -exec dirname {} \; | sort -u)

if [ ${#job_paths[@]} -eq 0 ]; then
    echo "❌ No calculation directories with jobscript found."
    exit 1
fi

# Extract unique functionals and calculation types
mapfile -t FUNCTIONALS < <(printf "%s\n" "${job_paths[@]}" | awk -F/ '{print $(NF-1)}' | sort -u)
mapfile -t CALCS       < <(printf "%s\n" "${job_paths[@]}" | awk -F/ '{print $(NF)}'   | sort -u)

# Prompt for functional
echo "Available functionals:"
select FUNC in "${FUNCTIONALS[@]}" "ALL"; do
    if [ "$FUNC" == "ALL" ]; then
        SELECTED_FUNCTIONALS=("${FUNCTIONALS[@]}")
        break
    elif [[ " ${FUNCTIONALS[*]} " == *" $FUNC "* ]]; then
        SELECTED_FUNCTIONALS=("$FUNC")
        break
    else
        echo "Invalid selection. Try again."
    fi
done

# Prompt for calculation type
echo "Available calculation types:"
select CALC in "${CALCS[@]}" "ALL"; do
    if [ "$CALC" == "ALL" ]; then
        SELECTED_CALCS=("${CALCS[@]}")
        break
    elif [[ " ${CALCS[*]} " == *" $CALC "* ]]; then
        SELECTED_CALCS=("$CALC")
        break
    else
        echo "Invalid selection. Try again."
    fi
done

# Filter out COMPLETED directories
pending_dirs=()
for dir in "${job_paths[@]}"; do
    func=$(basename "$(dirname "$dir")")
    calc=$(basename "$dir")
    if [[ " ${SELECTED_FUNCTIONALS[*]} " == *" $func "* && " ${SELECTED_CALCS[*]} " == *" $calc "* ]]; then
        if [ ! -f "$dir/COMPLETED" ]; then
            pending_dirs+=("$dir")
        else
            echo "✔️  Skipping $dir (COMPLETED file found)"
        fi
    fi
done

if [ ${#pending_dirs[@]} -eq 0 ]; then
    echo "✅ No pending jobs to submit."
    exit 0
fi

submit_jobs() {
    local batch=("$@")
    for dir in "${batch[@]}"; do
        (
            cd "$dir" || exit 1
            if [ -f "jobscript" ]; then
                jobid=$(sbatch jobscript | awk '{print $NF}')
                echo "$jobid" > .jobid
                echo "📤 Submitted job $jobid in $dir"
            else
                echo "⚠️  No jobscript found in $dir"
            fi
        )
    done
}

wait_for_jobs() {
    local jobids=("$@")
    while true; do
        sleep 30
        still_running=0
        for id in "${jobids[@]}"; do
            if squeue -h -j "$id" &> /dev/null; then
                still_running=1
                break
            fi
        done
        if [ "$still_running" -eq 0 ]; then
            break
        fi
    done
}

# Submit jobs in batches
i=0
total=${#pending_dirs[@]}
while [ $i -lt $total ]; do
    batch=("${pending_dirs[@]:$i:$MAX_JOBS}")
    submit_jobs "${batch[@]}"

    jobids=()
    for dir in "${batch[@]}"; do
        if [ -f "$dir/.jobid" ]; then
            jobids+=("$(<"$dir/.jobid")")
        fi
    done

    echo "⏳ Waiting for ${#jobids[@]} job(s) to finish..."
    wait_for_jobs "${jobids[@]}"

    i=$((i + MAX_JOBS))
done

echo "✅ All pending jobs submitted and monitored."

