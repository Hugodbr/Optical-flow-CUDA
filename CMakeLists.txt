cmake_minimum_required(VERSION 3.18)
project(optical_flow LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Include platform detection
include(cmake/platform.cmake)

# Optional CUDA
include(CheckLanguage)
check_language(CUDA)
if(CMAKE_CUDA_COMPILER)
    enable_language(CUDA)
    set(CMAKE_CUDA_STANDARD 17)
    add_compile_definitions(USE_CUDA)
    message(STATUS "CUDA found — GPU path enabled")
else()
    message(WARNING "CUDA not found — CPU-only mode")
endif()

find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})

# Collect sources
set(SOURCES
    src/main.cpp
    src/camera/CameraCapture.cpp
)

add_executable(optical_flow ${SOURCES})
target_include_directories(optical_flow PRIVATE src)
target_link_libraries(optical_flow ${OpenCV_LIBS})

# Test binary
add_executable(test_grayscale test/test_grayscale.cpp src/camera/CameraCapture.cpp)
target_include_directories(test_grayscale PRIVATE src)
target_link_libraries(test_grayscale ${OpenCV_LIBS})