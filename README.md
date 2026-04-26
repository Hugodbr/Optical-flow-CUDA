# First install deps

bash scripts/install_deps.sh

bash scripts/build_opencv.sh

# On Ubuntu:

~/droidcam$ droidcam-cli adb 4747      # step for using android cam only

bash scripts/ubuntu/build.sh

bash scripts/ubuntu/run.sh 0

# On Jetson:

bash scripts/jetson/build.sh           # build (auto-detects arch)

bash scripts/jetson/run.sh             # run with onboard cam + max power

OPTICAL_FLOW_POWER_MODE=2 bash scripts/jetson/run.sh  # run at 15W mode
