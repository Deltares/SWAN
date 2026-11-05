@echo off

rem Usage:
rem In your working folder, make sure that the file named “INPUT” is present, containing the SWAN input.
rem Execute the swan executable in the working folder. The executable is able to find all needed dlls.
rem
rem Alternative for using binaries from p:\swan\Releases:
rem   Download SWAN binaries from Nexus, for example by using Python script "download_swan_from_nexus.py"
rem   When executing "python download_swan_from_nexus.py", follow the instructions printed to screen
rem
rem Copy this script into your working folder
rem Change settings in this run script
rem Execute this run script
 
set OMP_NUM_THREADS=4

p:\swan\Releases\41.51.10\x64\bin\swan_omp.exe
