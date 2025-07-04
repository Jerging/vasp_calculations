#!/usr/bin/env bash
# Summarize hybrid VASP benchmark runs: electronic steps + time

set -euo pipefail

RESULTS_DIR="benchmark_results"
OUTPUT_CSV="${RESULTS_DIR}/summary.csv"
FAILED_JOBS="${RESULTS_DIR}/failed_jobs.txt"

mkdir -p "$RESULTS_DIR"
echo "NCORE,NSIM,Steps,Time(s),Steps/sec" > "$OUTPUT_CSV"
echo "Missing or Incomplete Jobs:" > "$FAILED_JOBS"

for dir in bench_ncore*/; do
    incar_file="${dir}/INCAR"
    oszicar_file="${dir}/OSZICAR"
    vaspout_file="${dir}/vasp.out"

    # Check required files
    if [[ ! -f "$incar_file" || ! -f "$oszicar_file" || ! -f "$vaspout_file" ]]; then
        echo "❌ $dir — missing INCAR, OSZICAR, or vasp.out" >> "$FAILED_JOBS"
        continue
    fi

    # Extract NCORE and NSIM
    ncore=$(awk '/^NCORE/ {print $3}' "$incar_file")
    nsim=$(awk '/^NSIM/  {print $3}' "$incar_file")

    # Extract final number of electronic steps
    step_line=$(grep "^DMP:" "$oszicar_file" | tail -1)
    if [[ -z "$step_line" ]]; then
        echo "⚠️  No DMP line in $dir/OSZICAR" >> "$FAILED_JOBS"
        continue
    fi
    steps=$(echo "$step_line" | awk '{print $2}')

    # Extract elapsed time (match "TIME=" line written by jobscript)
    elapsed=$(awk '/TIME=/{print $3}' "$vaspout_file" | tail -1)
    if [[ -z "$elapsed" ]]; then
        echo "⚠️  No elapsed time in $dir/vasp.out" >> "$FAILED_JOBS"
        continue
    fi

    # Compute steps/sec if possible
    if [[ "$elapsed" =~ ^[0-9]+$ && "$steps" =~ ^[0-9]+$ ]]; then
        sps=$(awk -v s="$steps" -v t="$elapsed" 'BEGIN {printf "%.3f", s/t}')
    else
        sps="NA"
    fi

    echo "$ncore,$nsim,$steps,$elapsed,$sps" >> "$OUTPUT_CSV"
done

echo
echo "✅ Summary written to $OUTPUT_CSV"

echo
echo "📊 Sorted by highest steps/sec:"
column -s, -t "$OUTPUT_CSV" | tail -n +2 | sort -t, -k5 -nr | column -s, -t

echo
echo "⚠️  Failed or incomplete jobs logged in: $FAILED_JOBS"

