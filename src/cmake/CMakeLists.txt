cmake_minimum_required(VERSION 3.30)

set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "" FORCE) 

project(SWAN LANGUAGES Fortran)

enable_language(Fortran C CXX)

include(functions.cmake)

#
# Handle command line options
option(USE_MPI "Use MPI for parallel computing" OFF)
option(PRECISION "Use single/double precision" SINGLE)
option(TIMING "Timing info in output" OFF)

if (USE_MPI)
    message("with MPI")
    set(CMAKE_Fortran_COMPILER mpiifx)
    set(MPI_SWITCH -mpi)
else()
    set(MPI_SWITCH )
endif(USE_MPI)

message("-- Precision: ${PRECISION}")

#
# Performance optimization,
# Introduced when switching to compiler Intel2024.2_IFX:
# OpenMP:
#     Windows:                  /arch:CORE-AVX2 /Qftz
#     Linux  :  NO fp=source    -arch CORE-AVX2  -ftz
# MPI:
#     Linux  :  NO fp=source    -arch CORE-AVX2
#

if (UNIX)
    if(PRECISION STREQUAL "DOUBLE")
        set(r8flag "-r8")
    else()
        set(r8flag "")
    endif()
    if(CMAKE_Fortran_COMPILER_ID MATCHES "GNU")
        if (NOT USE_MPI)
            set(openmp_flag1 " -O2 ${r8flag} -fopenmp -ffree-line-length-none -fallow-argument-mismatch ")
        else()
            set(openmp_flag1 " -O2 ${r8flag} -ffree-line-length-none  ")
        endif()
        set(openmp_flag2 )
    else()
        if (NOT USE_MPI)
            set(openmp_flag1 " -O0 ${r8flag} -qopenmp -arch CORE-AVX2 -ftz ")
            set(openmp_flag2 -qopenmp)
        else()
            set(openmp_flag1 " -O0 ${r8flag} -arch CORE-AVX2 ")
            set(openmp_flag2 )
        endif()
    endif()
    set(CMAKE_Fortran_FLAGS "${openmp_flag1} -diag-disable=8291 ")
    set(OS_SWITCH -unix)
else()
    if(PRECISION STREQUAL "DOUBLE")
        set(r8flag "/real-size:64")
    else()
        set(r8flag "")
    endif()
    if (NOT USE_MPI)
        set(openmp_flag1 "/Qopenmp ${r8flag} ")
    else()
        set(openmp_flag1 "${r8flag} ")
    endif()
    set(CMAKE_Fortran_FLAGS "/libs:dll /threads /nologo /heap-arrays:20 /Qauto /traceback /fp:source ${r8flag} /arch:CORE-AVX2 /Qftz ")
    set(CMAKE_Fortran_FLAGS_DEBUG "/fpp /debug:full /Od /dbglibs /debug-parameters:used \
                                   /check:bounds /check:stack /check:uninit ${openmp_flag1} ")
    set(CMAKE_Fortran_FLAGS_RELEASE "/fpp /Oy- /Qfp-speculation:safe ${openmp_flag1} ")
    set(openmp_flag2 /Qopenmp)
    set(OS_SWITCH -dos -cvis)
endif(UNIX)

if (TIMING)
    message("Timing added to output")
    set(TIMING_SWITCH -timg)
else()
    set(TIMING_SWITCH )
endif(TIMING)


if (WIN32)
    if (USE_MPI)
        message(STATUS "Intel MPI")
        list(APPEND CMAKE_MESSAGE_INDENT "  ")
            message(STATUS "Using Intel 2024 folder structure.")
            set(mpi_include_path $ENV{ONEAPI_ROOT}/mpi/latest/include)
            set(mpi_module_path ${mpi_include_path}/mpi)
            set(mpi_library_path $<IF:$<CONFIG:Debug>,$ENV{ONEAPI_ROOT}/mpi/latest/lib/mpi/debug,$ENV{ONEAPI_ROOT}/mpi/latest/lib>)
            set(mpi_fortran_library "impi.lib")
            set(mpi_c_library "impi.lib;impicxx.lib")
            message(STATUS "mpi include path \"${mpi_include_path}\"")
            message(STATUS "mpi module path \"${mpi_module_path}\"")
            message(STATUS "mpi library path \"${mpi_library_path}\"")
            message(STATUS "mpi fortran library \"${mpi_fortran_library}\"")
            message(STATUS "mpi c library \"${mpi_c_library}\"")
        list(POP_BACK CMAKE_MESSAGE_INDENT)
    endif (USE_MPI)
endif (WIN32)
if (UNIX)
    find_package(MPI REQUIRED)
    add_definitions(-DHAVE_MPI)
    set(mpi_module_path ${mpi_include_path})
endif(UNIX)


