# Detect GNUstep vs macOS
# LADYBIRD_USE_GNUSTEP is set early in lagom_options.cmake
if(APPLE)
    set(LADYBIRD_GNUSTEP OFF)
elseif(LADYBIRD_USE_GNUSTEP)
    set(LADYBIRD_GNUSTEP ON)
    # Re-run pkg_check_modules to get include dirs and libraries
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(GNUSTEP REQUIRED gnustep-base gnustep-gui)
else()
    message(FATAL_ERROR "GNUstep not found. Please install gnustep-base and gnustep-gui.")
endif()

add_library(ladybird_impl STATIC
    Application/Application.mm
    Application/ApplicationDelegate.mm
    Application/EventLoopImplementationMacOS.mm
    Interface/Autocomplete.mm
    Interface/Event.mm
    Interface/InfoBar.mm
    Interface/LadybirdWebView.mm
    Interface/LadybirdWebViewBridge.cpp
    Interface/LadybirdWebViewWindow.mm
    Interface/Menu.mm
    Interface/Palette.mm
    Interface/SearchPanel.mm
    Interface/Tab.mm
    Interface/TabController.mm
    Utilities/Conversions.mm
)
target_include_directories(ladybird_impl PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>)

target_compile_options(ladybird_impl PUBLIC
        $<$<COMPILE_LANGUAGE:CXX>:-fobjc-arc>
        $<$<COMPILE_LANGUAGE:CXX>:-Wno-deprecated-anon-enum-enum-conversion> # Required for CGImageCreate
)
target_compile_features(ladybird_impl PUBLIC cxx_std_23)

if(LADYBIRD_GNUSTEP)
    # GNUstep build configuration
    # GNUSTEP_CFLAGS includes critical flags like -fobjc-runtime=gnustep-2.x for ARC support
    target_compile_definitions(ladybird_impl PUBLIC GNUSTEP=1)
    target_include_directories(ladybird_impl PUBLIC ${GNUSTEP_INCLUDE_DIRS})
    separate_arguments(GNUSTEP_CFLAGS_LIST UNIX_COMMAND "${GNUSTEP_CFLAGS}")
    target_compile_options(ladybird_impl PUBLIC ${GNUSTEP_CFLAGS_LIST})
    # Suppress warnings from GNUstep system headers (e.g., unused parameter in NSZone.h)
    target_compile_options(ladybird_impl PUBLIC -Wno-unused-parameter)
    target_link_libraries(ladybird_impl PUBLIC ${GNUSTEP_LIBRARIES} LibUnicode)

    add_executable(ladybird
        main.mm
    )
    # create_ladybird_bundle handles resource file copying for non-Apple platforms
    create_ladybird_bundle(ladybird)
else()
    # macOS build configuration
    add_executable(ladybird MACOSX_BUNDLE
        main.mm
    )
    target_link_libraries(ladybird_impl PUBLIC "-framework Cocoa -framework UniformTypeIdentifiers" LibUnicode)
    create_ladybird_bundle(ladybird)
endif()

target_link_libraries(ladybird PRIVATE ladybird_impl)
