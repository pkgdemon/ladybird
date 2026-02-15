# FindGNUstep.cmake
# Finds GNUstep libraries and creates imported targets
#
# This module defines the following IMPORTED targets:
#   GNUstep::Base - The GNUstep Foundation library
#   GNUstep::GUI  - The GNUstep AppKit library
#
# This module will set the following variables:
#   GNUstep_FOUND        - True if GNUstep was found
#   GNUstep_INCLUDE_DIRS - Include directories for GNUstep
#   GNUstep_LIBRARIES    - Libraries to link against
#   GNUstep_CFLAGS       - Compiler flags for GNUstep
#
# Usage:
#   find_package(GNUstep REQUIRED)
#   target_link_libraries(myapp GNUstep::Base GNUstep::GUI)

include(FindPackageHandleStandardArgs)

# Try pkg-config first (works for Debian-style installations)
find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
    pkg_check_modules(_GNUSTEP_BASE QUIET gnustep-base)
    pkg_check_modules(_GNUSTEP_GUI QUIET gnustep-gui)
endif()

# Try gnustep-config (should be in PATH if GNUstep is installed)
find_program(GNUSTEP_CONFIG gnustep-config)

if(GNUSTEP_CONFIG)
    execute_process(
        COMMAND ${GNUSTEP_CONFIG} --objc-flags
        OUTPUT_VARIABLE _GNUSTEP_OBJC_FLAGS
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    execute_process(
        COMMAND ${GNUSTEP_CONFIG} --variable=GNUSTEP_SYSTEM_LIBRARIES
        OUTPUT_VARIABLE _GNUSTEP_SYSTEM_LIBRARIES
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
    execute_process(
        COMMAND ${GNUSTEP_CONFIG} --variable=GNUSTEP_SYSTEM_HEADERS
        OUTPUT_VARIABLE _GNUSTEP_SYSTEM_HEADERS
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
endif()

# Build search paths from pkg-config and gnustep-config results
set(_GNUSTEP_LIBRARY_SEARCH_PATHS
    ${_GNUSTEP_BASE_LIBRARY_DIRS}
    ${_GNUSTEP_GUI_LIBRARY_DIRS}
    ${_GNUSTEP_SYSTEM_LIBRARIES}
)

set(_GNUSTEP_INCLUDE_SEARCH_PATHS
    ${_GNUSTEP_BASE_INCLUDE_DIRS}
    ${_GNUSTEP_GUI_INCLUDE_DIRS}
    ${_GNUSTEP_SYSTEM_HEADERS}
)

# Find libraries - first with discovered paths, then default search
find_library(GNUSTEP_BASE_LIBRARY
    NAMES gnustep-base
    HINTS ${_GNUSTEP_LIBRARY_SEARCH_PATHS}
)

find_library(GNUSTEP_GUI_LIBRARY
    NAMES gnustep-gui
    HINTS ${_GNUSTEP_LIBRARY_SEARCH_PATHS}
)

find_library(OBJC_LIBRARY
    NAMES objc
    HINTS ${_GNUSTEP_LIBRARY_SEARCH_PATHS}
)

# Find include directories
find_path(GNUSTEP_BASE_INCLUDE_DIR
    NAMES Foundation/Foundation.h
    HINTS ${_GNUSTEP_INCLUDE_SEARCH_PATHS}
    PATH_SUFFIXES GNUstep
)

find_path(GNUSTEP_GUI_INCLUDE_DIR
    NAMES AppKit/AppKit.h
    HINTS ${_GNUSTEP_INCLUDE_SEARCH_PATHS}
    PATH_SUFFIXES GNUstep
)

# Determine compile flags
set(GNUstep_CFLAGS "")
if(_GNUSTEP_BASE_CFLAGS)
    list(APPEND GNUstep_CFLAGS ${_GNUSTEP_BASE_CFLAGS})
elseif(_GNUSTEP_OBJC_FLAGS)
    separate_arguments(_GNUSTEP_OBJC_FLAGS_LIST UNIX_COMMAND "${_GNUSTEP_OBJC_FLAGS}")
    list(APPEND GNUstep_CFLAGS ${_GNUSTEP_OBJC_FLAGS_LIST})
endif()

# Handle standard find_package arguments
find_package_handle_standard_args(GNUstep
    REQUIRED_VARS
        GNUSTEP_BASE_LIBRARY
        GNUSTEP_GUI_LIBRARY
        GNUSTEP_BASE_INCLUDE_DIR
        GNUSTEP_GUI_INCLUDE_DIR
)

if(GNUstep_FOUND)
    set(GNUstep_INCLUDE_DIRS ${GNUSTEP_BASE_INCLUDE_DIR} ${GNUSTEP_GUI_INCLUDE_DIR})
    set(GNUstep_LIBRARIES ${GNUSTEP_GUI_LIBRARY} ${GNUSTEP_BASE_LIBRARY} ${OBJC_LIBRARY})

    # Create GNUstep::Base imported target
    if(NOT TARGET GNUstep::Base)
        add_library(GNUstep::Base UNKNOWN IMPORTED)
        set_target_properties(GNUstep::Base PROPERTIES
            IMPORTED_LOCATION "${GNUSTEP_BASE_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${GNUSTEP_BASE_INCLUDE_DIR}"
            INTERFACE_COMPILE_OPTIONS "${GNUstep_CFLAGS}"
            INTERFACE_COMPILE_DEFINITIONS "GNUSTEP=1"
        )
        if(OBJC_LIBRARY)
            set_property(TARGET GNUstep::Base APPEND PROPERTY
                INTERFACE_LINK_LIBRARIES "${OBJC_LIBRARY}"
            )
        endif()
        find_library(GNUSTEP_CURL_LIBRARY
            NAMES curl
            PATHS /usr/lib /usr/lib/${CMAKE_LIBRARY_ARCHITECTURE}
            NO_CMAKE_FIND_ROOT_PATH
            NO_CMAKE_ENVIRONMENT_PATH
            NO_CMAKE_PATH
            NO_SYSTEM_ENVIRONMENT_PATH
            NO_CMAKE_SYSTEM_PATH
        )
        if(GNUSTEP_CURL_LIBRARY)
            set_property(TARGET GNUstep::Base APPEND PROPERTY
                INTERFACE_LINK_LIBRARIES "${GNUSTEP_CURL_LIBRARY}"
            )
        endif()
        cmake_path(GET GNUSTEP_BASE_LIBRARY PARENT_PATH _GNUSTEP_BASE_LIB_DIR)
        set_property(TARGET GNUstep::Base APPEND PROPERTY
            INTERFACE_LINK_DIRECTORIES "${_GNUSTEP_BASE_LIB_DIR}"
        )
    endif()

    # Create GNUstep::GUI imported target
    if(NOT TARGET GNUstep::GUI)
        add_library(GNUstep::GUI UNKNOWN IMPORTED)
        set_target_properties(GNUstep::GUI PROPERTIES
            IMPORTED_LOCATION "${GNUSTEP_GUI_LIBRARY}"
            INTERFACE_INCLUDE_DIRECTORIES "${GNUSTEP_GUI_INCLUDE_DIR}"
        )
        set_property(TARGET GNUstep::GUI APPEND PROPERTY
            INTERFACE_LINK_LIBRARIES GNUstep::Base
        )
        cmake_path(GET GNUSTEP_GUI_LIBRARY PARENT_PATH _GNUSTEP_GUI_LIB_DIR)
        set_property(TARGET GNUstep::GUI APPEND PROPERTY
            INTERFACE_LINK_DIRECTORIES "${_GNUSTEP_GUI_LIB_DIR}"
        )
    endif()

    mark_as_advanced(
        GNUSTEP_BASE_LIBRARY
        GNUSTEP_GUI_LIBRARY
        GNUSTEP_BASE_INCLUDE_DIR
        GNUSTEP_GUI_INCLUDE_DIR
        GNUSTEP_CONFIG
        OBJC_LIBRARY
    )
endif()
