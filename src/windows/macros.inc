##############################################################################
# IA32_Intel/EM64T_Intel:	Intel Pentium with MS Windows using Intel compiler 12.
##############################################################################
F90_SER = ifort
F90_OMP = ifort
F90_MPI =
FLAGS_OPT = /O2 /F:0x8ffffff
FLAGS_MSC = /nologo /warn:none /assume:byterecl /traceback
FLAGS90_MSC = $(FLAGS_MSC)
FLAGS_SER =
FLAGS_OMP = /Qopenmp
FLAGS_MPI =
NETCDFROOT = ..\lib_netcdf_w64_oneapi
!IF DEFINED(NETCDFROOT)
INCS_SER = /include:$(NETCDFROOT)
INCS_OMP = /include:$(NETCDFROOT)
INCS_MPI =
LIBSC = /link /LTCG /NODEFAULTLIB:LIBC.lib /NODEFAULTLIB:LIBCMTD.lib /NODEFAULTLIB:LIBCMT.lib msvcrt.lib
LIBS_SER = $(NETCDFROOT)\f90_netcdf.lib $(NETCDFROOT)\f77_netcdf.lib $(NETCDFROOT)\netcdf.lib $(LIBSC)
LIBS_OMP = $(NETCDFROOT)\f90_netcdf.lib $(NETCDFROOT)\f77_netcdf.lib $(NETCDFROOT)\netcdf.lib $(LIBSC)
LIBS_MPI =
NCF_OBJS = netcdf_tools.obj nctablemd.obj agioncmd.obj swn_outnc.obj HRextensions.obj
!ELSE
INCS_SER =
INCS_OMP =
INCS_MPI =
LIBS_SER =
LIBS_OMP =
LIBS_MPI =
NCF_OBJS =
!ENDIF
O_DIR =
OUT = /exe:
EXTO = obj
MAKE = nmake
RM = del
!IF DEFINED(NETCDFROOT)
swch = -dos -impi -cvis -netcdf -matl4
!ELSE
swch = -dos -impi -cvis -matl4
!ENDIF
