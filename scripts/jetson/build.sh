#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

# Detect Jetson model and set arch automatically
detect_jetson_arch() {
    if [ -f /proc/device-tree/model ]; then
        MODEL=$(cat /proc/device-tree/model 2>/dev/null)
        echo "    Detected: ${MODEL}"
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
export OPENCV_DIR="/usr/local/lib/cmake/opencv4"
export BUILD_TYPE="${1:-Release}"

bash scripts/common/build_core.sh

echo ""
echo "=== Run options ==="
echo "  Onboard cam:  bash scripts/jetson/run.sh"
echo "  USB cam:      ./build/optical_flow --camera 1"