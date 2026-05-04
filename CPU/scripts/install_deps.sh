#!/bin/bash
# install_deps.sh - Install CPU optical flow dependencies

set -e

echo "=========================================="
echo "  Installing CPU Optical Flow Dependencies"
echo "=========================================="
echo ""

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    echo "ERROR: Cannot detect operating system"
    exit 1
fi

echo "[*] Detected OS: $OS"
echo ""

# Install based on OS
case "$OS" in
    ubuntu|debian)
        echo "[*] Installing Ubuntu/Debian dependencies..."
        sudo apt-get update
        sudo apt-get install -y \
            build-essential \
            cmake \
            git \
            pkg-config \
            libopencv-dev \
            libopencv-contrib-dev \
            libomp-dev
        ;;
    fedora)
        echo "[*] Installing Fedora/RHEL dependencies..."
        sudo dnf install -y \
            gcc-c++ \
            make \
            cmake \
            git \
            pkg-config \
            opencv-devel \
            libomp-devel
        ;;
    arch)
        echo "[*] Installing Arch Linux dependencies..."
        sudo pacman -S --noconfirm \
            base-devel \
            cmake \
            git \
            pkg-config \
            opencv \
            libomp
        ;;
    *)
        echo "ERROR: Unsupported OS: $OS"
        echo "Please install manually:"
        echo "  - CMake 3.18+"
        echo "  - OpenCV 4.x development files"
        echo "  - OpenMP"
        echo "  - C++17 compiler (gcc, clang)"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "  Verifying Installation"
echo "=========================================="
echo ""

# Check CMake
if command -v cmake &> /dev/null; then
    echo "✓ CMake: $(cmake --version | head -1)"
else
    echo "✗ CMake not found"
    exit 1
fi

# Check OpenCV
if pkg-config --exists opencv4; then
    echo "✓ OpenCV: $(pkg-config --modversion opencv4)"
else
    echo "⚠ OpenCV not found via pkg-config"
    echo "  (May still be installed, trying to continue...)"
fi

# Check compiler
if command -v g++ &> /dev/null; then
    echo "✓ GCC: $(g++ --version | head -1)"
elif command -v clang++ &> /dev/null; then
    echo "✓ Clang: $(clang++ --version | head -1)"
else
    echo "✗ No C++ compiler found"
    exit 1
fi

# Check OpenMP
if command -v omp --version &> /dev/null 2>&1 || pkg-config --exists openmp; then
    echo "✓ OpenMP: available"
else
    echo "⚠ OpenMP may not be installed (will try to install it separately)"
fi

echo ""
echo "=========================================="
echo "  Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. cd CPU"
echo "  2. bash scripts/linux/build.sh"
echo "  3. bash scripts/linux/run.sh 0"
echo ""
