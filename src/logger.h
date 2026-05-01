#pragma once
#include <string>

struct RunLog {
    // Paths
    std::string logPath    = "optical_flow.log";
    std::string inputPath;
    std::string outputPath;

    // Video info
    int    width        = 0;
    int    height       = 0;
    double videoFps     = 0.0;
    int    totalFrames  = 0;
    long   inputFileBytes = 0;

    // Jetson power mode (captured by run.sh via nvpmodel -q)
    std::string powerMode = "unknown";

    // Wall clock time for the full run
    double wallTimeSec = 0.0;

    // CUDA timing — averages per processed frame (ms)
    float avgH2DMs      = 0.f;   // host → device upload (grayscale)
    float avgD2HMs      = 0.f;   // device → host download (BGR)
    float avgSobelMs    = 0.f;
    float avgTemporalMs = 0.f;
    float avgLKMs       = 0.f;
    float avgColorMs    = 0.f;
    int   timedFrames   = 0;     // frames used to compute averages
};

void appendLog(const RunLog& log);
