#include "camera/CameraCapture.h"
#include <opencv2/core/utils/filesystem.hpp>
#include <iostream>
#include <filesystem>

// ── Constructor ──────────────────────────────────────────────────────────────

CameraCapture::CameraCapture(const CameraConfig& config)
    : m_config(config) {}

CameraCapture::~CameraCapture() {
    release();
}

// ── Open ─────────────────────────────────────────────────────────────────────

bool CameraCapture::open() {
    applySource();

    if (!m_cap.isOpened()) {
        std::cerr << "[CameraCapture] Failed to open camera source.\n";
        return false;
    }

    // Apply resolution and FPS — these are hints; the device may ignore them
    m_cap.set(cv::CAP_PROP_FRAME_WIDTH,  m_config.width);
    m_cap.set(cv::CAP_PROP_FRAME_HEIGHT, m_config.height);
    m_cap.set(cv::CAP_PROP_FPS,          m_config.fps);

    double w = m_cap.get(cv::CAP_PROP_FRAME_WIDTH);
    double h = m_cap.get(cv::CAP_PROP_FRAME_HEIGHT);
    double f = m_cap.get(cv::CAP_PROP_FPS);
    std::cout << "[CameraCapture] Opened: " << w << "x" << h
              << " @ " << f << " fps\n";

    return true;
}

void CameraCapture::applySource() {
    if (std::holds_alternative<int>(m_config.source)) {
        int idx = std::get<int>(m_config.source);
        std::cout << "[CameraCapture] Opening device index: " << idx << "\n";
        m_cap.open(idx, cv::CAP_V4L2);   // Force V4L2 on Linux
    } else {
        const std::string& url = std::get<std::string>(m_config.source);
        std::cout << "[CameraCapture] Opening stream: " << url << "\n";
        m_cap.open(url);                  // OpenCV auto-detects RTSP/HTTP/MJPEG
    }
}

// ── Read ─────────────────────────────────────────────────────────────────────

bool CameraCapture::read(cv::Mat& frame) {
    return m_cap.read(frame);
}

bool CameraCapture::isOpened() const {
    return m_cap.isOpened();
}

void CameraCapture::release() {
    if (m_cap.isOpened())
        m_cap.release();
}

double CameraCapture::getActualFPS() const {
    return m_cap.get(cv::CAP_PROP_FPS);
}

// ── Config loader ─────────────────────────────────────────────────────────────

CameraConfig CameraCapture::fromYaml(const std::string& path) {
    CameraConfig cfg;
    cv::FileStorage fs(path, cv::FileStorage::READ);

    if (!fs.isOpened()) {
        std::cerr << "[CameraCapture] Could not open config: " << path
                  << " — using defaults.\n";
        return cfg;
    }

    auto camera = fs["camera"];
    camera["width"]  >> cfg.width;
    camera["height"] >> cfg.height;
    camera["fps"]    >> cfg.fps;

    // source can be int or string in YAML
    cv::FileNode src = camera["source"];
    if (src.type() == cv::FileNode::INT) {
        cfg.source = static_cast<int>(src);
    } else {
        cfg.source = static_cast<std::string>(src);
    }

    fs.release();
    return cfg;
}

// ── List devices ──────────────────────────────────────────────────────────────

void CameraCapture::listAvailableDevices() {
    std::cout << "\n=== Available V4L2 devices ===\n";
    for (int i = 0; i < 10; ++i) {
        std::string devPath = "/dev/video" + std::to_string(i);
        if (std::filesystem::exists(devPath)) {
            std::cout << "  [" << i << "] " << devPath;

            // Try to open and get name
            cv::VideoCapture test(i, cv::CAP_V4L2);
            if (test.isOpened()) {
                std::cout << "  ✓ accessible";
                test.release();
            } else {
                std::cout << "  ✗ not accessible";
            }
            std::cout << "\n";
        }
    }
    std::cout << "==============================\n\n";
}