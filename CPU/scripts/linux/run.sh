#!/bin/bash
# run.sh — Run script for CPU optical flow
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

BINARY="./build_cpu/optical_flow_cpu"
CONFIG="config/camera_ubuntu.yaml"

if [ ! -f "${BINARY}" ]; then
    echo "ERROR: binary not found at ${BINARY}"
    echo "Run ./scripts/linux/build.sh first"
    exit 1
fi

echo "=========================================="
echo "  Optical Flow (CPU)"
echo "=========================================="
echo ""

# Allow overriding camera source at runtime:
#   bash scripts/linux/run.sh 0              → built-in cam
#   bash scripts/linux/run.sh http://...     → custom IP cam
#   bash scripts/linux/run.sh                → reads camera_ubuntu.yaml

if [ -n "$1" ]; then
    echo "[*] Using camera override: $1"
    echo ""
    ${BINARY} --camera "$1"
else
    echo "[*] Using config: ${CONFIG}"
    echo ""
    # Print the active source so the user knows what's being used
    if [ -f "${CONFIG}" ]; then
        echo "Configuration:"
        grep -E "source:|width:|height:|fps:" "${CONFIG}" 2>/dev/null || echo "  (default config)"
    fi
    echo ""
    ${BINARY} --config "${CONFIG}"
fi
