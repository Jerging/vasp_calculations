#!/bin/bash

# batch_coplanar_magnetic_atoms.sh
# Wrapper script to run coplanar_magnetic_atoms.py in all subdirectories
# 
# Usage: ./batch_coplanar_magnetic_atoms.sh [POSCAR_FILE] [ORTHOGONAL_VECTOR] [ATOMS] [TOLERANCE] [LAYERS] [MAGNITUDE]
#
# This script will:
# 1. Find all subdirectories in the current directory
# 2. Enter each subdirectory
# 3. Run coplanar_magnetic_atoms.py with the provided arguments
# 4. Execute any additional commands (add them in the marked section)
# 5. Return to the parent directory
#
# The script assumes coplanar_magnetic_atoms.py is in your PATH or in the same directory as this script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if coplanar_magnetic_atoms.py is available
check_script_availability() {
    SCRIPT_CMD="python3 ~/scripts/magnetism/coplanar_magnetic_atoms.py"
    print_status "Using coplanar_magnetic_atoms.py at /scripts/magnetism/coplanar_magnetic_atoms.py"
}

# Function to display help
show_help() {
    echo "Usage: $0 [POSCAR_FILE] [ORTHOGONAL_VECTOR] [ATOMS] [TOLERANCE] [LAYERS] [MAGNITUDE]"
    echo ""
    echo "This script runs coplanar_magnetic_atoms.py in all subdirectories of the current directory."
    echo ""
    echo "Arguments (same as coplanar_magnetic_atoms.py):"
    echo "  POSCAR_FILE      Path to POSCAR/CONTCAR file (default: POSCAR)"
    echo "  ORTHOGONAL_VECTOR Vector in format [X,Y,Z] (e.g., [1,0,0])"
    echo "  ATOMS           Atom selection - elements, indices, or 'all'"
    echo "  TOLERANCE       Coplanarity tolerance in Å (default: 0.02)"
    echo "  LAYERS          Layers per ferromagnetic block (default: 1)"
    echo "  MAGNITUDE       Magnetic moment magnitude (default: 1.0)"
    echo ""
    echo "Examples:"
    echo "  $0 POSCAR [1,0,0] \"Fe Ni\" 0.02 1 1.0"
    echo "  $0 CONTCAR [0,0,1] all"
    echo "  $0 POSCAR [1,1,0] \"1 2 3 4\""
    echo ""
    echo "Note: Arguments are passed directly to coplanar_magnetic_atoms.py in each subdirectory."
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Store the original directory
ORIGINAL_DIR=$(pwd)

# Check if coplanar_magnetic_atoms.py is available
check_script_availability

# Get all subdirectories
SUBDIRS=($(find . -maxdepth 1 -type d ! -path . | sort))

if [[ ${#SUBDIRS[@]} -eq 0 ]]; then
    print_warning "No subdirectories found in current directory"
    exit 0
fi

print_status "Found ${#SUBDIRS[@]} subdirectories to process"
print_status "Script command: $SCRIPT_CMD"

# Store command line arguments
ARGS=("$@")

# Initialize counters
TOTAL_DIRS=${#SUBDIRS[@]}
SUCCESS_COUNT=0
ERROR_COUNT=0
SKIP_COUNT=0

# Process each subdirectory
for subdir in "${SUBDIRS[@]}"; do
    subdir_name=$(basename "$subdir")
    
    echo ""
    echo "==============================================="
    print_status "Processing directory: $subdir_name"
    echo "==============================================="
    
    # Change to subdirectory
    cd "$subdir" || {
        print_error "Failed to enter directory: $subdir"
        ((ERROR_COUNT++))
        continue
    }
    
    # Check if POSCAR file exists (if specified or default)
    if [[ ${#ARGS[@]} -gt 0 ]]; then
        POSCAR_FILE="${ARGS[0]}"
    else
        POSCAR_FILE="POSCAR"
    fi
    
    if [[ ! -f "$POSCAR_FILE" ]]; then
        print_warning "POSCAR file '$POSCAR_FILE' not found in $subdir_name - skipping"
        ((SKIP_COUNT++))
        cd "$ORIGINAL_DIR"
        continue
    fi
    
    # Run coplanar_magnetic_atoms.py with provided arguments
    print_status "Running coplanar_magnetic_atoms.py with arguments: ${ARGS[*]}"
    
    if eval "$SCRIPT_CMD" "${ARGS[@]}"; then
        print_success "coplanar_magnetic_atoms.py completed successfully in $subdir_name"
        
        # ========================================================================
        # ADD ADDITIONAL COMMANDS HERE
        # ========================================================================
        # This section is reserved for additional commands you want to run
        # in each subdirectory after coplanar_magnetic_atoms.py completes
        # 
        # Examples:
        # - Copy results to a central location
        # - Run additional analysis scripts
        # - Clean up temporary files
        # - Generate plots or reports
        
        # Example commands (uncomment and modify as needed):
        # print_status "Running additional commands in $subdir_name"
        
        # # Copy MAGMOM to a results directory
        # if [[ -f "MAGMOM" ]]; then
        #     mkdir -p "$ORIGINAL_DIR/results"
        #     cp MAGMOM "$ORIGINAL_DIR/results/MAGMOM_$subdir_name"
        # fi
        
        # # Run additional analysis
        # if [[ -f "analyze_results.py" ]]; then
        #     python analyze_results.py
        # fi
        
        # # Clean up temporary files
        # rm -f *.tmp
        
        # ========================================================================
        # END OF ADDITIONAL COMMANDS SECTION
        # ========================================================================
        cp $ORIGINAL_DIR/INCAR .
        bash ~/scripts/magnetism/write_magmom_to_incar.sh
        ((SUCCESS_COUNT++))
    else
        print_error "coplanar_magnetic_atoms.py failed in $subdir_name"
        ((ERROR_COUNT++))
    fi
    
    # Return to original directory
    cd "$ORIGINAL_DIR"
done

# Print summary
echo ""
echo "==============================================="
print_status "BATCH PROCESSING SUMMARY"
echo "==============================================="
print_status "Total directories processed: $TOTAL_DIRS"
print_success "Successful runs: $SUCCESS_COUNT"
print_warning "Skipped (no POSCAR): $SKIP_COUNT"
print_error "Failed runs: $ERROR_COUNT"

if [[ $ERROR_COUNT -gt 0 ]]; then
    echo ""
    print_error "Some directories failed processing. Check the output above for details."
    exit 1
else
    echo ""
    print_success "All applicable directories processed successfully!"
fi
