# First install deps

1) bash scripts/install_deps.sh

2) bash scripts/build_opencv.sh

# On linux:

3) bash scripts/linux/build.sh

4) bash scripts/linux/run.sh 0         # gets camera 0

# On Jetson:

bash scripts/jetson/build.sh           # build (auto-detects arch)

bash scripts/jetson/run.sh             # run with onboard cam + max power

OPTICAL_FLOW_POWER_MODE=2 bash scripts/jetson/run.sh  # run at 15W mode

# For android camera 

~/droidcam$ droidcam-cli adb 4747      # step for using android cam only