# Compiling Deltares SWAN

The SWAN build uses Conan, copied from the Delft3D repository. Execute the following two steps:

## 1. One-time Conan configuration
See:   
https://github.com/Deltares/Delft3D/blob/main/doc/compiling_Linux.md   
https://github.com/Deltares/Delft3D/blob/main/doc/compiling_Windows.md

## 2. Run Conan, CMake configure, build, install

### Deltares developers (with Nexus access)
`python build.py [--build-type Release] [--mpi] [--build]`
### External / open-source developers (without Nexus access)
`python build.py --build-dependencies [--build-type Release] [--mpi] [--build]`
