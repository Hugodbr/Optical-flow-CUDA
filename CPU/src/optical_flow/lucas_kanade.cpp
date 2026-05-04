/*
 * lucas_kanade.cpp - CPU Implementation
 *
 * Classic Lucas-Kanade dense optical flow on CPU.
 *
 * Pipeline per frame pair:
 *   1. Sobel kernels      — spatial gradients Ix, Iy  (Sobel 3x3)
 *   2. Temporal gradient  — It = curr - prev
 *   3. Lucas-Kanade solve — solve 2x2 structure tensor per pixel
 *   4. Flow to color      — HSV colour-wheel visualisation → BGR
 */

#include "optical_flow/lucas_kanade.h"
#include <opencv2/imgproc.hpp>
#include <cmath>
#include <algorithm>
#include <omp.h>

// ─────────────────────────────────────────────────────────────────────────────
// Step 1: Compute Sobel Gradients (Ix, Iy)
// ─────────────────────────────────────────────────────────────────────────────

static void computeSobelGradients(const cv::Mat& img, cv::Mat& Ix, cv::Mat& Iy) {
    CV_Assert(img.type() == CV_8UC1);
    
    int H = img.rows;
    int W = img.cols;
    
    Ix.create(H, W, CV_32F);
    Iy.create(H, W, CV_32F);
    
    // Sobel kernels
    // Gx = [-1  0  1]   Gy = [-1 -2 -1]
    //      [-2  0  2]        [ 0  0  0]
    //      [-1  0  1]        [ 1  2  1]
    
    for (int y = 0; y < H; ++y) {
        for (int x = 0; x < W; ++x) {
            // Border pixels: set to zero
            if (x == 0 || y == 0 || x == W - 1 || y == H - 1) {
                Ix.at<float>(y, x) = 0.f;
                Iy.at<float>(y, x) = 0.f;
                continue;
            }
            
            // Load 3x3 neighborhood
            float p00 = img.at<uchar>(y-1, x-1);
            float p01 = img.at<uchar>(y-1, x);
            float p02 = img.at<uchar>(y-1, x+1);
            float p10 = img.at<uchar>(y,   x-1);
            float p12 = img.at<uchar>(y,   x+1);
            float p20 = img.at<uchar>(y+1, x-1);
            float p21 = img.at<uchar>(y+1, x);
            float p22 = img.at<uchar>(y+1, x+1);
            
            // Sobel-X
            float gx = (-p00 + p02) + 2.f*(-p10 + p12) + (-p20 + p22);
            
            // Sobel-Y
            float gy = (-p00 - 2.f*p01 - p02) + (p20 + 2.f*p21 + p22);
            
            Ix.at<float>(y, x) = gx / 8.f;
            Iy.at<float>(y, x) = gy / 8.f;
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2: Compute Temporal Gradient (It)
// ─────────────────────────────────────────────────────────────────────────────

static void computeTemporalGradient(const cv::Mat& prev, const cv::Mat& curr, cv::Mat& It) {
    CV_Assert(prev.type() == CV_8UC1);
    CV_Assert(curr.type() == CV_8UC1);
    CV_Assert(prev.size() == curr.size());
    
    int H = prev.rows;
    int W = prev.cols;
    
    It.create(H, W, CV_32F);
    
    for (int y = 0; y < H; ++y) {
        for (int x = 0; x < W; ++x) {
            It.at<float>(y, x) = static_cast<float>(curr.at<uchar>(y, x)) - 
                                  static_cast<float>(prev.at<uchar>(y, x));
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 3: Lucas-Kanade Solver
// ─────────────────────────────────────────────────────────────────────────────

static void solveLucasKanade(
    const cv::Mat& Ix,
    const cv::Mat& Iy,
    const cv::Mat& It,
    cv::Mat& flowX,
    cv::Mat& flowY,
    int windowSize,
    float detThreshold
) {
    CV_Assert(Ix.type() == CV_32F);
    CV_Assert(Iy.type() == CV_32F);
    CV_Assert(It.type() == CV_32F);
    
    int H = Ix.rows;
    int W = Ix.cols;
    int halfWin = windowSize / 2;
    
    flowX.create(H, W, CV_32F);
    flowY.create(H, W, CV_32F);
    
    // Process each pixel
    #pragma omp parallel for collapse(2) schedule(dynamic)
    for (int y = 0; y < H; ++y) {
        for (int x = 0; x < W; ++x) {
            // Accumulate structure tensor over the window
            float Ixx = 0.f, Ixy = 0.f, Iyy = 0.f;
            float Ixt = 0.f, Iyt = 0.f;
            
            for (int wy = -halfWin; wy <= halfWin; ++wy) {
                for (int wx = -halfWin; wx <= halfWin; ++wx) {
                    // Clamp to image borders
                    int nx = std::clamp(x + wx, 0, W - 1);
                    int ny = std::clamp(y + wy, 0, H - 1);
                    
                    float ix = Ix.at<float>(ny, nx);
                    float iy = Iy.at<float>(ny, nx);
                    float it = It.at<float>(ny, nx);
                    
                    Ixx += ix * ix;
                    Ixy += ix * iy;
                    Iyy += iy * iy;
                    Ixt += ix * it;
                    Iyt += iy * it;
                }
            }
            
            // Compute determinant: det(A) = Ixx*Iyy - Ixy²
            float det = Ixx * Iyy - Ixy * Ixy;
            
            if (std::fabs(det) < detThreshold) {
                // Unreliable region — set flow to zero
                flowX.at<float>(y, x) = 0.f;
                flowY.at<float>(y, x) = 0.f;
            } else {
                // Cramer's rule:
                // [u, v]^T = A^-1 * b
                // u = (Iyy * (-Ixt) - Ixy * (-Iyt)) / det
                // v = (Ixx * (-Iyt) - Ixy * (-Ixt)) / det
                float invDet = 1.f / det;
                flowX.at<float>(y, x) = (-Ixt * Iyy + Ixy * Iyt) * invDet;
                flowY.at<float>(y, x) = (-Iyt * Ixx + Ixy * Ixt) * invDet;
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 4: HSV to BGR Conversion (inline)
// ─────────────────────────────────────────────────────────────────────────────

static void hsvToBgr(float h, float s, float v,
                      uchar& b, uchar& g, uchar& r) {
    // h in [0, 360), s and v in [0, 1]
    float c  = v * s;
    float h2 = h / 60.f;
    float x  = c * (1.f - std::fabs(std::fmod(h2, 2.f) - 1.f));
    float m  = v - c;
    
    float r1 = 0.f, g1 = 0.f, b1 = 0.f;
    int hi = static_cast<int>(h2) % 6;
    
    switch (hi) {
        case 0: r1 = c;    g1 = x;    break;
        case 1: r1 = x;    g1 = c;    break;
        case 2: g1 = c;    b1 = x;    break;
        case 3: g1 = x;    b1 = c;    break;
        case 4: r1 = x;    b1 = c;    break;
        case 5: r1 = c;    b1 = x;    break;
    }
    
    r = static_cast<uchar>((r1 + m) * 255.f);
    g = static_cast<uchar>((g1 + m) * 255.f);
    b = static_cast<uchar>((b1 + m) * 255.f);
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 5: Flow Visualization (HSV Colour Wheel)
// ─────────────────────────────────────────────────────────────────────────────

static void visualizeFlow(
    const cv::Mat& flowX,
    const cv::Mat& flowY,
    cv::Mat& bgr,
    float maxFlow
) {
    int H = flowX.rows;
    int W = flowX.cols;
    
    bgr.create(H, W, CV_8UC3);
    
    #pragma omp parallel for collapse(2) schedule(dynamic)
    for (int y = 0; y < H; ++y) {
        for (int x = 0; x < W; ++x) {
            float fx = flowX.at<float>(y, x);
            float fy = flowY.at<float>(y, x);
            
            float magnitude = std::sqrt(fx * fx + fy * fy);
            float angle = std::atan2(fy, fx);  // [-π, π]
            
            // Map angle to hue [0, 360)
            float hue = (angle + M_PI) / (2.f * M_PI) * 360.f;
            
            // Map magnitude to value [0, 1], clamped at maxFlow
            float value = std::min(magnitude / maxFlow, 1.f);
            
            uchar b_val, g_val, r_val;
            hsvToBgr(hue, 1.f, value, b_val, g_val, r_val);
            
            bgr.at<cv::Vec3b>(y, x) = cv::Vec3b(b_val, g_val, r_val);
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Entry Point
// ─────────────────────────────────────────────────────────────────────────────

void runLucasKanade(
    const cv::Mat& prev,
    const cv::Mat& curr,
    cv::Mat& flowVis,
    const LKConfig& cfg
) {
    CV_Assert(prev.type() == CV_8UC1);
    CV_Assert(curr.type() == CV_8UC1);
    CV_Assert(prev.size() == curr.size());
    
    // Step 1: Compute spatial gradients
    cv::Mat Ix, Iy;
    computeSobelGradients(curr, Ix, Iy);
    
    // Step 2: Compute temporal gradient
    cv::Mat It;
    computeTemporalGradient(prev, curr, It);
    
    // Step 3: Lucas-Kanade solver
    cv::Mat flowX, flowY;
    solveLucasKanade(Ix, Iy, It, flowX, flowY, cfg.windowSize, cfg.detThreshold);
    
    // Step 4: Visualize as HSV colour wheel
    visualizeFlow(flowX, flowY, flowVis, cfg.maxFlow);
}
