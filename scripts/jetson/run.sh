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
    echo "Usage: bash scripts/jetson/run.sh <input_video> [output_video] [log_file]"
    echo "  Example: bash scripts/jetson/run.sh input.mp4 output.avi optical_flow.log"
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-output.avi}"
LOG="${3:-optical_flow.log}"

# Capture current Jetson power mode (requires sudo)
POWER_MODE="unknown"
if command -v nvpmodel &>/dev/null; then
    NVP_OUT=$(sudo nvpmodel -q 2>/dev/null || true)
    MODE_NAME=$(echo "${NVP_OUT}" | grep "NV Power Mode" | sed 's/NV Power Mode: //' | tr -d '[:space:]')
    MODE_NUM=$(echo "${NVP_OUT}"  | tail -1 | tr -d '[:space:]')
    if [ -n "${MODE_NAME}" ]; then
        POWER_MODE="${MODE_NAME} (mode ${MODE_NUM})"
    fi
fi

echo ""
echo "=== Lucas-Kanade optical flow (CUDA) ==="
echo "  Input:      ${INPUT}"
echo "  Output:     ${OUTPUT}"
echo "  Log:        ${LOG}"
echo "  Power mode: ${POWER_MODE}"
echo ""

${BINARY} \
    --input      "${INPUT}"      \
    --output     "${OUTPUT}"     \
    --log        "${LOG}"        \
    --power-mode "${POWER_MODE}"
