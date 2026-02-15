# UI/GNUstep CMakeLists.txt
# Standalone UI implementation for Ladybird browser - no shared sources from AppKit

# Find GNUstep using our custom Find module
find_package(GNUstep REQUIRED)

set(LADYBIRD_GNUSTEP_SOURCES
    # Application
    Application/Application.mm
    Application/ApplicationDelegate.mm
    Application/EventLoopImplementationGNUstep.mm

    # Interface
    Interface/Autocomplete.mm
    Interface/BrowserTab.mm
    Interface/BrowserToolbar.mm
    Interface/Event.mm
    Interface/GNUstepBrowserWindow.mm
    Interface/InfoBar.mm
    Interface/LadybirdWebView.mm
    Interface/LadybirdWebViewBridge.cpp
    Interface/Menu.mm
    Interface/Palette.mm
    Interface/SearchPanel.mm

    # Utilities
    Utilities/Conversions.mm
)

add_library(ladybird_impl STATIC
    ${LADYBIRD_GNUSTEP_SOURCES}
)

target_include_directories(ladybird_impl PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
)

target_compile_options(ladybird_impl PUBLIC
    $<$<COMPILE_LANGUAGE:CXX>:-fobjc-arc>
    $<$<COMPILE_LANGUAGE:CXX>:-Wno-unused-parameter>
)

target_compile_features(ladybird_impl PUBLIC cxx_std_23)

# Use GNUstep imported targets
target_link_libraries(ladybird_impl PUBLIC
    GNUstep::GUI
    GNUstep::Base
    LibUnicode
    BlocksRuntime
    dispatch
)

# Define GNUSTEP for preprocessor
target_compile_definitions(ladybird_impl PUBLIC GNUSTEP=1)

# Create the ladybird executable
add_executable(ladybird
    main.mm
)

target_link_libraries(ladybird PRIVATE ladybird_impl)

# Use the bundle creation function from the parent CMakeLists.txt
create_ladybird_bundle(ladybird)
