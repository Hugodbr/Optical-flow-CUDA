#include <iostream>
#include <string>
#include <chrono>

#include <opencv2/opencv.hpp>
#include <opencv2/core/cuda.hpp>

#include "cuda/lucas_kanade.h"

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

    LKConfig lkCfg;
    cv::cuda::GpuMat d_prev, d_curr, d_vis;
    cv::Mat frame, gray, output;
    bool firstFrame = true;
    int  frameIdx   = 0;

    auto t0 = std::chrono::steady_clock::now();

    while (cap.read(frame)) {
        cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);
        d_curr.upload(gray);

        if (firstFrame) {
            d_curr.copyTo(d_prev);
            output = cv::Mat::zeros(height, width, CV_8UC3);
            firstFrame = false;
        } else {
            runLucasKanade(d_prev, d_curr, d_vis, lkCfg);
            d_vis.download(output);
        }

        d_curr.copyTo(d_prev);
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

    cap.release();
    writer.release();
    return 0;
}
