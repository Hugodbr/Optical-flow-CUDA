# 🚀 Quick Start Guide — CPU Optical Flow

## 30-Second Setup

```bash
# 1. Enter the CPU directory
cd CPU

# 2. Make scripts executable
chmod +x scripts/linux/*.sh

# 3. Build
bash scripts/linux/build.sh

# 4. Run
bash scripts/linux/run.sh 0
```

**Done!** Press `q` to quit.

---

## Detailed Steps

### Prerequisites Check

Make sure you have:
- **C++17 compiler** (g++, clang)
- **OpenCV** (`pkg-config --modversion opencv4`)
- **OpenMP** (usually comes with compiler)
- **CMake 3.18+** (`cmake --version`)
- **Camera** or video file

### Installation (if missing dependencies)

**Ubuntu/Debian:**
```bash
sudo apt-get install build-essential cmake libopencv-dev libomp-dev
```

**Fedora:**
```bash
sudo dnf install gcc-c++ cmake opencv-devel libomp-devel
```

**macOS:**
```bash
brew install cmake opencv libomp
```

### Build

```bash
cd CPU
chmod +x scripts/linux/*.sh
bash scripts/linux/build.sh Release
```

**Expected output:**
```
==========================================
  Building Optical Flow (CPU)
==========================================
[*] Configuring CMake...
[*] Building...
==========================================
  Build complete!
==========================================
Binary: .../build_cpu/optical_flow_cpu
```

### Run

#### Default camera
```bash
bash scripts/linux/run.sh
```

#### Specific camera
```bash
bash scripts/linux/run.sh 0      # /dev/video0
bash scripts/linux/run.sh 1      # /dev/video1
```

#### List cameras
```bash
./build_cpu/optical_flow_cpu --list
```

#### Video file
```bash
./build_cpu/optical_flow_cpu --camera video.mp4
```

#### IP camera (Droidcam)
```bash
bash scripts/linux/run.sh "http://192.168.1.100:4747/video"
```

#### Grayscale fallback mode
```bash
./build_cpu/optical_flow_cpu --grayscale
```

---

## What You'll See

1. **Video window** with live camera feed
2. **Colored arrows** showing motion direction/speed
3. **FPS counter** (top-left corner)
4. **Algorithm name** (Lucas-Kanade CPU)
5. **Press `q` or `ESC`** to exit

### Color Meaning

- **Red/Orange** — Rightward motion
- **Green** — Downward-right motion
- **Blue** — Leftward motion
- **Bright** — Fast motion
- **Dark** — Slow motion

---

## Performance Tips

### If too slow:

1. **Lower resolution** in `config/camera_ubuntu.yaml`:
   ```yaml
   width:  640
   height: 480
   ```

2. **Use smaller window** in `CPU/src/main.cpp`:
   ```cpp
   LKConfig lkCfg;
   lkCfg.windowSize = 5;  // Instead of 7
   ```

3. **Switch to grayscale** (for baseline):
   ```bash
   ./build_cpu/optical_flow_cpu --grayscale
   ```

### If want better quality:

1. **Increase window size** (slower but more accurate)
2. **Higher resolution** (more detail)
3. **Check CPU usage** — ensure other apps aren't hogging CPU

---

## Troubleshooting

### Build fails

```bash
# Check OpenCV
pkg-config --modversion opencv4

# Check CMake
cmake --version

# Try verbose build
cd build_cpu && cmake -DCMAKE_VERBOSE_MAKEFILE=ON ..
```

### Camera not found

```bash
# List available cameras
./build_cpu/optical_flow_cpu --list

# Try different device
./build_cpu/optical_flow_cpu --camera 1
```

### Low FPS

- Reduce resolution (see Performance Tips)
- Check CPU usage: `top` or `htop`
- Close other applications

---

## Next Steps

1. **Explore parameters** in `CPU/src/main.cpp`:
   - `windowSize` — affects accuracy and speed
   - `detThreshold` — confidence threshold for flow

2. **Customize camera config** in `CPU/config/camera_ubuntu.yaml`

3. **Review algorithm** in `CPU/docs/CHANGES.md` for technical details

4. **Compare with GPU version** for performance differences

---

## File Locations

```
CPU/
├── build_cpu/optical_flow_cpu    ← The executable (binary)
├── config/
│   └── camera_ubuntu.yaml        ← Camera settings
├── src/
│   ├── main.cpp                  ← Entry point
│   ├── optical_flow/
│   │   └── lucas_kanade.cpp      ← Algorithm core
│   └── camera/
│       └── CameraCapture.cpp     ← Camera driver
└── scripts/linux/
    ├── build.sh                  ← Build script
    └── run.sh                    ← Run script
```

---

## Full Documentation

For more details, see:
- **`docs/README.md`** — Comprehensive guide
- **`docs/CHANGES.md`** — Technical changes from GPU version

---

**Ready to use!** 🎉
