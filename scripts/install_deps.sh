#!/bin/bash
set -e

OPENCV_VERSION="4.9.0"
CUDA_ARCH="${CUDA_ARCH_BIN:-}"  # e.g. export CUDA_ARCH_BIN=8.7 before running on Jetson

echo "=== Installing system dependencies ==="
sudo apt update
sudo apt install -y \
    build-essential cmake git pkg-config python3-pip python3-dev python3-venv \
    libgtk-3-dev libavcodec-dev libavformat-dev libswscale-dev \
    libv4l-dev v4l-utils libjpeg-dev libpng-dev libtiff-dev \
    gstreamer1.0-tools gstreamer1.0-plugins-good \
    python3-opencv    # fast Python OpenCV for test_camera.py

echo ""
echo "=== Building OpenCV ${OPENCV_VERSION} from source ==="

cd ~ && git clone --branch ${OPENCV_VERSION} --depth 1 \
    https://github.com/opencv/opencv.git
git clone --branch ${OPENCV_VERSION} --depth 1 \
    https://github.com/opencv/opencv_contrib.git

mkdir -p opencv/build && cd opencv/build

# Build args — CUDA is optional
CUDA_ARGS=""
if [ -n "$CUDA_ARCH" ]; then
    CUDA_ARGS="-D WITH_CUDA=ON -D CUDA_ARCH_BIN=${CUDA_ARCH} -D WITH_CUDNN=ON -D OPENCV_DNN_CUDA=ON"
    echo "CUDA enabled for arch: ${CUDA_ARCH}"
else
    echo "CUDA disabled (set CUDA_ARCH_BIN env var to enable)"
fi

cmake .. \
    -D CMAKE_BUILD_TYPE=RELEASE \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D OPENCV_EXTRA_MODULES_PATH=~/opencv_contrib/modules \
    -D WITH_GSTREAMER=ON \
    -D WITH_V4L=ON \
    -D ENABLE_FAST_MATH=ON \
    -D BUILD_opencv_python3=ON \
    -D PYTHON3_EXECUTABLE=$(which python3) \
    -D BUILD_EXAMPLES=OFF \
    -D BUILD_TESTS=OFF \
    $CUDA_ARGS

make -j$(nproc)
sudo make install
sudo ldconfig

echo ""
echo "=== Done! Verify with: ==="
echo "  python3 -c \"import cv2; print(cv2.getBuildInformation())\""