#!/bin/bash
# Usage: ./set_power_mode.sh [0|1|2]
# 0 = Max performance, higher modes = lower power
sudo nvpmodel -m $1
sudo jetson_clocks   # pin clocks at max for current mode
echo "Power mode set to $1"