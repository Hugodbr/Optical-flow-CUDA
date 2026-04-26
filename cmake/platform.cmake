# Detect platform and set relevant flags/messages

if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    # Check if running on a Jetson by looking for tegra in /proc/version
    if(EXISTS "/proc/version")
        file(READ "/proc/version" PROC_VERSION)
        if(PROC_VERSION MATCHES "tegra" OR PROC_VERSION MATCHES "Tegra")
            set(PLATFORM_JETSON TRUE)
            message(STATUS "Platform: NVIDIA Jetson")
            add_compile_definitions(PLATFORM_JETSON)
        else()
            set(PLATFORM_UBUNTU TRUE)
            message(STATUS "Platform: Ubuntu / Linux PC")
            add_compile_definitions(PLATFORM_UBUNTU)
        endif()
    endif()
elseif(CMAKE_SYSTEM_NAME STREQUAL "Windows")
    message(FATAL_ERROR "Windows is not a supported platform for this project.")
endif()