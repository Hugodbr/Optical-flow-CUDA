cmake_minimum_required(VERSION 3.18)
project(optical_flow_cpu LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Optional: Enable OpenMP for parallelization
find_package(OpenMP REQUIRED)

# ── OpenCV (CPU-only) ─────────────────────────────────────────────────────────
find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})

message(STATUS "OpenCV version: ${OpenCV_VERSION}")
message(STATUS "OpenCV libraries: ${OpenCV_LIBS}")

# ── Main binary ───────────────────────────────────────────────────────────────
set(SOURCES
    src/main.cpp
    src/camera/CameraCapture.cpp
    src/optical_flow/lucas_kanade.cpp
)

add_executable(optical_flow_cpu ${SOURCES})
target_include_directories(optical_flow_cpu PRIVATE src)
target_link_libraries(optical_flow_cpu 
    ${OpenCV_LIBS}
    OpenMP::OpenMP_CXX
)

message(STATUS "Build configured successfully (CPU-only, no CUDA)")
