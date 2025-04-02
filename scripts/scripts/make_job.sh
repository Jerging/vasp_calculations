#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 6 ]; then
  echo "Usage: $0 <CALC> <SYSTEM> <NODE> <CORE> <QUEUE> <TIME>"
  exit 1
fi

# Assign input arguments to variables
CALC=$1
SYSTEM=$2
NODE=$3
CORE=$4
QUEUE=$5
TIME=$6

# Define the template content
template="#!/bin/bash 
#SBATCH -J CALC_SYSTEM    
#SBATCH -o vasp.%j.out     
#SBATCH -e vasp.%j.err 
#SBATCH -N NODE         
#SBATCH -n CORE
#SBATCH -p QUEUE      
#SBATCH -t TIME        
#SBATCH -A PHY24018

module load vasp/6.3.0
ibrun vasp_std > CALC.out
touch COMPLETED"

# Replace placeholders with user input
generated_script=$(echo "$template" | sed \
  -e "s/CALC/$CALC/" \
  -e "s/SYSTEM/$SYSTEM/" \
  -e "s/NODE/$NODE/" \
  -e "s/CORE/$CORE/" \
  -e "s/QUEUE/$QUEUE/" \
  -e "s/TIME/$TIME/")

# Save the generated script to a file
echo "$generated_script" > jobscript

# Notify the user
echo "Job script with chosen parameters created!"
