#!/bin/bash

# Usage:
# In your working folder, make sure that the file named “INPUT” is present, containing the SWAN input.
# Execute the swan executable in the working folder. The executable is able to find all needed so-files.
#
# Alternative for using binaries from /p/swan/Releases:
#   Download SWAN binaries from Nexus, for example by using Python script "download_swan_from_nexus.py"
#   When executing "python download_swan_from_nexus.py", follow the instructions printed to screen
#
# Copy this script into your working folder
# Change settings in this submit file
# Login on HAL8 and execute:
#   sbatch submit_swan_omp_HAL8.sh

#SBATCH --job-name=swan_omp4    # Job name
#SBATCH --ntasks=1              # Number of processes
#SBATCH --partition=4vcpu       # Type of node(s)
#SBATCH --nodes=1               # Maximum number of nodes to be allocated
#SBATCH --time 00:15:00         # Maximum runtime

export OMP_NUM_THREADS=4
/p/swan/Releases/41.51.10/lnx64/bin/swan_omp.exe
