#!/bin/bash
# build.sh — Build script for CPU optical flow
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

BUILD_DIR="build_cpu"
BUILD_TYPE="${1:-Release}"

echo "=========================================="
echo "  Building Optical Flow (CPU)"
echo "=========================================="
echo "Build type: ${BUILD_TYPE}"
echo "Build directory: ${BUILD_DIR}"
echo ""

# Clean previous build if requested
if [ "${2}" = "clean" ]; then
    echo "[*] Cleaning previous build..."
    rm -rf "${BUILD_DIR}"
fi

# Create build directory
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Configure and build
echo "[*] Configuring CMake..."
cmake .. -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

echo "[*] Building..."
cmake --build . --config "${BUILD_TYPE}" -j$(nproc)

echo ""
echo "=========================================="
echo "  Build complete!"
echo "=========================================="
echo "Binary: ${PROJECT_ROOT}/${BUILD_DIR}/optical_flow_cpu"
echo ""
