#!/bin/bash
set -e

# ── Check if already installed ────────────────────────────────────────────────
if ls /usr/local/lib/libopencv_cuda* 1>/dev/null 2>&1; then
    echo "=== OpenCV with CUDA already installed — skipping. ==="
    echo "    Delete /usr/local/lib/libopencv_* to force a rebuild."
    exit 0
fi

# ── Clone if needed ───────────────────────────────────────────────────────────
OPENCV_VERSION="4.10.0"

if [ ! -d ~/opencv ]; then
    echo "=== Cloning OpenCV ${OPENCV_VERSION} ==="
    git clone --branch ${OPENCV_VERSION} --depth 1 \
        https://github.com/opencv/opencv.git ~/opencv
else
    echo "=== ~/opencv already exists — skipping clone ==="
fi

if [ ! -d ~/opencv_contrib ]; then
    echo "=== Cloning opencv_contrib ${OPENCV_VERSION} ==="
    git clone --branch ${OPENCV_VERSION} --depth 1 \
        https://github.com/opencv/opencv_contrib.git ~/opencv_contrib
else
    echo "=== ~/opencv_contrib already exists — skipping clone ==="
fi

# ── Configure ─────────────────────────────────────────────────────────────────
mkdir -p ~/opencv/build && cd ~/opencv/build

echo "=== Configuring OpenCV with CUDA ==="
cmake ~/opencv \
    -D CMAKE_BUILD_TYPE=RELEASE \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D OPENCV_EXTRA_MODULES_PATH=~/opencv_contrib/modules \
    -D WITH_CUDA=ON \
    -D CUDA_ARCH_BIN="8.9" \
    -D WITH_CUDNN=OFF \
    -D OPENCV_DNN_CUDA=OFF \
    -D ENABLE_FAST_MATH=ON \
    -D WITH_GSTREAMER=ON \
    -D WITH_V4L=ON \
    -D BUILD_opencv_python3=ON \
    -D PYTHON3_EXECUTABLE=$(which python3) \
    -D BUILD_EXAMPLES=OFF \
    -D BUILD_TESTS=OFF

# ── Verify CUDA is in the cache before spending 40 min compiling ──────────────
echo ""
echo "=== Verifying CUDA in CMakeCache ==="
if ! grep -q "WITH_CUDA:BOOL=ON" ~/opencv/build/CMakeCache.txt; then
    echo "ERROR: CUDA not enabled in CMakeCache."
    echo "  nvcc path: $(which nvcc 2>/dev/null || echo 'NOT FOUND')"
    echo "  If nvcc is missing, add to ~/.bashrc:"
    echo "    export PATH=/usr/local/cuda/bin:\$PATH"
    echo "    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH"
    exit 1
fi
echo "  CUDA enabled ✓"

# ── Compile ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Compiling OpenCV (this takes 20-40 min) ==="
make -j$(nproc)
sudo make install
sudo ldconfig

# ── Final verification ────────────────────────────────────────────────────────
echo ""
echo "=== Verifying installation ==="
python3 -c "
import cv2
info = cv2.getBuildInformation()
for line in info.splitlines():
    if any(k in line for k in ['CUDA', 'cuDNN', 'GStreamer', 'V4L']):
        print(line)
"
ls /usr/local/lib/libopencv_cuda* | head -3
echo ""
echo "=== OpenCV with CUDA installed successfully ==="