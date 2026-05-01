#include <iostream>
#include <string>
#include <chrono>
#include <filesystem>

#include <opencv2/opencv.hpp>
#include <cuda_runtime.h>

#include "cuda/lucas_kanade.h"
#include "logger.h"

#define CUDA_CHECK(call)                                                \
    do {                                                                \
        cudaError_t _e = (call);                                        \
        if (_e != cudaSuccess) {                                        \
            std::cerr << "[CUDA] " << cudaGetErrorString(_e)           \
                      << " at " << __FILE__ << ":" << __LINE__ << "\n";\
            std::exit(1);                                               \
        }                                                               \
    } while(0)

struct AppConfig {
    std::string inputPath;
    std::string outputPath = "output.avi";
    std::string logPath    = "optical_flow.log";
    std::string powerMode  = "unknown";
};

AppConfig parseArgs(int argc, char** argv) {
    AppConfig cfg;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if ((arg == "--input"  || arg == "-i") && i + 1 < argc)
            cfg.inputPath  = argv[++i];
        else if ((arg == "--output" || arg == "-o") && i + 1 < argc)
            cfg.outputPath = argv[++i];
        else if (arg == "--log" && i + 1 < argc)
            cfg.logPath    = argv[++i];
        else if (arg == "--power-mode" && i + 1 < argc)
            cfg.powerMode  = argv[++i];
        else if (arg == "--help" || arg == "-h") {
            std::cout
                << "Usage: optical_flow -i <input> [-o <output>] [--log <file>]\n"
                << "  -i, --input  <path>        Input video file\n"
                << "  -o, --output <path>        Output video file (default: output.avi)\n"
                << "      --log    <path>        Log file (default: optical_flow.log)\n"
                << "      --power-mode <string>  Jetson power mode label (set by run.sh)\n";
            std::exit(0);
        }
    }
    return cfg;
}

// ── CUDA event helper ─────────────────────────────────────────────────────────

struct CudaTimer {
    cudaEvent_t start, stop;
    CudaTimer()  { cudaEventCreate(&start); cudaEventCreate(&stop); }
    ~CudaTimer() { cudaEventDestroy(start); cudaEventDestroy(stop); }
    void begin() { cudaEventRecord(start); }
    float end()  {
        cudaEventRecord(stop);
        cudaEventSynchronize(stop);
        float ms = 0.f;
        cudaEventElapsedTime(&ms, start, stop);
        return ms;
    }
};

// ── Main ──────────────────────────────────────────────────────────────────────

