#!/usr/bin/env bash
# Interactive Hybrid Functional Benchmarking Script for VASP
# Requires: POSCAR, POTCAR, KPOINTS, INCAR.base in working dir

set -euo pipefail

echo "🔧 Enter comma-separated NCORE values (e.g., 2,4,8):"
read -r ncore_input
IFS=',' read -r -a NCORE_LIST <<< "$ncore_input"

echo "🔧 Enter comma-separated NSIM values (e.g., 2,4):"
read -r nsim_input
IFS=',' read -r -a NSIM_LIST <<< "$nsim_input"

read -rp "💻 Total number of cores to use per job (e.g., 128): " CORES
read -rp "💼 Calculation name prefix (e.g., HSE_benchmark): " CALC_NAME

# Queue selection
echo "🧵 Choose queue type:"
echo "   1) vm-small"
echo "   2) normal"
echo "   3) other"
read -rp "Enter number (1/2/3): " queue_choice

case "$queue_choice" in
    1) QUEUE="vm-small" ;;
    2) QUEUE="normal" ;;
    3) read -rp "Enter queue name: " QUEUE ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

read -rp "⏱️  Enter wall time (e.g., 04:00:00): " WALL_TIME

# Ask if WAVECAR and CHGCAR should be copied
read -rp "📂 Copy WAVECAR and CHGCAR files to each benchmark directory? (y/n): " copy_wavecar_chgcar
copy_wavecar_chgcar=${copy_wavecar_chgcar,,}  # to lowercase

echo
echo "🔍 Summary:"
echo "  NCORE values: ${NCORE_LIST[*]}"
echo "  NSIM values: ${NSIM_LIST[*]}"
echo "  Cores per job: $CORES"
echo "  Job name prefix: $CALC_NAME"
echo "  Queue: $QUEUE"
echo "  Time: $WALL_TIME"
echo "  Copy WAVECAR and CHGCAR: $copy_wavecar_chgcar"
echo

mkdir -p benchmark_results
echo "job_id, directory, NCORE, NSIM" > benchmark_results/jobs.submitted
echo "NCORE,NSIM,Time(s),Status" > benchmark_results/summary.txt

for ncore in "${NCORE_LIST[@]}"; do
  for nsim in "${NSIM_LIST[@]}"; do
    test_dir="bench_ncore${ncore}_nsim${nsim}"
    mkdir -p "$test_dir"

    echo "📦 Preparing: $test_dir"
    cp POSCAR POTCAR KPOINTS "$test_dir/"
    cp INCAR.base "$test_dir/INCAR"

    if [[ "$copy_wavecar_chgcar" == "y" ]]; then
      cp WAVECAR CHGCAR "$test_dir/" 2>/dev/null || echo "⚠️ WAVECAR or CHGCAR not found, skipping copy."
    fi

    # Append benchmark params to INCAR
    cat >> "$test_dir/INCAR" <<EOF

# Benchmark parameters
NCORE = $ncore
NSIM  = $nsim
EOF

    # Create jobscript using external script
    bash ~/scripts/make_job.sh "$test_dir" "${CALC_NAME}_${ncore}_${nsim}" 1 "$CORES" "$QUEUE" "$WALL_TIME"

    # Submit job from inside subdir, log job ID
    job_id=$(cd "$test_dir" && sbatch jobscript | awk '{print $NF}')
    echo "$job_id, $test_dir, $ncore, $nsim" >> benchmark_results/jobs.submitted
  done
done

echo
echo "✅ All benchmark jobs submitted. Monitor with: squeue -u \$USER"

