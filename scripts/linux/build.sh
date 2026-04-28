#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

# Platform-specific settings
export CUDA_ARCH="89"
export OPENCV_DIR="/usr/local/lib/cmake/opencv4"
export BUILD_TYPE="${1:-Release}"

bash scripts/common/build_core.sh