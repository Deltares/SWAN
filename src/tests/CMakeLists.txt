add_library(swan_test_process_memory STATIC process_memory.c)
add_executable(swan_partition_test test_partition_setup.f90)

set(swan_module_dir ${SWANMOD_MODULE_DIRECTORY})
if(NOT swan_module_dir)
    set(swan_module_dir "${CMAKE_Fortran_MODULE_DIRECTORY}")
endif()
target_include_directories(swan_partition_test PRIVATE
    "${swan_module_dir}"
    "${swan_module_dir}/$<CONFIG>")
target_link_libraries(swan_partition_test PRIVATE ${SWANLIB} swanmod netCDF::netcdff swan_test_process_memory)

if(WIN32)
    target_include_directories(swan_partition_test PRIVATE "${mpi_module_path}")
    target_link_directories(swan_partition_test PRIVATE "${mpi_library_path}")
    target_link_libraries(swan_partition_test PRIVATE "${mpi_fortran_library}" Psapi)
    get_filename_component(mpi_root "${mpi_include_path}" DIRECTORY)
    find_program(swan_mpiexec NAMES mpiexec.exe HINTS "${mpi_root}/bin" NO_DEFAULT_PATH REQUIRED)
    set(swan_process_flag -n)
else()
    find_package(MPI REQUIRED COMPONENTS Fortran)
    target_link_libraries(swan_partition_test PRIVATE MPI::MPI_Fortran)
    set(swan_mpiexec "${MPIEXEC_EXECUTABLE}")
    set(swan_process_flag "${MPIEXEC_NUMPROC_FLAG}")
endif()

foreach(mode connected disconnected repeated)
    add_test(NAME swan_partition_${mode}
        COMMAND "${swan_mpiexec}" ${swan_process_flag} 2 ${MPIEXEC_PREFLAGS}
            $<TARGET_FILE:swan_partition_test> ${MPIEXEC_POSTFLAGS} ${mode})
    set_tests_properties(swan_partition_${mode} PROPERTIES
        PROCESSORS 2
        TIMEOUT 120)
endforeach()
set_tests_properties(swan_partition_repeated PROPERTIES SKIP_RETURN_CODE 77)
