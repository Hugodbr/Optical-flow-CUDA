#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

echo "=== Ubuntu build ==="
echo "    GPU:       RTX 4060 Ti (Ada Lovelace)"
echo "    CUDA arch: 8.9"
echo "    Camera:    Droidcam (WiFi) or built-in"
echo ""

# Platform-specific settings
export CUDA_ARCH="89"
export OPENCV_DIR="/usr/local/lib/cmake/opencv4"
export BUILD_TYPE="${1:-Release}"

bash scripts/common/build_core.sh

echo ""
echo "=== Run options ==="
echo "  Droidcam (WiFi):  bash scripts/ubuntu/run.sh"
echo "  Built-in camera:  ./build/optical_flow --camera 0"
echo "  USB camera:       ./build/optical_flow --camera 1"