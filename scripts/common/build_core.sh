#!/bin/bash
# Called by platform scripts — not meant to be run directly.
# Expects these env vars to be set by the caller:
#   CUDA_ARCH        e.g. "89" or "87"
#   OPENCV_DIR       e.g. "/usr/local/lib/cmake/opencv4"
#   BUILD_TYPE       e.g. "Release" or "Debug"

set -e

BUILD_DIR="build"

# ── Validate required vars ────────────────────────────────────────────────────
if [ -z "$CUDA_ARCH" ]; then
    echo "ERROR: CUDA_ARCH not set. Call this from a platform script."
    exit 1
fi

# ── Verify OpenCV CUDA is installed ──────────────────────────────────────────
if ! ls /usr/local/lib/libopencv_cuda* 1>/dev/null 2>&1; then
    echo "ERROR: OpenCV CUDA libraries not found."
    echo "  Run scripts/build_opencv.sh first."
    exit 1
fi
echo "  OpenCV CUDA libraries found ✓"

# ── CMake + Make ──────────────────────────────────────────────────────────────
echo ""
echo "=== Building optical_flow [arch=${CUDA_ARCH}, type=${BUILD_TYPE}] ==="
mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR}

cmake .. \
    -D CMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -D CMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -D OpenCV_DIR=${OPENCV_DIR} \
    -D CUDA_ARCH_BIN=${CUDA_ARCH}

make -j$(nproc)

echo ""
echo "=== Build complete. Binary at ./build/optical_flow ==="