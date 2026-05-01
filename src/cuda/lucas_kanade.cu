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
 *
 * No OpenCV CUDA dependency — all GPU memory is managed with raw cudaMalloc.
 */

#ifdef USE_CUDA

#include "cuda/lucas_kanade.h"

#include <cuda_runtime.h>
#include <device_launch_parameters.h>

#include <cmath>
#include <iostream>
#include <stdexcept>

using uchar = unsigned char;

#define CUDA_CHECK(call)                                                        \
    do {                                                                        \
        cudaError_t _err = (call);                                              \
        if (_err != cudaSuccess) {                                              \
            throw std::runtime_error(                                           \
                std::string("[CUDA] ") + cudaGetErrorString(_err) +             \
                " at " + __FILE__ + ":" + std::to_string(__LINE__));            \
        }                                                                       \
    } while (0)

static constexpr int BLOCK = 16;


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
    const uchar* __restrict__ img,
    float*       __restrict__ Ix,
    float*       __restrict__ Iy,
    int width, int height
) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;

    if (x >= width || y >= height) return;

    if (x == 0 || y == 0 || x == width - 1 || y == height - 1) {
        Ix[y * width + x] = 0.f;
        Iy[y * width + x] = 0.f;
        return;
    }

    float p00 = img[(y-1)*width + (x-1)], p01 = img[(y-1)*width + x], p02 = img[(y-1)*width + (x+1)];
    float p10 = img[ y   *width + (x-1)],                               p12 = img[ y   *width + (x+1)];
    float p20 = img[(y+1)*width + (x-1)], p21 = img[(y+1)*width + x], p22 = img[(y+1)*width + (x+1)];

    float gx = (-p00 + p02) + 2.f*(-p10 + p12) + (-p20 + p22);
    float gy = (-p00 - 2.f*p01 - p02) + (p20 + 2.f*p21 + p22);

    Ix[y * width + x] = gx / 8.f;
    Iy[y * width + x] = gy / 8.f;
}


// ─────────────────────────────────────────────────────────────────────────────
// Kernel 2 — Temporal gradient
// ─────────────────────────────────────────────────────────────────────────────

__global__ void temporalKernel(
    const uchar* __restrict__ prev,
    const uchar* __restrict__ curr,
    float*       __restrict__ It,
    int width, int height
) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) return;

    int idx = y * width + x;
    It[idx] = static_cast<float>(curr[idx]) - static_cast<float>(prev[idx]);
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

__global__ void lucasKanadeKernel(
    const float* __restrict__ Ix,
    const float* __restrict__ Iy,
    const float* __restrict__ It,
    float*       __restrict__ flowX,
    float*       __restrict__ flowY,
    int width, int height,
    int halfWin, float detThreshold
) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) return;

    float Ixx = 0.f, Ixy = 0.f, Iyy = 0.f;
    float Ixt = 0.f, Iyt = 0.f;

    for (int wy = -halfWin; wy <= halfWin; ++wy) {
        for (int wx = -halfWin; wx <= halfWin; ++wx) {
            int nx  = min(max(x + wx, 0), width  - 1);
            int ny  = min(max(y + wy, 0), height - 1);
            int idx = ny * width + nx;

            float ix = Ix[idx], iy = Iy[idx], it = It[idx];
            Ixx += ix * ix;
            Ixy += ix * iy;
            Iyy += iy * iy;
            Ixt += ix * it;
            Iyt += iy * it;
        }
    }

    float det = Ixx * Iyy - Ixy * Ixy;

    if (fabsf(det) < detThreshold) {
        flowX[y * width + x] = 0.f;
        flowY[y * width + x] = 0.f;
        return;
    }

    float invDet = 1.f / det;
    flowX[y * width + x] = (-Ixt * Iyy + Ixy * Iyt) * invDet;
    flowY[y * width + x] = (-Iyt * Ixx + Ixy * Ixt) * invDet;
}


// ─────────────────────────────────────────────────────────────────────────────
// Kernel 4 — Flow → BGR colour wheel
// ─────────────────────────────────────────────────────────────────────────────

__device__ void hsvToBgr(float h, float s, float v,
                          uchar& b, uchar& g, uchar& r)
{
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
    uchar*       __restrict__ bgr,
    int width, int height, float maxFlow
) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) return;

    int   idx       = y * width + x;
    float fx        = flowX[idx];
    float fy        = flowY[idx];
    float magnitude = sqrtf(fx * fx + fy * fy);
    float angle     = atan2f(fy, fx);

    float hue   = (angle + static_cast<float>(M_PI)) /
                  (2.f   * static_cast<float>(M_PI)) * 360.f;
    float value = fminf(magnitude / maxFlow, 1.f);

    uchar b, g, r;
    hsvToBgr(hue, 1.f, value, b, g, r);

    int bgrIdx = idx * 3;
    bgr[bgrIdx + 0] = b;
    bgr[bgrIdx + 1] = g;
    bgr[bgrIdx + 2] = r;
}


