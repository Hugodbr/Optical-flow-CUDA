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

# ── Verify OpenCV has CUDA support (cv::cuda::GpuMat must be available) ──────
# libopencv_cuda* does not exist as a separate file on JetPack installs —
# GpuMat lives inside libopencv_core when built with CUDA.
CUDA_IN_OPENCV=$(python3 -c "import cv2; info=cv2.getBuildInformation(); print('YES' if 'CUDA' in info and 'YES' in info[info.find('CUDA'):info.find('CUDA')+60] else 'NO')" 2>/dev/null || echo "NO")
if [ "${CUDA_IN_OPENCV}" != "YES" ]; then
    echo "ERROR: OpenCV was not built with CUDA support."
    echo "  The apt package does not include CUDA. Build from source:"
    echo "    export CUDA_ARCH_BIN=87"
    echo "    bash scripts/install_opencv.sh"
    exit 1
fi
echo "  OpenCV CUDA support found ✓"

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