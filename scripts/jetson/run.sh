#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

BINARY="./build/optical_flow"

if [ ! -f "${BINARY}" ]; then
    echo "ERROR: binary not found. Run scripts/jetson/build.sh first."
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: bash scripts/jetson/run.sh <input_video> [output_video]"
    echo "  Example: bash scripts/jetson/run.sh input.mp4 output.avi"
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-output.avi}"

# echo "=== Setting Jetson power mode: max performance ==="
# bash scripts/jetson/set_power_mode.sh 0

echo ""
echo "=== Lucas-Kanade optical flow (CUDA) ==="
echo "  Input:  ${INPUT}"
echo "  Output: ${OUTPUT}"
echo ""

${BINARY} --input "${INPUT}" --output "${OUTPUT}"
