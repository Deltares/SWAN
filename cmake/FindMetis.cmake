# a CMake script to try to find Metis include path and libraries
#
# Copyright (C) 2023  Delft University of Technology
#
# this script reports the following variables:
#
#  Metis_INCLUDE_DIR - include directory where metis.h is resided
#  Metis_LIBRARIES   - libraries to link against to use Metis
#  Metis_FOUND       - flag indicating whether Metis was found or not
#
# the following path will be searched (if available):
#
#  Metis_ROOT (set as environment variable)

# search for include path
find_path( Metis_INCLUDE_DIR
           NAMES metis.h
           PATHS ENV Metis_ROOT Metis_PATH METIS_ROOT METIS_PATH
           HINTS $ENV{HOME}/local $ENV{HOME}/metis /usr /usr/local /opt/local /opt/metis
           PATH_SUFFIXES include
         )
mark_as_advanced( Metis_INCLUDE_DIR )

# search for libraries
find_library( Metis_LIBRARY
              NAMES libmetis.a libmetis.so
              PATHS ENV Metis_ROOT Metis_PATH METIS_ROOT METIS_PATH
              HINTS $ENV{HOME}/local $ENV{HOME}/metis /usr /usr/local /opt/local /opt/metis
              PATH_SUFFIXES lib lib32 lib64
            )
set( Metis_LIBRARIES ${Metis_LIBRARY} )

find_library( GK_LIBRARY
              NAMES libGKlib.a libGKlib.so
              PATHS ENV Metis_ROOT Metis_PATH METIS_ROOT METIS_PATH
              HINTS $ENV{HOME}/local $ENV{HOME}/metis /usr /usr/local /opt/local /opt/metis
              PATH_SUFFIXES lib lib32 lib64
            )
list( APPEND Metis_LIBRARIES ${GK_LIBRARY} )

mark_as_advanced( Metis_LIBRARIES )

# state whether Metis has been found or not
include( FindPackageHandleStandardArgs )
find_package_handle_standard_args( Metis DEFAULT_MSG Metis_INCLUDE_DIR )
find_package_handle_standard_args( Metis DEFAULT_MSG Metis_LIBRARIES )
