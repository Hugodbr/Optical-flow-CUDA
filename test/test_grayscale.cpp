// Minimal C++ test — opens a camera, applies grayscale, confirms it's not empty.
// Run directly: ./build/test_grayscale [device_index_or_url]

#include <opencv2/opencv.hpp>
#include "filters/GrayscaleFilter.h"
#include <iostream>

int main(int argc, char** argv) {
    std::string src = (argc > 1) ? argv[1] : "0";

    cv::VideoCapture cap;
    try {
        cap.open(std::stoi(src));
    } catch (...) {
        cap.open(src);
    }

    if (!cap.isOpened()) {
        std::cerr << "FAIL: cannot open source: " << src << "\n";
        return -1;
    }

    cv::Mat frame;
    cap.read(frame);

    if (frame.empty()) {
        std::cerr << "FAIL: got empty frame.\n";
        return -1;
    }

    GrayscaleFilter f;
    cv::Mat result = f.apply(frame);

    if (result.empty() || result.size() != frame.size()) {
        std::cerr << "FAIL: filter output is wrong.\n";
        return -1;
    }

    std::cout << "PASS: grayscale filter works on " 
              << frame.cols << "x" << frame.rows << " frame.\n";
    return 0;
}