int main(int argc, char** argv) {
    AppConfig app = parseArgs(argc, argv);

    if (app.inputPath.empty()) {
        std::cerr << "Error: no input video. Use -i <path>\n";
        return -1;
    }

    printCudaDeviceInfo();

    cv::VideoCapture cap(app.inputPath);
    if (!cap.isOpened()) {
        std::cerr << "Fatal: cannot open video: " << app.inputPath << "\n";
        return -1;
    }

    const int    width  = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_WIDTH));
    const int    height = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_HEIGHT));
    const double fps    = cap.get(cv::CAP_PROP_FPS);
    const int    total  = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_COUNT));

    long inputFileBytes = 0;
    try {
        inputFileBytes = static_cast<long>(std::filesystem::file_size(app.inputPath));
    } catch (...) {}

    std::cout << "Input:  " << app.inputPath
              << " (" << width << "x" << height
              << " @ " << fps << " fps, " << total << " frames)\n"
              << "Output: " << app.outputPath << "\n\n";

    cv::VideoWriter writer(
        app.outputPath,
        cv::VideoWriter::fourcc('M','J','P','G'),
        fps,
        {width, height}
    );
    if (!writer.isOpened()) {
        std::cerr << "Fatal: cannot open output: " << app.outputPath << "\n";
        return -1;
    }

    // GPU frame buffers
    const size_t grayBytes = static_cast<size_t>(width) * height;
    const size_t bgrBytes  = grayBytes * 3;

    unsigned char *d_prev, *d_curr, *d_vis;
    CUDA_CHECK(cudaMalloc(&d_prev, grayBytes));
    CUDA_CHECK(cudaMalloc(&d_curr, grayBytes));
    CUDA_CHECK(cudaMalloc(&d_vis,  bgrBytes));

    LKConfig  lkCfg;
    CudaTimer xferTimer;

    cv::Mat frame, gray, output(height, width, CV_8UC3);
    bool firstFrame = true;
    int  frameIdx   = 0;

    // Accumulated timing stats
    double totalH2DMs = 0.0, totalD2HMs = 0.0;
    double totalSobelMs = 0.0, totalTemporalMs = 0.0;
    double totalLKMs = 0.0, totalColorMs = 0.0;
    int    timedFrames = 0;

    auto t0 = std::chrono::steady_clock::now();

    while (cap.read(frame)) {
        cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);

        // H2D upload — timed
        xferTimer.begin();
        CUDA_CHECK(cudaMemcpy2D(
            d_curr, width,
            gray.data, gray.step,
            width, height,
            cudaMemcpyHostToDevice
        ));
        float h2dMs = xferTimer.end();

        if (firstFrame) {
            CUDA_CHECK(cudaMemcpy(d_prev, d_curr, grayBytes, cudaMemcpyDeviceToDevice));
            output = cv::Mat::zeros(height, width, CV_8UC3);
            firstFrame = false;
        } else {
            LKTiming t = runLucasKanade(d_prev, d_curr, d_vis, width, height, lkCfg);

            // D2H download — timed
            xferTimer.begin();
            CUDA_CHECK(cudaMemcpy2D(
                output.data, output.step,
                d_vis, width * 3,
                width * 3, height,
                cudaMemcpyDeviceToHost
            ));
            float d2hMs = xferTimer.end();

            totalH2DMs      += h2dMs;
            totalD2HMs      += d2hMs;
            totalSobelMs    += t.sobelMs;
            totalTemporalMs += t.temporalMs;
            totalLKMs       += t.lkMs;
            totalColorMs    += t.colorMs;
            ++timedFrames;
        }

        CUDA_CHECK(cudaMemcpy(d_prev, d_curr, grayBytes, cudaMemcpyDeviceToDevice));
        writer.write(output);

        ++frameIdx;
        if (frameIdx % 30 == 0 || frameIdx == total) {
            auto elapsed = std::chrono::duration<double>(
                std::chrono::steady_clock::now() - t0).count();
            std::cout << "\r  Frame " << frameIdx << "/" << total
                      << "  (" << static_cast<int>(frameIdx / elapsed) << " fps)"
                      << std::flush;
        }
    }

    double wallTimeSec = std::chrono::duration<double>(
        std::chrono::steady_clock::now() - t0).count();

    std::cout << "\nDone. " << frameIdx << " frames -> " << app.outputPath << "\n";

    // Build and write log
    RunLog log;
    log.logPath       = app.logPath;
    log.inputPath     = app.inputPath;
    log.outputPath    = app.outputPath;
    log.width         = width;
    log.height        = height;
    log.videoFps      = fps;
    log.totalFrames   = frameIdx;
    log.inputFileBytes = inputFileBytes;
    log.powerMode     = app.powerMode;
    log.wallTimeSec   = wallTimeSec;
    log.timedFrames   = timedFrames;

    if (timedFrames > 0) {
        log.avgH2DMs      = static_cast<float>(totalH2DMs      / timedFrames);
        log.avgD2HMs      = static_cast<float>(totalD2HMs      / timedFrames);
        log.avgSobelMs    = static_cast<float>(totalSobelMs    / timedFrames);
        log.avgTemporalMs = static_cast<float>(totalTemporalMs / timedFrames);
        log.avgLKMs       = static_cast<float>(totalLKMs       / timedFrames);
        log.avgColorMs    = static_cast<float>(totalColorMs    / timedFrames);
    }

    appendLog(log);

    cudaFree(d_prev);
    cudaFree(d_curr);
    cudaFree(d_vis);
    cap.release();
    writer.release();
    return 0;
}
