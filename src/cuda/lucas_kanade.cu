/*
 * lucas_kanade.cu
 *
 * Classic Lucas-Kanade dense optical flow on CUDA.
 *
 * Pipeline per frame pair:
 *   1. sobelKernel        — spatial gradients Ix, Iy  (Sobel 3x3)
 *   2. temporalKernel     — temporal gradient It = curr - prev
 *   3. lucasKanadeKernel  — solve 2x2 structure tensor per pixel
 *   4. flowToColorKernel  — HSV colour-wheel visualisation → BGR
 */

#ifdef USE_CUDA

#include "cuda/lucas_kanade.h"

#include <cuda_runtime.h>
#include <device_launch_parameters.h>
#include <opencv2/core/cuda.hpp>

#include <cmath>
#include <iostream>
#include <stdexcept>

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

// Convenience macro — throws a std::runtime_error on CUDA failure
#define CUDA_CHECK(call)                                                        \
    do {                                                                        \
        cudaError_t _err = (call);                                              \
        if (_err != cudaSuccess) {                                              \
            throw std::runtime_error(                                           \
                std::string("[CUDA] ") + cudaGetErrorString(_err) +             \
                " at " + __FILE__ + ":" + std::to_string(__LINE__));            \
        }                                                                       \
    } while (0)

static constexpr int BLOCK = 16;   // 16x16 thread block = 256 threads


// ─────────────────────────────────────────────────────────────────────────────
// Kernel 1 — Sobel gradients
// ─────────────────────────────────────────────────────────────────────────────
//
// Computes Ix and Iy for every pixel using a 3x3 Sobel operator.
// Border pixels are zeroed (they will be skipped by the LK kernel anyway).
//
//   Sobel-X:  [-1  0  +1]       Sobel-Y:  [-1  -2  -1]
//              [-2  0  +2]                  [ 0   0   0]
//              [-1  0  +1]                  [+1  +2  +1]
//
// Dividing by 8 normalises to the range of the original pixel values.

__global__ void sobelKernel(
    const uchar* __restrict__ img,     // grayscale input  (row-major, step bytes/row)
    float*       __restrict__ Ix,      // dI/dx output     (width*height floats)
    float*       __restrict__ Iy,      // dI/dy output
    int width, int height, int step    // step = bytes per row (may differ from width)
) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    // Zero the border — these pixels have no valid 3x3 neighbourhood
    if (x == 0 || y == 0 || x == width - 1 || y == height - 1) {
        Ix[y * width + x] = 0.f;
        Iy[y * width + x] = 0.f;
        return;
    }

    // Load the 3x3 neighbourhood once into registers to avoid repeated global reads
    float p00 = img[(y-1)*step + (x-1)], p01 = img[(y-1)*step + x], p02 = img[(y-1)*step + (x+1)];
    float p10 = img[ y   *step + (x-1)],                              p12 = img[ y   *step + (x+1)];
    float p20 = img[(y+1)*step + (x-1)], p21 = img[(y+1)*step + x], p22 = img[(y+1)*step + (x+1)];

    float gx = (-p00 + p02) + 2.f*(-p10 + p12) + (-p20 + p22);
    float gy = (-p00 - 2.f*p01 - p02) + (p20 + 2.f*p21 + p22);

    Ix[y * width + x] = gx / 8.f;
    Iy[y * width + x] = gy / 8.f;
}


// ─────────────────────────────────────────────────────────────────────────────
// Kernel 2 — Temporal gradient
// ─────────────────────────────────────────────────────────────────────────────
//
// It(x,y) = I_curr(x,y) - I_prev(x,y)
// Simple frame difference — adequate for small inter-frame motion.

__global__ void temporalKernel(
    const uchar* __restrict__ prev,
    const uchar* __restrict__ curr,
    float*       __restrict__ It,
    int width, int height, int step
) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) return;

    It[y * width + x] =
        static_cast<float>(curr[y * step + x]) -
        static_cast<float>(prev[y * step + x]);
}


// ─────────────────────────────────────────────────────────────────────────────
// Kernel 3 — Lucas-Kanade optical flow
// ─────────────────────────────────────────────────────────────────────────────
//
// Assumes brightness constancy:  Ix*u + Iy*v + It = 0
//
// For each pixel, sums the structure tensor A and vector b over a WxW window:
//
//   A = | sum(Ix²)   sum(Ix·Iy) |     b = | -sum(Ix·It) |
//       | sum(Ix·Iy) sum(Iy²)   |         | -sum(Iy·It) |
//
// Flow is the least-squares solution:  [u, v]^T = A^-1 · b
//
// Pixels where det(A) is too small are unreliable (uniform regions, noise)
// and are set to zero flow.

