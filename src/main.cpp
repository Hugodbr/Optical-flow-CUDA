#include <iostream>
#include <string>
#include <memory>
#include <chrono>

#include <opencv2/opencv.hpp>

#include "camera/CameraCapture.h"
#include "filters/Filter.h"
#include "filters/GrayscaleFilter.h"

#ifdef USE_CUDA
#include <opencv2/core/cuda.hpp>
#include "cuda/lucas_kanade.h"
#endif

// ── (parseArgs and FPSCounter unchanged from before) ─────────────────────────

struct AppConfig {
    std::string configPath     = "../config/camera.yaml";
    std::string cameraOverride;
    bool        listCameras    = false;
};

AppConfig parseArgs(int argc, char** argv) {
    AppConfig app;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if ((arg == "--camera" || arg == "-c") && i + 1 < argc)
            app.cameraOverride = argv[++i];
        else if ((arg == "--config" || arg == "-f") && i + 1 < argc)
            app.configPath = argv[++i];
        else if (arg == "--list" || arg == "-l")
            app.listCameras = true;
        else if (arg == "--help" || arg == "-h") {
            std::cout
                << "Usage: optical_flow [options]\n"
                << "  -c, --camera <src>   Device index or stream URL\n"
                << "  -f, --config <path>  Path to camera.yaml\n"
                << "  -l, --list           List local /dev/video* devices\n";
            std::exit(0);
        }
    }
    return app;
}

class FPSCounter {
public:
    void tick() {
        auto now = std::chrono::steady_clock::now();
        double dt = std::chrono::duration<double>(now - m_last).count();
        m_last = now;
        m_fps  = 0.9 * m_fps + 0.1 * (1.0 / dt);
    }
    double get() const { return m_fps; }
private:
    std::chrono::steady_clock::time_point m_last = std::chrono::steady_clock::now();
    double m_fps = 0.0;
};

// ── Main ──────────────────────────────────────────────────────────────────────

int main(int argc, char** argv) {
    AppConfig app = parseArgs(argc, argv);

    if (app.listCameras) {
        CameraCapture::listAvailableDevices();
        return 0;
    }

#ifdef USE_CUDA
    printCudaDeviceInfo();
    LKConfig lkCfg;      // use defaults — tweak via config later
#else
    std::cout << "[main] CUDA not available — running grayscale CPU mode.\n";
#endif

    CameraConfig camCfg = CameraCapture::fromYaml(app.configPath);
    if (!app.cameraOverride.empty()) {
        try   { camCfg.source = std::stoi(app.cameraOverride); }
        catch (...) { camCfg.source = app.cameraOverride; }
    }

    CameraCapture camera(camCfg);
    if (!camera.open()) {
        std::cerr << "Fatal: cannot open camera.\n";
        return -1;
    }

    cv::namedWindow("Optical Flow", cv::WINDOW_AUTOSIZE);
    cv::Mat   frame, grayFrame, displayFrame;
    FPSCounter fps;

#ifdef USE_CUDA
    cv::cuda::GpuMat d_prev, d_curr, d_vis;
    bool firstFrame = true;
#else
    std::unique_ptr<Filter> filter = std::make_unique<GrayscaleFilter>();
#endif

    while (true) {
        if (!camera.read(frame) || frame.empty()) continue;

#ifdef USE_CUDA
        // Convert to grayscale for the LK algorithm
        cv::cvtColor(frame, grayFrame, cv::COLOR_BGR2GRAY);
        d_curr.upload(grayFrame);

        if (firstFrame) {
            // First frame: nothing to diff against — show blank
            d_curr.copyTo(d_prev);
            displayFrame = frame.clone();
            firstFrame = false;
        } else {
            runLucasKanade(d_prev, d_curr, d_vis, lkCfg);
            d_vis.download(displayFrame);
        }

        // Roll: current becomes previous
        d_curr.copyTo(d_prev);
#else
        displayFrame = filter->apply(frame);
#endif

        fps.tick();
        cv::putText(displayFrame,
                    "FPS: " + std::to_string(static_cast<int>(fps.get())),
                    {10, 30}, cv::FONT_HERSHEY_SIMPLEX, 1.0, {0, 255, 0}, 2);

#ifdef USE_CUDA
        cv::putText(displayFrame, "Lucas-Kanade (CUDA)",
                    {10, 65}, cv::FONT_HERSHEY_SIMPLEX, 0.7, {0, 200, 255}, 2);
#endif

        cv::imshow("Optical Flow", displayFrame);
        char key = static_cast<char>(cv::waitKey(1));
        if (key == 'q' || key == 27) break;
    }

    camera.release();
    cv::destroyAllWindows();
    return 0;
}