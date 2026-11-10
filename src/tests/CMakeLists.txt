if(WIN32)
    get_filename_component(mpi_root "${mpi_include_path}" DIRECTORY)
    find_program(swan_mpiexec NAMES mpiexec.exe HINTS "${mpi_root}/bin" NO_DEFAULT_PATH REQUIRED)
    set(swan_process_flag -n)
else()
    find_package(MPI REQUIRED COMPONENTS Fortran)
    set(swan_mpiexec "${MPIEXEC_EXECUTABLE}")
    set(swan_process_flag "${MPIEXEC_NUMPROC_FLAG}")
endif()

add_executable(swan_check_spectral_records check_spectral_records.f90)
target_link_libraries(swan_check_spectral_records PRIVATE netCDF::netcdff)

foreach(ranks 2 4)
    foreach(case collection hotstart)
        add_test(NAME swan_mpi_${case}_${ranks}
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/test_mpi_spectral_io.py"
                ${case} $<TARGET_FILE:swan_check_spectral_records>
                "${swan_mpiexec}" ${swan_process_flag} ${ranks} ${MPIEXEC_PREFLAGS}
                $<TARGET_FILE:${SWANEXE}> ${MPIEXEC_POSTFLAGS})
        set_tests_properties(swan_mpi_${case}_${ranks} PROPERTIES
            PROCESSORS ${ranks}
            TIMEOUT 120)
    endforeach()
endforeach()

if(USE_METIS)
    add_library(swan_test_process_memory STATIC process_memory.c)
    add_executable(swan_partition_test test_partition_setup.f90)
    target_include_directories(swan_partition_test PRIVATE
        "${SWANMOD_MODULE_DIRECTORY}"
        "${SWANMOD_MODULE_DIRECTORY}/$<CONFIG>")
    target_link_libraries(swan_partition_test PRIVATE ${SWANLIB} swanmod netCDF::netcdff swan_test_process_memory)

    if(WIN32)
        target_include_directories(swan_partition_test PRIVATE "${mpi_module_path}")
        target_link_directories(swan_partition_test PRIVATE "${mpi_library_path}")
        target_link_libraries(swan_partition_test PRIVATE "${mpi_fortran_library}" Psapi)
    else()
        target_link_libraries(swan_partition_test PRIVATE MPI::MPI_Fortran)
    endif()

    foreach(mode connected disconnected edge_cases repeated)
        add_test(NAME swan_partition_${mode}
            COMMAND "${swan_mpiexec}" ${swan_process_flag} 2 ${MPIEXEC_PREFLAGS}
                $<TARGET_FILE:swan_partition_test> ${MPIEXEC_POSTFLAGS} ${mode})
        set_tests_properties(swan_partition_${mode} PROPERTIES
            PROCESSORS 2
            TIMEOUT 120)
    endforeach()
    set_tests_properties(swan_partition_repeated PROPERTIES SKIP_RETURN_CODE 77)

    foreach(ranks 2 4)
        add_test(NAME swan_partition_metis_${ranks}
            COMMAND "${swan_mpiexec}" ${swan_process_flag} ${ranks} ${MPIEXEC_PREFLAGS}
                $<TARGET_FILE:swan_partition_test> ${MPIEXEC_POSTFLAGS} metis)
        set_tests_properties(swan_partition_metis_${ranks} PROPERTIES
            PROCESSORS ${ranks}
            TIMEOUT 120)
    endforeach()
endif()