// ─────────────────────────────────────────────────────────────────────────────
// GPU buffer pool — intermediate buffers, reused across frames
// ─────────────────────────────────────────────────────────────────────────────

struct GpuBuffers {
    float* Ix    = nullptr;
    float* Iy    = nullptr;
    float* It    = nullptr;
    float* flowX = nullptr;
    float* flowY = nullptr;
    int    width  = 0;
    int    height = 0;

    void allocate(int w, int h) {
        if (w == width && h == height) return;
        release();
        size_t n = static_cast<size_t>(w) * h * sizeof(float);
        CUDA_CHECK(cudaMalloc(&Ix,    n));
        CUDA_CHECK(cudaMalloc(&Iy,    n));
        CUDA_CHECK(cudaMalloc(&It,    n));
        CUDA_CHECK(cudaMalloc(&flowX, n));
        CUDA_CHECK(cudaMalloc(&flowY, n));
        width = w; height = h;
    }

    void release() {
        cudaFree(Ix);    Ix    = nullptr;
        cudaFree(Iy);    Iy    = nullptr;
        cudaFree(It);    It    = nullptr;
        cudaFree(flowX); flowX = nullptr;
        cudaFree(flowY); flowY = nullptr;
        width = height = 0;
    }

    ~GpuBuffers() { release(); }
};

static GpuBuffers g_bufs;


// ─────────────────────────────────────────────────────────────────────────────
// Host-side entry point
// ─────────────────────────────────────────────────────────────────────────────

// CUDA event pair — created once, reused every frame
static cudaEvent_t s_eStart = nullptr;
static cudaEvent_t s_eStop  = nullptr;

static float timeKernel(cudaEvent_t eStart, cudaEvent_t eStop) {
    float ms = 0.f;
    cudaEventSynchronize(eStop);
    cudaEventElapsedTime(&ms, eStart, eStop);
    return ms;
}

LKTiming runLucasKanade(
    const unsigned char* prev,
    const unsigned char* curr,
    unsigned char*       flowVis,
    int width, int height,
    const LKConfig& cfg
) {
    if (!s_eStart) {
        CUDA_CHECK(cudaEventCreate(&s_eStart));
        CUDA_CHECK(cudaEventCreate(&s_eStop));
    }

    g_bufs.allocate(width, height);

    dim3 block(BLOCK, BLOCK);
    dim3 grid((width + BLOCK - 1) / BLOCK, (height + BLOCK - 1) / BLOCK);

    LKTiming timing;

    cudaEventRecord(s_eStart);
    sobelKernel<<<grid, block>>>(curr, g_bufs.Ix, g_bufs.Iy, width, height);
    cudaEventRecord(s_eStop);
    CUDA_CHECK(cudaGetLastError());
    timing.sobelMs = timeKernel(s_eStart, s_eStop);

    cudaEventRecord(s_eStart);
    temporalKernel<<<grid, block>>>(prev, curr, g_bufs.It, width, height);
    cudaEventRecord(s_eStop);
    CUDA_CHECK(cudaGetLastError());
    timing.temporalMs = timeKernel(s_eStart, s_eStop);

    cudaEventRecord(s_eStart);
    lucasKanadeKernel<<<grid, block>>>(
        g_bufs.Ix, g_bufs.Iy, g_bufs.It,
        g_bufs.flowX, g_bufs.flowY,
        width, height, cfg.windowSize / 2, cfg.detThreshold
    );
    cudaEventRecord(s_eStop);
    CUDA_CHECK(cudaGetLastError());
    timing.lkMs = timeKernel(s_eStart, s_eStop);

    cudaEventRecord(s_eStart);
    // flowVis is the caller's device buffer — write directly into it
    flowToColorKernel<<<grid, block>>>(
        g_bufs.flowX, g_bufs.flowY, flowVis, width, height, cfg.maxFlow
    );
    cudaEventRecord(s_eStop);
    CUDA_CHECK(cudaGetLastError());
    timing.colorMs = timeKernel(s_eStart, s_eStop);

    CUDA_CHECK(cudaDeviceSynchronize());
    return timing;
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
            << "       SM count    : " << p.multiProcessorCount << "\n";
    }
    std::cout << "====================\n\n";
}

#endif // USE_CUDA
