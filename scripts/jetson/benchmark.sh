#!/bin/bash
# Runs optical_flow for N seconds per power mode and logs FPS.
# Requires: optical_flow binary built, camera connected.

BINARY="./build/optical_flow"
CAMERA="${1:-0}"
DURATION=30   # seconds per mode
LOG="docs/benchmark_results.csv"

echo "mode,fps_avg" > ${LOG}

for MODE in 0 1 2 3; do
    echo "=== Testing power mode ${MODE} ==="
    ./scripts/jetson/set_power_mode.sh ${MODE}
    sleep 2

    # Run for DURATION seconds, grab FPS from stdout (optical_flow should print it)
    FPS=$(timeout ${DURATION} ${BINARY} --camera ${CAMERA} 2>/dev/null \
          | grep -oP "FPS: \K[\d.]+" | tail -20 | awk '{s+=$1; n++} END {print s/n}')

    echo "${MODE},${FPS}" >> ${LOG}
    echo "  Mode ${MODE}: avg FPS = ${FPS}"
done

echo ""
echo "Results saved to ${LOG}"