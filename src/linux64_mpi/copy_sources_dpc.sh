#!/bin/sh

cp ../*.ftn .
cp ../*.ftn90 .
cp ../swanout1_deltares.inc .
cp ../switch.pl .

cp /opt/apps/netcdf/v4.7.4_v4.5.3_intel18.0.3/lib/libnetcdf.so.18 .
cp /opt/apps/netcdf/v4.7.4_v4.5.3_intel18.0.3/lib/libnetcdff.so.7 .

cp /opt/apps/hdf5/1.12.0_intel18.0.3/lib/libhdf5_hl.so.200.0.0 .
cp /opt/apps/hdf5/1.12.0_intel18.0.3/lib/libhdf5.so.200.0.0 .

cp /opt/apps/intel/18.0.3/lib/intel64/libimf.so .
cp /opt/apps/intel/18.0.3/lib/intel64/libsvml.so .
cp /opt/apps/intel/18.0.3/lib/intel64/libirng.so .
cp /opt/apps/intel/18.0.3/lib/intel64/libintlc.so.5 .
cp /opt/apps/intel/18.0.3/lib/intel64/libifport.so.5 .
cp /opt/apps/intel/18.0.3/lib/intel64/libifcoremt.so.5 .

sed -i 's/DELTARES VERSION/DELTARES MPI VERSION/g' swanmain.ftn
