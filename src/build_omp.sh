#!/bin/bash
. /usr/share/Modules/init/bash
export MODULEPATH=/opt/apps/modules:$MODULEPATH

svn revert swanmain.ftn
svn revert CMakeLists.txt

sed -i 's/DELTARES VERSION/DELTARES OMP VERSION/g' swanmain.ftn

# remove file for METIS
sed -i '/SwanParallel/d' CMakeLists.txt

module load intel/2023.1.0
module load netcdf/4.9.2_4.6.1_intel2023.1.0
module load cmake/3.28.1_intel2023.1.0
module load gcc/12.2.0_gcc12.2.0
# module load metis/5.2.1_intel2023.1.0
# module load gklib/8bd6bad750b2b0d90800c632cf18e8ee93ad72d7_intel2023.1.0

# module load cmake/3.26.4_intel2023.1.0
export NetCDF_ROOT=/opt/apps/netcdf/4.9.2_4.6.1_intel2023.1.0
# export Metis_ROOT=/opt/apps/metis/5.2.1_intel2023.1.0

mkdir -p bin
rm -rf build
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_Fortran_COMPILER="/opt/apps/intel/2023.1.0/compiler/2023.1.0/linux/bin/intel64/ifort"

cmake --build .
mv swan_omp.exe ../bin/swan_4145_2_del_l64_i23_omp.exe
cd ..
