Work flow for compiling / debugging under Windows.

1) copy Fortran files using 'copy_sources.bat'

2) check NetCDF path in macros.inc

3) compile using: 'nmake omp'

4) check NetCDF path in swan.vfproj

5) debug: open 'swan.sln' in Visual Studio