__global__ void lucasKanadeKernel(
    const float* __restrict__ Ix,
    const float* __restrict__ Iy,
    const float* __restrict__ It,
    float*       __restrict__ flowX,
    float*       __restrict__ flowY,
    int   width,
    int   height,
    int   halfWin,         // window half-size, e.g. 3 for a 7x7 window
    float detThreshold     // minimum |det(A)| to consider reliable
) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) return;

    // Accumulate structure tensor elements over the local window
    float Ixx = 0.f, Ixy = 0.f, Iyy = 0.f;
    float Ixt = 0.f, Iyt = 0.f;

    for (int wy = -halfWin; wy <= halfWin; ++wy) {
        for (int wx = -halfWin; wx <= halfWin; ++wx) {
            // Clamp to image border (replicates edge pixels)
            int nx  = min(max(x + wx, 0), width  - 1);
            int ny  = min(max(y + wy, 0), height - 1);
            int idx = ny * width + nx;

            float ix = Ix[idx];
            float iy = Iy[idx];
            float it = It[idx];

            Ixx += ix * ix;
            Ixy += ix * iy;
            Iyy += iy * iy;
            Ixt += ix * it;
            Iyt += iy * it;
        }
    }

    // det(A) = Ixx*Iyy - Ixy^2
    float det = Ixx * Iyy - Ixy * Ixy;

    if (fabsf(det) < detThreshold) {
        // Unreliable region — zero flow
        flowX[y * width + x] = 0.f;
        flowY[y * width + x] = 0.f;
        return;
    }

    // Cramer's rule:
    //   u = (Iyy * (-Ixt) - Ixy * (-Iyt)) / det
    //   v = (Ixx * (-Iyt) - Ixy * (-Ixt)) / det
    float invDet = 1.f / det;
    flowX[y * width + x] = (-Ixt * Iyy + Ixy * Iyt) * invDet;
    flowY[y * width + x] = (-Iyt * Ixx + Ixy * Ixt) * invDet;
}


// ─────────────────────────────────────────────────────────────────────────────
// Kernel 4 — Flow → BGR colour wheel
// ─────────────────────────────────────────────────────────────────────────────
//
// Standard HSV optical flow visualisation:
//   Hue        = flow direction  (0–360° mapped to 0–179 for OpenCV)
//   Saturation = 255 (always fully saturated)
//   Value      = flow magnitude  (normalised to [0, maxFlow], clamped)
//
// HSV → BGR conversion is done inline to avoid a second pass.

__device__ void hsvToBgr(float h, float s, float v,
                          uchar& b, uchar& g, uchar& r)
{
    // h in [0, 360), s and v in [0, 1]
    float c  = v * s;
    float h2 = h / 60.f;
    float x  = c * (1.f - fabsf(fmodf(h2, 2.f) - 1.f));
    float m  = v - c;

    float r1 = 0.f, g1 = 0.f, b1 = 0.f;
    int   hi = static_cast<int>(h2) % 6;

    switch (hi) {
        case 0: r1=c; g1=x; break;
        case 1: r1=x; g1=c; break;
        case 2: g1=c; b1=x; break;
        case 3: g1=x; b1=c; break;
        case 4: r1=x; b1=c; break;
        case 5: r1=c; b1=x; break;
    }

    r = static_cast<uchar>((r1 + m) * 255.f);
    g = static_cast<uchar>((g1 + m) * 255.f);
    b = static_cast<uchar>((b1 + m) * 255.f);
}

__global__ void flowToColorKernel(
    const float* __restrict__ flowX,
    const float* __restrict__ flowY,
    uchar*       __restrict__ bgr,     // output: width * height * 3 bytes
    int   width,
    int   height,
    float maxFlow    // flow magnitude that maps to full brightness
) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) return;

    int idx = y * width + x;
    float fx = flowX[idx];
    float fy = flowY[idx];

    float magnitude = sqrtf(fx * fx + fy * fy);
    float angle     = atan2f(fy, fx);               // [-π, π]

    // Map angle to hue [0, 360)
    float hue = (angle + static_cast<float>(M_PI)) /
                (2.f  * static_cast<float>(M_PI)) * 360.f;

    // Map magnitude to value [0, 1], clamped at maxFlow
    float value = fminf(magnitude / maxFlow, 1.f);

    uchar b, g, r;
    hsvToBgr(hue, 1.f, value, b, g, r);

    int bgrIdx = idx * 3;
    bgr[bgrIdx + 0] = b;
    bgr[bgrIdx + 1] = g;
    bgr[bgrIdx + 2] = r;
}


// ─────────────────────────────────────────────────────────────────────────────
// GPU buffer pool — avoids malloc/free every frame
// ─────────────────────────────────────────────────────────────────────────────

struct GpuBuffers {
    float* Ix      = nullptr;
    float* Iy      = nullptr;
    float* It      = nullptr;
    float* flowX   = nullptr;
    float* flowY   = nullptr;
    uchar* bgrOut  = nullptr;

    int    width   = 0;
    int    height  = 0;

