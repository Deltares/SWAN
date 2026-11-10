import sys
import glob
import re
import os

verbose = 0
buildir = 'build'
for x in sys.argv[1:]:
    if (x == 'verbose'):
        verbose = 1
    elif (x.startswith('buildir=')):
        buildir = x.split('=', 1)[1]


d = [
['-esmf'   , 0, '^!ESMF',   '^!!ESMF'],
['-timg'   , 0, '^!TIMG',   ''],
['-jac'    , 0, '^!JAC' ,   '^!WFR'],
['-metis'  , 0, '^!METIS',  '^!NMETIS'],
['-mpi'    , 0, '^!MPI' ,   '^!NMPI'],
['-pun'    , 0, '^!PUN' ,   '^!NPUN'],
['-f95'    , 0, '^!F95' ,   ''],
['-dos'    , 0, '^!DOS' ,   ''],
['-unix'   , 0, '^!UNIX',   ''],
['-cray'   , 0, '^!/Cray',  ''],
['-sgi'    , 0, '^!/SGI',   ''],
['-impi'   , 0, '^!/impi',  ''],
['-cvis'   , 0, '^!CVIS',   ''],
['-adcirc' , 0, '^!ADC',    '^!NADC'],
['-coh'    , 0, '^!COH',    '^!NCOH'],
['-netcdf' , 0, '^!NCF',    '^!NNCF'],
['-matl4 ' , 0, '^!MatL4',  '^!MatL5']
]

# adjust d based on command line arguments
for x in sys.argv[1:]:
    for i,content in enumerate(d):
        if (x == d[i][0]):
            d[i][1] = 1

if (verbose > 0):
    for p in d:
        print(p)

def switch_line(line):
    switched = line
    for item in d:
        flag = item[1];
        if (flag):
            switched = re.sub(item[2], '', switched)
        elif (item[3] != ''):
            switched = re.sub(item[3], '', switched)
    return switched

# Regenerate when feature switches change, even if the templates are unchanged.
generated_dir = os.path.join("..", buildir, "generated")
os.makedirs(generated_dir, exist_ok=True)
state_file = os.path.join(generated_dir, ".swan_switches")
switch_state = repr([(item[0], item[1]) for item in d])
try:
    with open(state_file, encoding="ascii") as state:
        switches_changed = state.read() != switch_state
except FileNotFoundError:
    switches_changed = True


def need_update(old, new):
    newfile_exists = os.path.isfile(new)
    if switches_changed or not newfile_exists:
        return 1

    modtime_old = os.path.getmtime(old)
    modtime_new = os.path.getmtime(new)

    return max(modtime_old, os.path.getmtime(__file__)) > modtime_new

def switch_content(old, new):
    if not need_update(old, new):
        if (verbose > 1):
            print(old + ' is up-to-date\n')
        return

    if (verbose > 1):
        print(old+'->'+new+'\n')
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
    switch_content(f1, os.path.join("..", buildir, 'generated', f1new))

for f2 in free:
    f2new = re.sub('ftn90$', 'f90', f2)
    switch_content(f2, os.path.join("..", buildir, 'generated', f2new))

# Record switches only after every source file has been generated successfully.
with open(state_file, "w", encoding="ascii") as state:
    state.write(switch_state)
