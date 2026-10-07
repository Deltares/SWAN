@echo off

rem Usage:
rem - Download SWAN binaries from Nexus, for example by using Python script "download_swan_from_nexus.py"
rem   When executing "python download_swan_from_nexus.py", follow the instructions printed to screen
rem - Change settings in this run script
rem - Execute this run script
 
set OMP_NUM_THREADS=4

c:\path\to\the\downloaded\swan\version\x64\bin\swan_omp.exe
