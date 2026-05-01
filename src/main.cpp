#include <iostream>
#include <string>
#include <chrono>

#include <opencv2/opencv.hpp>
#include <cuda_runtime.h>

#include "cuda/lucas_kanade.h"

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
};

AppConfig parseArgs(int argc, char** argv) {
    AppConfig cfg;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if ((arg == "--input" || arg == "-i") && i + 1 < argc)
            cfg.inputPath = argv[++i];
        else if ((arg == "--output" || arg == "-o") && i + 1 < argc)
            cfg.outputPath = argv[++i];
        else if (arg == "--help" || arg == "-h") {
            std::cout
                << "Usage: optical_flow -i <input_video> [-o <output_video>]\n"
                << "  -i, --input  <path>   Input video file\n"
                << "  -o, --output <path>   Output video file (default: output.avi)\n";
            std::exit(0);
        }
    }
    return cfg;
}

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

    // GPU buffers — prev/curr are grayscale (1 byte/px), vis is BGR (3 bytes/px)
    const size_t grayBytes = static_cast<size_t>(width) * height;
    const size_t bgrBytes  = grayBytes * 3;

    unsigned char *d_prev, *d_curr, *d_vis;
    CUDA_CHECK(cudaMalloc(&d_prev, grayBytes));
    CUDA_CHECK(cudaMalloc(&d_curr, grayBytes));
    CUDA_CHECK(cudaMalloc(&d_vis,  bgrBytes));

    LKConfig lkCfg;
    cv::Mat frame, gray, output(height, width, CV_8UC3);
    bool firstFrame = true;
    int  frameIdx   = 0;

    auto t0 = std::chrono::steady_clock::now();

    while (cap.read(frame)) {
        cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);

        // Upload: handle cv::Mat row padding with cudaMemcpy2D
        CUDA_CHECK(cudaMemcpy2D(
            d_curr, width,         // dst (contiguous), dst pitch
            gray.data, gray.step,  // src, src pitch (may have padding)
            width, height,
            cudaMemcpyHostToDevice
        ));

        if (firstFrame) {
            CUDA_CHECK(cudaMemcpy(d_prev, d_curr, grayBytes, cudaMemcpyDeviceToDevice));
            output = cv::Mat::zeros(height, width, CV_8UC3);
            firstFrame = false;
        } else {
            runLucasKanade(d_prev, d_curr, d_vis, width, height, lkCfg);

            // Download: d_vis is contiguous, output.step may have padding
            CUDA_CHECK(cudaMemcpy2D(
                output.data, output.step,  // dst, dst pitch
                d_vis, width * 3,          // src (contiguous), src pitch
                width * 3, height,
                cudaMemcpyDeviceToHost
            ));
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

    std::cout << "\nDone. " << frameIdx << " frames -> " << app.outputPath << "\n";

    cudaFree(d_prev);
    cudaFree(d_curr);
    cudaFree(d_vis);
    cap.release();
    writer.release();
    return 0;
}
