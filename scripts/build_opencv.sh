#!/bin/bash
set -e

# ── Detect package manager ────────────────────────────────────────────────────
detect_pkg_manager() {
    if   command -v apt-get &>/dev/null; then echo "apt"
    elif command -v dnf     &>/dev/null; then echo "dnf"
    elif command -v pacman  &>/dev/null; then echo "pacman"
    else echo "unknown"
    fi
}

PKG_MANAGER=$(detect_pkg_manager)
echo "  Package manager: ${PKG_MANAGER}"

# ── Install GStreamer deps ─────────────────────────────────────────────────────
install_gstreamer() {
    case "${PKG_MANAGER}" in
        apt)
            sudo apt-get install -y \
                libgstreamer1.0-dev \
                libgstreamer-plugins-base1.0-dev \
                libgstreamer-plugins-good1.0-dev \
                gstreamer1.0-plugins-bad \
                gstreamer1.0-libav
            ;;
        dnf)
            # Fedora / RHEL / CentOS
            sudo dnf install -y \
                gstreamer1-devel \
                gstreamer1-plugins-base-devel \
                gstreamer1-plugins-good \
                gstreamer1-plugins-bad-free \
                gstreamer1-libav
            ;;
        pacman)
            # Arch / Manjaro
            sudo pacman -S --noconfirm \
                gstreamer \
                gst-plugins-base \
                gst-plugins-good \
                gst-plugins-bad \
                gst-libav
            ;;
        *)
            echo "WARNING: Unknown package manager — skipping GStreamer install."
            echo "  Install GStreamer dev libraries manually for your distro."
            ;;
    esac
}

# ── Install cuDNN ─────────────────────────────────────────────────────────────
install_cudnn() {
    case "${PKG_MANAGER}" in
        apt)
            # Ubuntu / Debian — NVIDIA provides apt packages
            sudo apt-get install -y \
                "libcudnn9-cuda-${CUDA_MAJOR}" \
                "libcudnn9-dev-cuda-${CUDA_MAJOR}" 2>/dev/null || return 1
            ;;
        dnf)
            # Fedora — NVIDIA repo needed, no clean package name
            echo "  INFO: For Fedora, install cuDNN manually from:"
            echo "  https://developer.nvidia.com/cudnn-downloads"
            return 1
            ;;
        pacman)
            # Arch — available in AUR
            if command -v yay &>/dev/null; then
                yay -S --noconfirm cudnn
            elif command -v paru &>/dev/null; then
                paru -S --noconfirm cudnn
            else
                echo "  INFO: Install cuDNN from AUR: yay -S cudnn"
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac
}

# ── Add NVIDIA repo (apt only) ────────────────────────────────────────────────
add_nvidia_repo() {
    if [ "${PKG_MANAGER}" != "apt" ]; then
        echo "  Skipping NVIDIA repo setup (not apt-based)."
        return 1
    fi

    UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "22.04")
    ARCH=$(dpkg --print-architecture)
    KEYRING_PKG="cuda-keyring_1.1-1_all.deb"
    KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu${UBUNTU_VERSION//./}/${ARCH}/${KEYRING_PKG}"

    wget -q -O /tmp/${KEYRING_PKG} "${KEYRING_URL}" || return 1
    sudo dpkg -i /tmp/${KEYRING_PKG}
    sudo apt-get update -qq
}