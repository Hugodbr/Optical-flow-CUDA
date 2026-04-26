cmake_minimum_required(VERSION 3.18)
project(optical_flow LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(cmake/platform.cmake)

# ── CUDA detection ────────────────────────────────────────────────────────────
include(CheckLanguage)
check_language(CUDA)

if(CMAKE_CUDA_COMPILER)
    enable_language(CUDA)
    set(CMAKE_CUDA_STANDARD 17)
    add_compile_definitions(USE_CUDA)
    message(STATUS "CUDA found — GPU path enabled")

    # CUDA_ARCH_BIN can be passed via: cmake .. -DCUDA_ARCH_BIN=87
    # Defaults to "native" which auto-detects the current GPU
    if(NOT DEFINED CUDA_ARCH_BIN)
        set(CUDA_ARCH_BIN "native")
        message(STATUS "CUDA_ARCH_BIN not set — using 'native' (auto-detect)")
    endif()

    set(CUDA_SOURCES src/cuda/lucas_kanade.cu)
else()
    message(WARNING "CUDA not found — CPU-only mode, lucas_kanade.cu will not be compiled")
    set(CUDA_SOURCES "")
endif()

# ── OpenCV ────────────────────────────────────────────────────────────────────
find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})

# ── Main binary ───────────────────────────────────────────────────────────────
set(SOURCES
    src/main.cpp
    src/camera/CameraCapture.cpp
    ${CUDA_SOURCES}              # Empty string if no CUDA — safe
)

add_executable(optical_flow ${SOURCES})
target_include_directories(optical_flow PRIVATE src)
target_link_libraries(optical_flow ${OpenCV_LIBS})

if(CMAKE_CUDA_COMPILER)
    # This is the line that was missing — tells nvcc which GPU arch to target
    set_target_properties(optical_flow PROPERTIES
        CUDA_ARCHITECTURES ${CUDA_ARCH_BIN}
        CUDA_SEPARABLE_COMPILATION ON
    )
    target_link_libraries(optical_flow cuda cudart)
endif()

# ── Test binary ───────────────────────────────────────────────────────────────
add_executable(test_grayscale
    test/test_grayscale.cpp
    src/camera/CameraCapture.cpp
)
target_include_directories(test_grayscale PRIVATE src)
target_link_libraries(test_grayscale ${OpenCV_LIBS})