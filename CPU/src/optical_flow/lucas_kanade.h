#pragma once

#include <opencv2/opencv.hpp>

/**
 * CPU Implementation of Lucas-Kanade Dense Optical Flow
 * 
 * This is a direct CPU translation of the CUDA kernel-based algorithm.
 * Same algorithm, same results, no GPU required.
 */

// Configuration for the Lucas-Kanade solver
struct LKConfig {
    int   windowSize  = 7;      // Neighbourhood window (must be odd)
    float detThreshold = 1e-3f; // Min determinant — skips flat/noisy regions
    float maxFlow     = 20.f;   // Clamp for visualisation (pixels/frame)
};

/**
 * Main entry point — CPU version
 * 
 * @param prev      Previous grayscale frame (CV_8UC1)
 * @param curr      Current grayscale frame (CV_8UC1)
 * @param flowVis   Output BGR visualization (CV_8UC3) — allocated by function
 * @param cfg       Lucas-Kanade parameters
 */
void runLucasKanade(
    const cv::Mat& prev,
    const cv::Mat& curr,
    cv::Mat&       flowVis,
    const LKConfig& cfg = LKConfig{}
);

