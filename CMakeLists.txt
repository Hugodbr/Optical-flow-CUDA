cmake_minimum_required(VERSION 3.18)
project(optical_flow LANGUAGES CXX CUDA)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CUDA_STANDARD 17)

include(cmake/platform.cmake)

add_compile_definitions(USE_CUDA)

# Pass via: cmake .. -DCUDA_ARCH_BIN=87
# Defaults to "native" which auto-detects the current GPU
if(NOT DEFINED CUDA_ARCH_BIN)
    set(CUDA_ARCH_BIN "native")
    message(STATUS "CUDA_ARCH_BIN not set — using 'native' (auto-detect)")
endif()

find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})

add_executable(optical_flow
    src/main.cpp
    src/cuda/lucas_kanade.cu
)

target_include_directories(optical_flow PRIVATE src ${CMAKE_CUDA_TOOLKIT_INCLUDE_DIRECTORIES})
target_link_libraries(optical_flow ${OpenCV_LIBS} cuda cudart)

set_target_properties(optical_flow PROPERTIES
    CUDA_ARCHITECTURES        ${CUDA_ARCH_BIN}
    CUDA_SEPARABLE_COMPILATION ON
)
