#!/usr/bin/bash

#POSCAR system to study
SYSTEM=STO
PSEUDO=PBE

#KPOINTS
KPR=0.04
KSCHEME=2

#Relax jobscript parameters
RQUEUE="vm-small"
RNODE="1"
RCORE="1"
RTIME="00:01:00"

#Makes system directory and populates it with the (unrelaxed) system POSCAR
mkdir $SYSTEM
cp ~/POSCARs/$SYSTEM $SYSTEM/POSCAR
cd $SYSTEM
echo -e "01\n103" | vaspkit | awk '/Summary/,EOF' >> README
sed "s/SYSTEM/$SYSTEM/" ~/scripts/jobscript > ./jobscript || { echo "Failed to modify jobscript for $SYSTEM"; exit 1; }

#Setup subdirectories for different calculation types
for CALC in bands elastic phonons relax; do
        mkdir $CALC
        sed "s/CALC/$CALC/" ./jobscript > ./$CALC/jobscript || { echo "Failed to modify jobscript for $CALC"; exit 1; }
	cp POTCAR ./$CALC/ || { echo "Failed to copy POTCAR file to $CALC"; exit 1; }
done

#Copy/create input files in relax subdirectory
cp POSCAR ./relax/ || { echo "Failed to copy POSCAR file to relax"; exit 1; }
mv POSCAR unrelaxedPOSCAR 

cd ./relax/
echo -e "101\nSR" | vaspkit
echo -e "102\n$KSCHEME\n$KPR" | vaspkit | { echo "Initial K-space";  awk '/Summary/,/+---------------------------------------------------------------+/'; } >> README

sed -e "/QUEUE/$RQUEUE/" -e "s/NODE/$RNODE/" -e "s/CORE/$RCORE/" -e "s/TIME/$RTIME/" jobscript > jobscript.tmp
mv jobscript.tmp jobscript

#Submit Standard relaxation jobscript
JOBID=$(sbatch jobscript | awk '{print $NF}')

# Debugging: Print the captured job ID
sleep 1
echo "Submitted job with ID: $JOBID"

# Check if the job ID is valid
if [[ -z $JOBID ]]; then
   	 echo "Error: Job ID not captured. Exiting."
   	 exit 1
fi

# Wait for the SLURM output file
while [ ! -f "vasp.${JOBID}.out" ]; do
	echo "Waiting for standard relaxation job number ${JOBID}..."
   	sleep 10
done

echo "Standard relaxation job number $JOBID completed."
mv CONTCAR POSCAR
#echo -e "101\nLR" | vaspkit

#sbatch jobscript

#cp CONTCAR ../POSCAR
cd ..
