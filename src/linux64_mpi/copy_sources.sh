#!/bin/sh

cp ../*.ftn .
cp ../*.ftn90 .
cp ../swanout1_deltares.inc .
cp ../switch.pl .

cp /opt/netcdf/v4.6.2_v4.4.4_intel_18.0.3/lib/libnetcdf.so.13 .
cp /opt/netcdf/v4.6.2_v4.4.4_intel_18.0.3/lib/libnetcdff.so.6 .

sed -i 's/DELTARES VERSION/DELTARES MPI VERSION/g' swanmain.ftn
