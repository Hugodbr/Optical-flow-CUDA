#!/bin/bash
# Usage: ./scripts/jetson/set_power_mode.sh <mode>
# Run 'sudo nvpmodel --query' to see modes available on your board.
#
# Common Jetson Orin modes:
#   0 = MAXN (max performance)
#   1 = 10W
#   2 = 15W
#   3 = 30W
#   4 = 50W

MODE=${1:-0}

echo "Setting Jetson power mode to: $MODE"
sudo nvpmodel -m ${MODE}
sudo jetson_clocks     # pin clocks at max for this mode

echo "Current mode:"
sudo nvpmodel --query