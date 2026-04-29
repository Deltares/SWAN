cmake_minimum_required(VERSION 3.5 FATAL_ERROR)

set(CMAKE_CONFIGURATION_TYPES "Debug;Release" CACHE STRING "" FORCE) 

project(SWAN LANGUAGES Fortran)

enable_language(Fortran C CXX)

option(USE_MPI "Use MPI for parallel computing" OFF)
option(PRECISION "Use single/double precision" SINGLE)

if (USE_MPI)
    message("with MPI")
    set(CMAKE_Fortran_COMPILER mpif90)
    set(MPI_SWITCH -mpi)
else()
    set(MPI_SWITCH )
endif(USE_MPI)

message("-- Precision: ${PRECISION}")

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
            set(openmp_flag1 " -O2 ${r8flag} -qopenmp")
            set(openmp_flag2 -qopenmp)
        else()
            set(openmp_flag1 " -O2 ${r8flag} ")
            set(openmp_flag2 )
        endif()
    endif()
    set(CMAKE_Fortran_FLAGS "${openmp_flag1} ")
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
    set(CMAKE_Fortran_FLAGS "/libs:dll /threads /nologo /heap-arrays:20 /Qauto /traceback /fp:source ${r8flag} ")
    set(CMAKE_Fortran_FLAGS_DEBUG "/fpp /debug:full /Od /dbglibs /debug-parameters:used \
                                   /check:bounds /check:stack /check:uninit ${openmp_flag1} ")
    set(CMAKE_Fortran_FLAGS_RELEASE "/fpp /Oy- /Qfp-speculation:safe ${openmp_flag1} ")
    set(openmp_flag2 /Qopenmp)
    set(OS_SWITCH -dos -cvis)
endif(UNIX)

# oss_include_libraries
# Adds oss dependencies to the specified library.
#
# Note that it is assumed that the dependency is located in the PROJECT_BINARY_DIR in a subdirectory with the same dependency name.
#
# Argument
# library_name : The name of the library where dependencies should be added.
# dependencies : A list of dependencies to set for the library_name.
function(oss_include_libraries library_name dependencies)

    foreach(dependency IN LISTS ${dependencies})
        add_dependencies(${library_name} ${dependency})
        if (UNIX)
            include_directories( ${PROJECT_BINARY_DIR}/${dependency} )
        endif()
    endforeach()

endfunction()

set(netcdf_version NetCDF_4.6.1)

if (WIN32)
    add_subdirectory(netcdf/cmake_deltares)
endif(WIN32)

# we require Perl for this recipe to work
find_package(Perl QUIET REQUIRED)

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
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanSumOverNodes.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanSpectPart.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swanser.for
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanReadTriangleGrid.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanReadGrid.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanReadfort18.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanReadEasymeshGrid.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanReadADCGrid.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanPunCollect.f90
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
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanMinOverNodes.f90
    ${CMAKE_CURRENT_BINARY_DIR}/generated/SwanMaxOverNodes.f90
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
    ${CMAKE_CURRENT_BINARY_DIR}/generated/swan2coh.f90
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

# not needed: ${CMAKE_CURRENT_BINARY_DIR}/generated/HottifySWAN.f90

# generate code
add_custom_command(
  OUTPUT
    ${SWANF} ${HCAT} ${SWANMOD}
  COMMAND
    ${PERL_EXECUTABLE} switch.pl -netcdf ${OS_SWITCH} ${MPI_SWITCH} *.ftn*
  WORKING_DIRECTORY
    ${CMAKE_CURRENT_SOURCE_DIR}
  DEPENDS
    switch.pl
  )

add_library(swanmod "")

target_sources(swanmod
  PRIVATE
    ${SWANMOD}
  )

set(SWANEXE "swan")
if (r8flag STREQUAL "-r8" OR r8flag STREQUAL "/real-size:64")
    set(SWANEXE "${SWANEXE}_r8")
endif()
if (USE_MPI)
    set(SWANEXE "${SWANEXE}_mpi")
else()
    set(SWANEXE "${SWANEXE}_omp")
endif()
if (UNIX)
    set(SWANEXE "${SWANEXE}.exe")
endif()

add_executable(${SWANEXE} "")

target_sources(${SWANEXE}
  PRIVATE
    ${SWANF}
  )

# Add dependencies
if (UNIX)
    # the `pkg_check_modules` function is created with this call
    find_package(PkgConfig REQUIRED)

    # these calls create special `PkgConfig::<MODULE>` variables
    pkg_check_modules(NETCDF REQUIRED IMPORTED_TARGET netcdf)
    pkg_check_modules(NETCDF_FTN REQUIRED IMPORTED_TARGET netcdf-fortran)

    target_link_libraries(swanmod
         PkgConfig::NETCDF
         PkgConfig::NETCDF_FTN)

    target_link_libraries(${SWANEXE}
         swanmod
         PkgConfig::NETCDF
         PkgConfig::NETCDF_FTN)

    #include_directories("${CMAKE_CURRENT_SOURCE_DIR}/include")

    add_definitions(-DHAVE_CONFIG_H=1)
endif(UNIX)

target_include_directories(${SWANEXE}
  PRIVATE
    ${CMAKE_CURRENT_BINARY_DIR}/generated
    .
  )

if (NOT USE_MPI)
    if(UNIX)
        target_link_options(swanmod PRIVATE ${openmp_flag2})
        target_link_options(${SWANEXE} PRIVATE ${openmp_flag2})
    endif(UNIX)
endif()

if(WIN32)
    target_link_libraries(swanmod netcdf4 netcdff netcdf)
    target_link_libraries(${SWANEXE} swanmod netcdf4 netcdff netcdf)
endif(WIN32)

target_link_directories(${SWANEXE}
         PRIVATE
         "netcdf/${netcdf_version}/lib")

if (USE_MPI)
add_executable(hcat "")
target_sources(hcat
  PRIVATE
    ${HCAT}
  )
endif(USE_MPI)

