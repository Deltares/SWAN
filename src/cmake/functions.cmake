# Function to return ifort version number
# This function is copied from the Delft3D repository
function(get_intel_version)
    # Intel OneAPI versions have different version numbers for their compilers.
    # Furthermore, the compiler versions reported through CMAKE_Fortran_COMPILER_VERSION do not always match the official compiler version string.
    # Before OneAPI 2021, the compiler version matches the ifort version (e.g., 2020.2)
    # After OneAPI 2024, the compiler version matches the ifx version (e.g., 2025.1)
    # In between, the ifx version does match the OneAPI version, but the ifort version is always reported as 2021.x(x).x.xxxxxxxx.
    # Up to and including version 2023, the 2021.x version kept increasing, but in OneAPI 2024 the version reported in CMake goes back to 2021.0 or 2021.1.
    if (${CMAKE_Fortran_COMPILER_VERSION} MATCHES "^2021\\.[0-9]\\.[0-9]\\.(20231010|202[4-9][0-9][0-9][0-9][0-9])|^2024[\\.0-9]*")
        set(intel_version 24 PARENT_SCOPE)
    elseif (${CMAKE_Fortran_COMPILER_VERSION} MATCHES "^2021\\.(8|9|10)\\.[\\.0-9]*|^2023[\\.0-9]*")
        set(intel_version 23 PARENT_SCOPE)
    elseif (${CMAKE_Fortran_COMPILER_VERSION} MATCHES "^2021\\.(5|6|7)\\.[\\.0-9]*|^2022[\\.0-9]*")
        set(intel_version 22 PARENT_SCOPE)
    elseif (${CMAKE_Fortran_COMPILER_VERSION} MATCHES "^20([0-9][0-9])[\\.0-9]*")
        set(intel_version ${CMAKE_MATCH_1} PARENT_SCOPE) # Set to the result of the first capture group in parentheses (the last two year numbers, for example 25)
    else()
        message(FATAL_ERROR "Intel version ${CMAKE_Fortran_COMPILER_VERSION} is not recognized.")
    endif()
    if (NOT DEFINED ENV{ONEAPI_ROOT})
        if (WIN32)
            message(FATAL_ERROR "ONEAPI_ROOT environment variable not found. \nPlease run CMake from an intel oneapi command prompt for intel 64.")
        else()
            message(FATAL_ERROR "ONEAPI_ROOT environment variable not found. \nPlease ensure that the intel environment is set via an environment module or via a setvars script.")
        endif()
    endif()
endfunction()

# Find all binaries in "targetDir" and set rpath to "rpathValue" in these binaries
# This function is copied from the Delft3D repository
function(set_rpath targetDir rpathValue)
  execute_process(COMMAND find "${targetDir}" -type f -exec bash -c "patchelf --set-rpath '${rpathValue}' $1" _ {} \; -exec echo "patched rpath of: " {} \;)
endfunction(set_rpath)
