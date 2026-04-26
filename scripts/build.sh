#!/bin/bash
set -e

BUILD_DIR="build"
BUILD_TYPE="${1:-Release}"   # pass Debug as first arg if needed

echo "=== Building optical_flow [${BUILD_TYPE}] ==="

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

cmake .. \
    -DCMAKE_BUILD_TYPE=${BUILD_TYPE} \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON   # for IDEs / clangd

make -j$(nproc)

echo ""
echo "=== Build complete. Binaries in ./${BUILD_DIR}/ ==="
echo "  ./build/optical_flow --help"
echo "  ./build/optical_flow --list"
echo "  ./build/optical_flow --camera 0"
echo "  ./build/optical_flow --camera http://192.168.1.X:4747/video"