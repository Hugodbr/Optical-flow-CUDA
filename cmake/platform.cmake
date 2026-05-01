if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
    message(FATAL_ERROR "This branch targets NVIDIA Jetson (Linux only).")
endif()

if(EXISTS "/proc/version")
    file(READ "/proc/version" PROC_VERSION)
    if(NOT (PROC_VERSION MATCHES "tegra" OR PROC_VERSION MATCHES "Tegra"))
        message(WARNING "Not detected as a Jetson — proceeding anyway.")
    endif()
endif()

add_compile_definitions(PLATFORM_JETSON)
message(STATUS "Platform: NVIDIA Jetson")
