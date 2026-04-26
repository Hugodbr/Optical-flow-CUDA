#pragma once

#include <opencv2/opencv.hpp>
#include <string>
#include <variant>

// A camera source can be a device index (int) or a URL/pipeline (string)
using CameraSource = std::variant<int, std::string>;

struct CameraConfig {
    CameraSource source = 0;
    int width           = 1280;
    int height          = 720;
    int fps             = 30;
};

class CameraCapture {
public:
    explicit CameraCapture(const CameraConfig& config);
    ~CameraCapture();

    bool open();
    bool read(cv::Mat& frame);
    void release();

    bool isOpened() const;
    double getActualFPS() const;

    // Static helpers
    static CameraConfig fromYaml(const std::string& path);
    static void listAvailableDevices();

private:
    CameraConfig  m_config;
    cv::VideoCapture m_cap;

    void applySource();
};