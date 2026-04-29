import sys
import glob
import re
import os

verbose = 0
for x in sys.argv[1:]:
    parts = x.split('=')
    if (len(parts) > 1):
       if (parts[0] == 'verbose'):
           verbose = int(parts[1])

d = [
('-esmf'   , 0, '^!ESMF',   '^!!ESMF'),
('-timg'   , 0, '^!TIMG',   ''),
('-jac'    , 0, '^!JAC' ,   '^!WFR'),
('-mpi'    , 0, '^!MPI' ,   ''),
('-pun'    , 0, '^!PUN' ,   '^!NPUN'),
('-f95'    , 0, '^!F95' ,   ''),
('-dos'    , 0, '^!DOS' ,   ''),
('-unix'   , 0, '^!UNIX',   ''),
('-cray'   , 0, '^!\/Cray', ''),
('-sgi'    , 0, '^!\/SGI',  ''),
('-impi'   , 0, '^!\/impi', ''),
('-cvis'   , 0, '^!CVIS',   ''),
('-adcirc' , 0, '^!ADC',    '^!NADC'),
('-coh'    , 0, '^!COH',    '^!NCOH'),
('-netcdf' , 0, '^!NCF',    '^!NNCF'),
('-matl4 ' , 0, '^!MatL4',  '^!MatL5')
]

# adjust d based on command line arguments
for x in sys.argv[1:]:
    for item in d:
        if (x == item[0]):
                item = (item[0], 1, item[2:3])

if (verbose > 0):
    for p in d:
        print p

def switch_line(line):
    switched = line
    for item in d:
        flag = item[1];
        if (flag):
            switched = re.sub(item[2], '', switched)
        elif (item[3] != ''):
            switched = re.sub(item[3], '', switched)
    return switched

def need_update(old, new):
    newfile_exists = os.path.isfile(new)
    if not newfile_exists:
        return 1

    modtime_old = os.path.getmtime(old)
    modtime_new = os.path.getmtime(new)

    return modtime_old > modtime_new

def switch_content(old, new):
    if not need_update(old, new):
        if (verbose > 1):
            print old, ' is up-to-date'
        return

    if (verbose > 1):
        print old, '->', new
    f_in = open(old, 'r')
    f_out = open(new, 'w')

    for line in f_in:
        f_out.write(switch_line(line))

    f_in.close()
    f_out.close()

# main :

fixed = glob.glob('*.ftn')
free  = glob.glob('*.ftn90')

for f1 in fixed:
    f1new = re.sub('ftn$', 'for', f1)
    switch_content(f1, f1new)

for f2 in free:
    f2new = re.sub('ftn90$', 'f90', f2)
    switch_content(f2, f2new)
