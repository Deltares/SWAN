#!/bin/sh

cp ../*.ftn .
cp ../*.ftn90 .
cp ../swanout1_deltares.inc .
cp ../switch.pl .

sed -i 's/DELTARES VERSION/DELTARES MPI VERSION/g' swanmain.ftn