    void allocate(int w, int h) {
        if (w == width && h == height) return;   // already the right size
        release();
        size_t n      = static_cast<size_t>(w) * h;
        size_t nFloat = n * sizeof(float);
        size_t nBgr   = n * 3 * sizeof(uchar);

        CUDA_CHECK(cudaMalloc(&Ix,     nFloat));
        CUDA_CHECK(cudaMalloc(&Iy,     nFloat));
        CUDA_CHECK(cudaMalloc(&It,     nFloat));
        CUDA_CHECK(cudaMalloc(&flowX,  nFloat));
        CUDA_CHECK(cudaMalloc(&flowY,  nFloat));
        CUDA_CHECK(cudaMalloc(&bgrOut, nBgr));

        width  = w;
        height = h;
    }

    void release() {
        cudaFree(Ix);     Ix     = nullptr;
        cudaFree(Iy);     Iy     = nullptr;
        cudaFree(It);     It     = nullptr;
        cudaFree(flowX);  flowX  = nullptr;
        cudaFree(flowY);  flowY  = nullptr;
        cudaFree(bgrOut); bgrOut = nullptr;
        width = height = 0;
    }

    ~GpuBuffers() { release(); }
};

// Single static instance — persists across frames
static GpuBuffers g_bufs;


// ─────────────────────────────────────────────────────────────────────────────
// Host-side entry point
// ─────────────────────────────────────────────────────────────────────────────

void runLucasKanade(
    const cv::cuda::GpuMat& prev,
    const cv::cuda::GpuMat& curr,
    cv::cuda::GpuMat&       flowVis,
    const LKConfig&         cfg
) {
    CV_Assert(prev.type() == CV_8UC1);
    CV_Assert(curr.type() == CV_8UC1);
    CV_Assert(prev.size() == curr.size());

    const int W = prev.cols;
    const int H = prev.rows;

    // Ensure output is allocated
    if (flowVis.empty() || flowVis.size() != prev.size() || flowVis.type() != CV_8UC3)
        flowVis.create(H, W, CV_8UC3);

    // (Re-)allocate intermediate buffers if resolution changed
    g_bufs.allocate(W, H);

    // Kernel launch config
    dim3 block(BLOCK, BLOCK);
    dim3 grid(
        (W + BLOCK - 1) / BLOCK,
        (H + BLOCK - 1) / BLOCK
    );

    int halfWin = cfg.windowSize / 2;

    // Step 1: spatial gradients of the current frame
    sobelKernel<<<grid, block>>>(
        curr.ptr<uchar>(), g_bufs.Ix, g_bufs.Iy,
        W, H, static_cast<int>(curr.step)
    );
    CUDA_CHECK(cudaGetLastError());

    // Step 2: temporal gradient
    temporalKernel<<<grid, block>>>(
        prev.ptr<uchar>(), curr.ptr<uchar>(), g_bufs.It,
        W, H, static_cast<int>(prev.step)
    );
    CUDA_CHECK(cudaGetLastError());

    // Step 3: Lucas-Kanade solve
    lucasKanadeKernel<<<grid, block>>>(
        g_bufs.Ix, g_bufs.Iy, g_bufs.It,
        g_bufs.flowX, g_bufs.flowY,
        W, H, halfWin, cfg.detThreshold
    );
    CUDA_CHECK(cudaGetLastError());

    // Step 4: visualise as HSV colour wheel
    flowToColorKernel<<<grid, block>>>(
        g_bufs.flowX, g_bufs.flowY,
        g_bufs.bgrOut,
        W, H, cfg.maxFlow
    );
    CUDA_CHECK(cudaGetLastError());

    // Copy result into the output GpuMat (zero-copy: same device memory)
    // flowVis wraps bgrOut — avoids a device→device memcpy
    flowVis = cv::cuda::GpuMat(H, W, CV_8UC3, g_bufs.bgrOut);

    CUDA_CHECK(cudaDeviceSynchronize());
}


// ─────────────────────────────────────────────────────────────────────────────
// Device info
// ─────────────────────────────────────────────────────────────────────────────

void printCudaDeviceInfo() {
    int deviceCount = 0;
    CUDA_CHECK(cudaGetDeviceCount(&deviceCount));

    std::cout << "\n=== CUDA Devices ===\n";
    for (int i = 0; i < deviceCount; ++i) {
        cudaDeviceProp p;
        CUDA_CHECK(cudaGetDeviceProperties(&p, i));
        std::cout
            << "  [" << i << "] " << p.name << "\n"
            << "       Compute cap : " << p.major << "." << p.minor << "\n"
            << "       Global mem  : " << p.totalGlobalMem / (1 << 20) << " MB\n"
            << "       SM count    : " << p.multiProcessorCount << "\n"
            << "       Max threads : " << p.maxThreadsPerBlock << " per block\n";
    }
    std::cout << "====================\n\n";
}

#endif // USE_CUDA