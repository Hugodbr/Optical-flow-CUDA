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

# Benchmark GPU vs CPU

Use the root benchmark script to compare both implementations sequentially with the same video input:

```bash
python3 benchmark.py --runs 3 --seconds 10
```

This generates:

- `resultados.csv` (summary stats)
- `frames.csv` (per-frame timing data)
- `plots/fps_comparison.png`
- `plots/total_time_comparison.png`
- `plots/frame_times.png` (real-time performance analysis)

The `frame_times.png` plot shows processing time per frame over time, with a red line at 33.3ms (30 FPS real-time limit). GPU should stay below the line, CPU may exceed it.

Example expected plot:
- X-axis: Frame ID (1, 2, 3, ...)
- Y-axis: Time per frame (ms)
- Blue line: GPU processing times (fast, stable)
- Orange line: CPU processing times (slower, variable)
- Red dashed line: 33.3ms real-time threshold
