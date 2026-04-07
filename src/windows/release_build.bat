@echo off

call "%IFORT_COMPILER18%\bin\ifortvars.bat" intel64
call "c:\Program Files (x86)\Microsoft Visual Studio 14.0\VC\vcvarsall.bat" amd64

nmake omp

