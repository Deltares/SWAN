@echo off

call "%IFORT_COMPILER21%\..\env\vars.bat" intel64 vs2019

nmake omp

