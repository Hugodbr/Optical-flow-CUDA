#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

BINARY="./build/optical_flow"
CONFIG="config/camera_ubuntu.yaml"

if [ ! -f "${BINARY}" ]; then
    echo "ERROR: binary not found. Run scripts/ubuntu/build.sh first."
    exit 1
fi

# Allow overriding camera source at runtime:
#   bash scripts/ubuntu/run.sh 0              → built-in cam
#   bash scripts/ubuntu/run.sh http://...     → custom Droidcam IP
#   bash scripts/ubuntu/run.sh               → reads camera_ubuntu.yaml

if [ -n "$1" ]; then
    echo "=== Using camera override: $1 ==="
    ${BINARY} --camera "$1"
else
    echo "=== Using config: ${CONFIG} ==="
    # Print the active source so the user knows what's being used
    grep "source:" ${CONFIG} | head -1
    echo ""
    ${BINARY} --config "${CONFIG}"
fi