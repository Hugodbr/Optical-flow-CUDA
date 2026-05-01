#pragma once

#ifdef USE_CUDA

struct LKConfig {
    int   windowSize   = 7;
    float detThreshold = 1e-3f;
    float maxFlow      = 20.f;
};

struct LKTiming {
    float sobelMs    = 0.f;
    float temporalMs = 0.f;
    float lkMs       = 0.f;
    float colorMs    = 0.f;
};

// prev, curr  — contiguous grayscale device buffers (width × height bytes)
// flowVis     — contiguous BGR device buffer (width × height × 3 bytes)
// Returns per-kernel wall times measured with CUDA events (milliseconds)
LKTiming runLucasKanade(
    const unsigned char* prev,
    const unsigned char* curr,
    unsigned char*       flowVis,
    int width, int height,
    const LKConfig& cfg = LKConfig{}
);

void printCudaDeviceInfo();

#endif // USE_CUDA
