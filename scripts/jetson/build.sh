#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

# Detect Jetson model and set arch automatically
detect_jetson_arch() {
    if [ -f /proc/device-tree/model ]; then
        MODEL=$(cat /proc/device-tree/model 2>/dev/null)
        echo "    Detected: ${MODEL}" >&2
        case "$MODEL" in
            *"Orin"*)   echo "87" ;;   # Orin NX / AGX Orin
            *"Xavier"*) echo "72" ;;   # Xavier NX / AGX Xavier
            *"Nano"*)   echo "53" ;;   # Jetson Nano
            *)          echo "87" ;;   # fallback to Orin
        esac
    else
        echo "87"  # default if detection fails
    fi
}

echo "=== Jetson build ==="
ARCH=$(detect_jetson_arch)
echo "    CUDA arch: ${ARCH}"
echo "    Camera:    onboard (CSI/USB)"
echo ""

export CUDA_ARCH="${ARCH}"
export BUILD_TYPE="${1:-Release}"

# Prefer a from-source build; fall back to the JetPack system install
for candidate in \
    "/usr/local/lib/cmake/opencv4" \
    "/usr/lib/aarch64-linux-gnu/cmake/opencv4" \
    "/usr/lib/cmake/opencv4"
do
    if [ -f "${candidate}/OpenCVConfig.cmake" ]; then
        export OPENCV_DIR="${candidate}"
        break
    fi
done

if [ -z "${OPENCV_DIR}" ]; then
    echo "ERROR: OpenCV CMake config not found. Install OpenCV with CUDA support."
    exit 1
fi
echo "    OpenCV:    ${OPENCV_DIR}"

bash scripts/common/build_core.sh

echo ""
echo "=== Run options ==="
echo "  Video:  bash scripts/jetson/run.sh input.mp4 output.avi"