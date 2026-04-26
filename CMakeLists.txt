cmake_minimum_required(VERSION 3.18)
project(optical_flow LANGUAGES CXX)

# Only add CUDA language if actually available
include(CheckLanguage)
check_language(CUDA)
if(CMAKE_CUDA_COMPILER)
    enable_language(CUDA)
    set(CMAKE_CUDA_STANDARD 17)
    add_compile_definitions(USE_CUDA)
    message(STATUS "CUDA found — GPU path enabled")
else()
    message(WARNING "CUDA not found — running CPU-only mode")
endif()

set(CMAKE_CXX_STANDARD 17)

find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})

add_executable(camera_test src/main.cpp src/camera/CameraCapture.cpp)
target_link_libraries(camera_test ${OpenCV_LIBS})

# Windows-specific: link against DirectShow if needed
if(WIN32)
    target_link_libraries(camera_test strmiids ole32 oleaut32)
endif()