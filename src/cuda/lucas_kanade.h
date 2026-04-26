#pragma once

#ifdef USE_CUDA
#include <opencv2/core/cuda.hpp>

// Configuration for the LK solver
struct LKConfig {
    int   windowSize  = 7;      // Neighbourhood window (must be odd)
    float detThreshold = 1e-3f; // Min determinant — skips flat/noisy regions
    float maxFlow     = 20.f;   // Clamp for visualisation (pixels/frame)
};

// Main entry point called from main.cpp each frame
// prev, curr  — grayscale GPU frames (CV_8UC1)
// flowVis     — output BGR visualisation frame (CV_8UC3), same size as input
void runLucasKanade(
    const cv::cuda::GpuMat& prev,
    const cv::cuda::GpuMat& curr,
    cv::cuda::GpuMat&       flowVis,
    const LKConfig&         cfg = LKConfig{}
);

// Prints CUDA device info to stdout — call once at startup
void printCudaDeviceInfo();

#endif // USE_CUDA