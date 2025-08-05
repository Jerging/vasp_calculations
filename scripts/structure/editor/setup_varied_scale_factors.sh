#!/usr/bin/env bash

# Default: single point at 1.0
x_vals=("1.0")
y_vals=("1.0")
z_vals=("1.0")

print_help() {
  echo "Usage: $0 [-x start:stop:step] [-y start:stop:step] [-z start:stop:step]"
  echo "All values may be floats. Defaults to 1.0 if not specified."
  exit 1
}

generate_range() {
  local start="$1"
  local stop="$2"
  local step="$3"
  awk -v start="$start" -v stop="$stop" -v step="$step" 'BEGIN {
    for (x = start; x <= stop + (step/2); x += step) {
      printf "%.10g\n", x
    }
  }'
}

# Parse options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -x)
      IFS=':' read -r x_start x_stop x_step <<< "$2"
      mapfile -t x_vals < <(generate_range "$x_start" "$x_stop" "$x_step")
      shift 2
      ;;
    -y)
      IFS=':' read -r y_start y_stop y_step <<< "$2"
      mapfile -t y_vals < <(generate_range "$y_start" "$y_stop" "$y_step")
      shift 2
      ;;
    -z)
      IFS=':' read -r z_start z_stop z_step <<< "$2"
      mapfile -t z_vals < <(generate_range "$z_start" "$z_stop" "$z_step")
      shift 2
      ;;
    -h|--help)
      print_help
      ;;
    *)
      echo "Unknown option: $1"
      print_help
      ;;
  esac
done

parent_dir=$(pwd)

# Main loop
for x in "${x_vals[@]}"; do
  for y in "${y_vals[@]}"; do
    for z in "${z_vals[@]}"; do
      echo "Running for x=$x, y=$y, z=$z"

      new_dir="${parent_dir}/scale_${x}/POSCAR_z_${z}"
      mkdir -p "$new_dir"
      cd "$new_dir" || exit 1

      cp "$parent_dir/POSCAR" ./POSCAR
      cp "$parent_dir/POTCAR" ./POTCAR
      python ~/scripts/structure/editor/change_scaling_factors.py "$x" "$x" "$z"
      echo -e "102\n2\n0.03" | vaspkit > /dev/null 2>&1
      cp "$parent_dir/INCAR" ./INCAR
      cd "$parent_dir" || exit 1

    done
  done
done