# Conan: add the CMakeDeps generator output to the search path and find all explicit dependencies.
# In the CMakeDeps generator, transitively depending on a dll counts as an explicit dependency,
# because we need to install the dll and deliver it to a user.
list(PREPEND CMAKE_PREFIX_PATH "${CMAKE_BINARY_DIR}/conan/generators")
find_package(netCDF CONFIG REQUIRED)
find_package(netCDF-Fortran CONFIG REQUIRED)

# generate directory where we place the generated code
file(MAKE_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/generated)

set( SWANMOD
    ${CMAKE_CURRENT_BINARY_DIR}/generated/m_constants.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/m_fileio.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/serv_xnl4v5.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/mod_xnl4v5.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanCompdata.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanGridobjects.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanGriddata.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swmod1.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swmod2.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/netcdf_tools.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/nctablemd.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/agioncmd.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swn_outnc.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/HRextensions.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanQCM.f90
)

set( SWANF
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swanmain.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanVertlist.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanTranspX.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanTranspAc.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanThreadBounds.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanSweepSel.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanSpectPart.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swanser.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanReadTriangleGrid.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanReadGrid.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanReadEasymeshGrid.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanReadADCGrid.f90
# Disabled:    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanParallel.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanPropvelX.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanPropvelS.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanPrintGridInfo.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanPrepComp.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swanpre2.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swanpre1.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanPointinMesh.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swanparll.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swanout2.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swanout1.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanIntgratSpc.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanInterpolatePoint.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanInterpolateOutput.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanInterpolateAc.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanInitCompGrid.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanGSECorr.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanGridVert.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanGridTopology.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanGridFace.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanGridCell.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanGradVel.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanGradDepthorK.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanFindPoint.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanFindObstacles.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanDispParm.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanDiffPar.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanCrossObstacle.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanCreateEdges.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanConvStopc.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanConvAccur.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanComputeForce.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanCompUnstruc.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swancom5.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swancom4.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swancom3.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swancom2.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swancom1.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanCheckGrid.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanBpntlist.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanBndStruc.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SdsBabanin.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/ocpmix.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/ocpids.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/ocpcre.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/fftpack51.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanVTKPDataSets.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanVTKWriteData.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanIEM.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanVTKWriteHeader.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanBraggScat.f90
)

set( HCAT
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swanhcat.for
)

