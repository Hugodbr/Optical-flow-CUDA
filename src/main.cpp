#include <iostream>
#include <string>
#include <memory>
#include <chrono>

#include <opencv2/opencv.hpp>

#include "camera/CameraCapture.h"
#include "filters/Filter.h"
#include "filters/GrayscaleFilter.h"

// ── CLI args parser ───────────────────────────────────────────────────────────

struct AppConfig {
    std::string configPath = "config/camera.yaml";
    std::string cameraOverride;     // overrides config file if set
    bool listCameras = false;
};

AppConfig parseArgs(int argc, char** argv) {
    AppConfig app;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];

        if ((arg == "--camera" || arg == "-c") && i + 1 < argc) {
            app.cameraOverride = argv[++i];

        } else if ((arg == "--config" || arg == "-f") && i + 1 < argc) {
            app.configPath = argv[++i];

        } else if (arg == "--list" || arg == "-l") {
            app.listCameras = true;

        } else if (arg == "--help" || arg == "-h") {
            std::cout
                << "Usage: optical_flow [options]\n"
                << "  -c, --camera <src>   Camera source: index (0,1) or URL\n"
                << "                       Examples:\n"
                << "                         --camera 0          (built-in)\n"
                << "                         --camera 1          (USB)\n"
                << "                         --camera http://192.168.1.10:4747/video\n"
                << "                         --camera rtsp://192.168.1.10:4747/h264_ulaw.sdp\n"
                << "  -f, --config <path>  Path to camera.yaml (default: config/camera.yaml)\n"
                << "  -l, --list           List available local camera devices\n"
                << "  -h, --help           Show this message\n";
            std::exit(0);
        }
    }
    return app;
}

// ── FPS counter ───────────────────────────────────────────────────────────────

class FPSCounter {
public:
    void tick() {
        auto now = std::chrono::steady_clock::now();
        double dt = std::chrono::duration<double>(now - m_last).count();
        m_last = now;
        m_fps  = 0.9 * m_fps + 0.1 * (1.0 / dt);  // exponential smoothing
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

    // Load config from YAML, then apply CLI override if given
    CameraConfig camCfg = CameraCapture::fromYaml(app.configPath);

    if (!app.cameraOverride.empty()) {
        // Try to parse as integer index first, otherwise treat as URL
        try {
            camCfg.source = std::stoi(app.cameraOverride);
        } catch (...) {
            camCfg.source = app.cameraOverride;
        }
    }

    // Open camera
    CameraCapture camera(camCfg);
    if (!camera.open()) {
        std::cerr << "Fatal: cannot open camera. Run with --list to see devices.\n";
        return -1;
    }

    // Active filter — swap this out for Lucas-Kanade later
    std::unique_ptr<Filter> filter = std::make_unique<GrayscaleFilter>();
    std::cout << "Active filter: " << filter->name() << "\n";

    cv::namedWindow("Optical Flow", cv::WINDOW_AUTOSIZE);
    cv::Mat frame;
    FPSCounter fps;

    while (true) {
        if (!camera.read(frame) || frame.empty()) {
            std::cerr << "Warning: empty frame received.\n";
            continue;
        }

        cv::Mat output = filter->apply(frame);

        fps.tick();

        // Overlay FPS
        std::string fpsText = "FPS: " + std::to_string(static_cast<int>(fps.get()));
        cv::putText(output, fpsText, {10, 30},
                    cv::FONT_HERSHEY_SIMPLEX, 1.0, {0, 255, 0}, 2);

        cv::imshow("Optical Flow", output);

        char key = static_cast<char>(cv::waitKey(1));
        if (key == 'q' || key == 27) break;   // q or ESC to quit
    }

    camera.release();
    cv::destroyAllWindows();
    return 0;
}