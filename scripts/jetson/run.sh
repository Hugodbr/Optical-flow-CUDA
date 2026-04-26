#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${PROJECT_ROOT}"

BINARY="./build/optical_flow"
CONFIG="config/camera_jetson.yaml"
POWER_MODE="${OPTICAL_FLOW_POWER_MODE:-0}"   # default max performance

if [ ! -f "${BINARY}" ]; then
    echo "ERROR: binary not found. Run scripts/jetson/build.sh first."
    exit 1
fi

# Set power mode before running (can override via env var)
echo "=== Setting Jetson power mode: ${POWER_MODE} ==="
bash scripts/jetson/set_power_mode.sh ${POWER_MODE}

if [ -n "$1" ]; then
    echo "=== Using camera override: $1 ==="
    ${BINARY} --camera "$1"
else
    echo "=== Using config: ${CONFIG} ==="
    grep "source:" ${CONFIG} | head -1
    echo ""
    ${BINARY} --config "${CONFIG}"
fi