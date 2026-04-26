#include <iostream>

#include <opencv2/opencv.hpp>


int main() {
    cv::VideoCapture cap(0); // 0 = first camera
    if (!cap.isOpened()) {
        std::cerr << "Error: cannot open camera\n";
        return -1;
    }

    // Optional: set resolution
    cap.set(cv::CAP_PROP_FRAME_WIDTH, 1280);
    cap.set(cv::CAP_PROP_FRAME_HEIGHT, 720);

    cv::Mat frame, gray;
    std::string window = "Optical Flow - Camera Test";
    cv::namedWindow(window, cv::WINDOW_AUTOSIZE);

    while (true) {
        cap >> frame;
        if (frame.empty()) break;

        cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);

        // Later: this is where CUDA processing will plug in
        // cv::cuda::GpuMat d_frame(gray);
        // lucasKanade(d_frame, ...);

        cv::imshow(window, gray);
        if (cv::waitKey(1) == 'q') break;
    }

    cap.release();
    cv::destroyAllWindows();
    return 0;
}