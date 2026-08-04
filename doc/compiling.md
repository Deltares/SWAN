# Compiling Deltares SWAN

The SWAN build uses Conan, copied from the Delft3D repository. Execute the following two steps:

## 1. One-time Conan configuration
See:   
https://github.com/Deltares/Delft3D/blob/main/doc/compiling_Linux.md   
https://github.com/Deltares/Delft3D/blob/main/doc/compiling_Windows.md   
When all one-time configuration is done:   
`python run_conan.py initialize deltares` (or `external`)


## 2. Run Conan, CMake configure, build, install

### Deltares developers (with Nexus access)
`python build.py <options>`
### External / open-source developers (without Nexus access)
`python build.py --build-dependencies <options>`
### <options>
#### Options specific for SWAN
**--mpi** : Build MPI version of SWAN   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  "_mpi" is added to the name of the binary being build   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  Default: without mpi; "_omp" is added to the name of the binary being build   
**--timing** : SWAN writes timing information to the PRINT file   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  "_timing" is added to the name of the binary being build   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  Default: without timing   
**--double** : Build SWAN using double precision reals instead of single precision   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  "_doubleprecision" is added to the name of the binary being build   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  Default: single precision reals   
**--cmake_trace** : CMake config with verbose output   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  Default: without trace   
**--cmake_verbose** : Build/compile with verbose output   
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
  Default: without verbose   
#### Options inherited from Delft3D
**--build** : Execute build/compile/install after the configure phase   
**--build-type Release**   
**--build-type Debug**   
**--build-dir build_dir**   
**--install-dir install_dir**   
**--ci**   
**--keep-build**   
**--vs**   
**--profile**   
#### Options *not* inherited from Delft3D
**--config**