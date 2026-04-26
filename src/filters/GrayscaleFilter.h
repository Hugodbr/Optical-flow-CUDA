#pragma once
#include "Filter.h"

class GrayscaleFilter : public Filter {
public:
    cv::Mat apply(const cv::Mat& input) override {
        cv::Mat gray, output;
        cv::cvtColor(input, gray, cv::COLOR_BGR2GRAY);
        // Convert back to BGR so imshow renders correctly
        cv::cvtColor(gray, output, cv::COLOR_GRAY2BGR);
        return output;
    }

    const char* name() const override { return "Grayscale"; }
};