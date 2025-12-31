include_guard()

# Vulkan is used for GPU-accelerated Skia rendering on non-Apple platforms
# Skip Vulkan for GNUstep builds (detected early in lagom_options.cmake)
if (NOT APPLE AND NOT LADYBIRD_USE_GNUSTEP)
    find_package(VulkanHeaders CONFIG QUIET)
    find_package(Vulkan QUIET)
    if (VulkanHeaders_FOUND AND Vulkan_FOUND)
        set(HAS_VULKAN ON CACHE BOOL "" FORCE)
        add_cxx_compile_definitions(USE_VULKAN=1)
    endif()
endif()
