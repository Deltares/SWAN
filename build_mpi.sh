#!/bin/bash
. /usr/share/Modules/init/bash

export I_MPI_F90=ifort
export FC=mpif90

module load intel/2023.1.0
module load intelmpi/2021.9.0
module load netcdf/4.9.2_4.6.1_intel2023.1.0
module load metis/5.2.1_intel2023.1.0
module load gklib/8bd6bad750b2b0d90800c632cf18e8ee93ad72d7_intel2023.1.0
# module load cmake/3.28.1_intel2023.1.0

export NetCDF_ROOT=/opt/apps/netcdf/4.9.2_4.6.1_intel2023.1.0
export Metis_ROOT=/opt/apps/metis/5.2.1_intel2023.1.0

cd swan
rm -rf build
mkdir build
cd build
cmake .. -DNETCDF=ON -DMPI=ON
cmake --build .
mv bin/swan.exe ../bin/swan_4145_1_tud_l64_i23_mpi.exe
cp bin/hcat.exe ../bin/hcat.exe
cd ../..