file(GLOB SWAN_SOURCE_FILES 
    ${CMAKE_CURRENT_SOURCE_DIR}/../*.ftn
    ${CMAKE_CURRENT_SOURCE_DIR}/../*.ftn90
)

# generate code using switch.py
add_custom_command(
  OUTPUT
    ${SWANF} ${HCAT} ${SWANMOD}
  COMMAND
    python ${CMAKE_CURRENT_SOURCE_DIR}/../switch.py -netcdf ${OS_SWITCH} ${MPI_SWITCH} ${TIMING_SWITCH} *.ftn*
  WORKING_DIRECTORY
    ${CMAKE_CURRENT_SOURCE_DIR}/..
  DEPENDS
    ${CMAKE_CURRENT_SOURCE_DIR}/../switch.py
    ${SWAN_SOURCE_FILES}
  )

add_library(swanmod "")
target_sources(swanmod PRIVATE ${SWANMOD})

set(SWANEXE "swan")
if (USE_MPI)
    set(SWANEXE "${SWANEXE}_mpi")
else()
    set(SWANEXE "${SWANEXE}_omp")
endif()
if(PRECISION STREQUAL "DOUBLE")
    set(SWANEXE "${SWANEXE}_doubleprecision")
endif()
if (TIMING)
    set(SWANEXE "${SWANEXE}_timing")
endif()
if (UNIX)
    set(SWANEXE "${SWANEXE}.exe")
endif()

add_executable(${SWANEXE} "")
target_sources(${SWANEXE} PRIVATE ${SWANF})

# Add dependencies
if (UNIX)
    # the `pkg_check_modules` function is created with this call
    find_package(PkgConfig REQUIRED)
    target_link_libraries(swanmod netCDF::netcdff)
    target_link_libraries(${SWANEXE} swanmod netCDF::netcdff)
    add_definitions(-DHAVE_CONFIG_H=1)
endif(UNIX)

target_include_directories(${SWANEXE} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/generated .)

if (NOT USE_MPI)
    if(UNIX)
        target_link_options(swanmod PRIVATE ${openmp_flag2})
        target_link_options(${SWANEXE} PRIVATE ${openmp_flag2})
    endif(UNIX)
endif()

if(WIN32)
    target_link_libraries(swanmod netCDF::netcdff)
    target_link_libraries(${SWANEXE} swanmod netCDF::netcdff)
endif(WIN32)

if (USE_MPI)
    add_executable(hcat "")
    target_sources(hcat PRIVATE ${HCAT})
    target_include_directories(${SWANEXE} PRIVATE ${mpi_module_path})
    target_link_directories(${SWANEXE} PRIVATE "${mpi_library_path}")
    if(WIN32)
        target_link_libraries(${SWANEXE} "${mpi_fortran_library}")
    endif(WIN32)
endif(USE_MPI)

#
# Install
# Basicly copied from Delft3D
if (UNIX)
    set(platform_extension sh)
    set(library_suffix so)
    set(library_prefix lib)
elseif (WIN32)
    set(platform_extension bat)
    set(library_suffix dll)
    set(CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS_NO_WARNINGS TRUE) # Ignore warnings about missing ifort libs, we use ifx
    set(library_prefix "")
    include(InstallRequiredSystemLibraries)
    # CMake doesn't like back slashes entering via environment parameters
    STRING(REGEX REPLACE "\\\\" "/" DLL_PATHS_IMPI "$ENV{ONEAPI_ROOT}/mpi/latest/bin/impi.dll")
    STRING(REGEX REPLACE "\\\\" "/" DLL_PATHS_ILP "$ENV{ONEAPI_ROOT}/mpi/latest/bin/libmpi_ilp64.dll")
    STRING(REGEX REPLACE "\\\\" "/" DLL_PATHS_MPIEXEC "$ENV{ONEAPI_ROOT}/mpi/latest/bin/mpiexec.exe")
    STRING(REGEX REPLACE "\\\\" "/" DLL_PATHS_HYDRABSTRAP "$ENV{ONEAPI_ROOT}/mpi/latest/bin/hydra_bstrap_proxy.exe")
    STRING(REGEX REPLACE "\\\\" "/" DLL_PATHS_HYDRAPMI "$ENV{ONEAPI_ROOT}/mpi/latest/bin/hydra_pmi_proxy.exe")
    STRING(REGEX REPLACE "\\\\" "/" DLL_PATHS_HYDRASERVICE "$ENV{ONEAPI_ROOT}/mpi/latest/bin/hydra_service.exe")
    STRING(REGEX REPLACE "\\\\" "/" DLL_PATHS_FABRIC "$ENV{ONEAPI_ROOT}/mpi/latest/opt/mpi/libfabric/bin/libfabric.dll")
    STRING(REGEX REPLACE "\\\\" "/" DLL_PATHS_IFCOREMD "$ENV{ONEAPI_ROOT}/compiler/latest/bin/libifcoremd.dll")
    STRING(REGEX REPLACE "\\\\" "/" DLL_PATHS_MMD "$ENV{ONEAPI_ROOT}/compiler/latest/bin/libmmd.dll")
    STRING(REGEX REPLACE "\\\\" "/" DLL_PATHS_DISPMD "$ENV{ONEAPI_ROOT}/compiler/latest/bin/svml_dispmd.dll")
    STRING(REGEX REPLACE "\\\\" "/" DLL_PATHS_VCRUNTIME140 "c:/Windows/System32/vcruntime140.dll")
    set(DLL_PATHS
        "${DLL_PATHS_IMPI}"
        "${DLL_PATHS_ILP}"
        "${DLL_PATHS_MPIEXEC}"
        "${DLL_PATHS_HYDRABSTRAP}"
        "${DLL_PATHS_HYDRAPMI}"
        "${DLL_PATHS_HYDRASERVICE}"
        "${DLL_PATHS_FABRIC}"
        "${DLL_PATHS_IFCOREMD}"
        "${DLL_PATHS_MMD}"
        "${DLL_PATHS_DISPMD}"
        "${DLL_PATHS_VCRUNTIME140}"
        )
endif()

install(TARGETS ${SWANEXE} RUNTIME DESTINATION bin)
install(FILES $<TARGET_RUNTIME_DLLS:${SWANEXE}> DESTINATION bin)
if (UNIX)
    install(CODE "
        include(\"${CMAKE_CURRENT_SOURCE_DIR}/functions.cmake\")
        execute_process(
            COMMAND bash
                \"${CMAKE_CURRENT_SOURCE_DIR}/copy_libs.sh\"
                \"${CMAKE_INSTALL_PREFIX}/bin\"
                \"${CMAKE_BINARY_DIR}/conan/generators\"
            RESULT_VARIABLE result
        )
        if(NOT result EQUAL 0)
            message(FATAL_ERROR \"copy_libs.sh failed with exit code \${result}\")
        endif()

        set_rpath(\"${CMAKE_INSTALL_PREFIX}/bin\" \"$ORIGIN:$ORIGIN/../lib\")
        set_rpath(\"${CMAKE_INSTALL_PREFIX}/lib\" \"$ORIGIN\")
        file(REMOVE \"${CMAKE_INSTALL_PREFIX}/lib/libc.so.6\")
        file(REMOVE \"${CMAKE_INSTALL_PREFIX}/lib/libgcc_s.so.1\")
    ")
elseif (WIN32)
    install(PROGRAMS ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS} DESTINATION bin)
    install(PROGRAMS ${DLL_PATHS} DESTINATION bin)
endif()
