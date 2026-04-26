#pragma once
#include <opencv2/opencv.hpp>

// Abstract base — swap filters in/out without touching main.cpp
class Filter {
public:
    virtual ~Filter() = default;
    virtual cv::Mat apply(const cv::Mat& input) = 0;
    virtual const char* name() const = 0;
};