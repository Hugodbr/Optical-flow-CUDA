#include "logger.h"

#include <fstream>
#include <iostream>
#include <iomanip>
#include <sstream>
#include <ctime>

static std::string currentTimestamp() {
    auto t  = std::time(nullptr);
    auto tm = *std::localtime(&t);
    std::ostringstream oss;
    oss << std::put_time(&tm, "%Y-%m-%d %H:%M:%S");
    return oss.str();
}

static double bandwidthGBps(long bytes, float avgMs) {
    if (avgMs <= 0.f) return 0.0;
    return (static_cast<double>(bytes) / 1e9) / (avgMs * 1e-3);
}

void appendLog(const RunLog& log) {
    std::ofstream f(log.logPath, std::ios::app);
    if (!f.is_open()) {
        std::cerr << "[log] Cannot open log file: " << log.logPath << "\n";
        return;
    }

    const long grayBytes = static_cast<long>(log.width) * log.height;
    const long bgrBytes  = grayBytes * 3;
    const double simFps  = log.wallTimeSec > 0.0
                           ? log.totalFrames / log.wallTimeSec
                           : 0.0;
    const float kernelTotalMs = log.avgSobelMs + log.avgTemporalMs
                              + log.avgLKMs    + log.avgColorMs;

    f << std::fixed;

    f << "================================================================================\n";
    f << "Run timestamp : " << currentTimestamp() << "\n";
    f << "Input         : " << log.inputPath
      << "  (" << log.width << "x" << log.height
      << " @ " << std::setprecision(1) << log.videoFps << " fps"
      << ", " << log.totalFrames << " frames"
      << ", " << std::setprecision(1) << log.inputFileBytes / 1e6 << " MB)\n";
    f << "Output        : " << log.outputPath << "\n";
    f << "Power mode    : " << log.powerMode  << "\n";
    f << "\n";

    f << "Wall time     : " << std::setprecision(2) << log.wallTimeSec << " s\n";
    f << "Simulated FPS : " << std::setprecision(1) << simFps
      << " fps  (" << log.totalFrames << " frames / "
      << std::setprecision(2) << log.wallTimeSec << " s)\n";
    f << "\n";

    f << "CUDA per-frame averages (" << log.timedFrames << " frames):\n";
    f << std::setprecision(3);
    f << "  H2D upload       : " << std::setw(7) << log.avgH2DMs
      << " ms   [ " << std::setprecision(2) << bandwidthGBps(grayBytes, log.avgH2DMs) << " GB/s ]\n";
    f << "  D2H download     : " << std::setprecision(3) << std::setw(7) << log.avgD2HMs
      << " ms   [ " << std::setprecision(2) << bandwidthGBps(bgrBytes,  log.avgD2HMs) << " GB/s ]\n";
    f << std::setprecision(3);
    f << "  Sobel kernel     : " << std::setw(7) << log.avgSobelMs    << " ms\n";
    f << "  Temporal kernel  : " << std::setw(7) << log.avgTemporalMs << " ms\n";
    f << "  Lucas-Kanade     : " << std::setw(7) << log.avgLKMs       << " ms\n";
    f << "  Color mapping    : " << std::setw(7) << log.avgColorMs    << " ms\n";
    f << "  Kernels total    : " << std::setw(7) << kernelTotalMs     << " ms\n";
    f << "================================================================================\n\n";

    std::cout << "[log] Appended to " << log.logPath << "\n";
}
