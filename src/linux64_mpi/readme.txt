Work flow for compiling Swan

1) copy Fortran files using './copy_sources.sh'

2) check NetCDF path in macros.inc

3) select compiler: '. /opt/intel/composer_xe_2013.5.192/bin/ifortvars.sh intel64'

4) add mpif90 to path: 'export PATH=/opt/mpich2-1.0.8-intel64/bin:$PATH'

5) compile using: 'make mpi'

