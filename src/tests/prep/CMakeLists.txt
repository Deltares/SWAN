add_executable(swan_prep_comp_test test_prep_comp.f90)
target_include_directories(swan_prep_comp_test PRIVATE
    "${SWANMOD_MODULE_DIRECTORY}"
    "${SWANMOD_MODULE_DIRECTORY}/$<CONFIG>")
target_link_libraries(swan_prep_comp_test PRIVATE ${SWANLIB})
if(WIN32 AND USE_MPI)
    target_link_directories(swan_prep_comp_test PRIVATE "${mpi_library_path}")
endif()

add_test(NAME swan_prep_comp COMMAND swan_prep_comp_test)
set_tests_properties(swan_prep_comp PROPERTIES TIMEOUT 30)
