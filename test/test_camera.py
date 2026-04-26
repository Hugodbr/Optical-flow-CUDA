#!/usr/bin/env python3
"""
Quick camera sanity-check. Run before the C++ build to confirm
your chosen source is accessible from Python/OpenCV.

Usage:
    python3 test/test_camera.py                        # built-in camera (index 0)
    python3 test/test_camera.py --camera 1             # second camera
    python3 test/test_camera.py --camera http://192.168.1.10:4747/video
    python3 test/test_camera.py --list                 # list /dev/video* devices
"""

import cv2
import argparse
import os
import time


def list_cameras():
    print("\n=== Available /dev/video* devices ===")
    found = False
    for i in range(10):
        dev = f"/dev/video{i}"
        if os.path.exists(dev):
            cap = cv2.VideoCapture(i)
            ok = cap.isOpened()
            cap.release()
            status = "✓ OK" if ok else "✗ not readable"
            print(f"  [{i}] {dev}  {status}")
            found = True
    if not found:
        print("  No /dev/video* devices found.")
    print("=====================================\n")


def run(source):
    # Parse source: int or string
    try:
        src = int(source)
    except (ValueError, TypeError):
        src = source

    print(f"Opening source: {src!r}")
    cap = cv2.VideoCapture(src)

    if not cap.isOpened():
        print("ERROR: Cannot open camera source.")
        return

    w = cap.get(cv2.CAP_PROP_FRAME_WIDTH)
    h = cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
    f = cap.get(cv2.CAP_PROP_FPS)
    print(f"Opened: {w:.0f}x{h:.0f} @ {f:.1f} fps")
    print("Press Q to quit.")

    fps_start = time.time()
    frame_count = 0

    while True:
        ret, frame = cap.read()
        if not ret or frame is None:
            print("Warning: empty frame.")
            continue

        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        output = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

        frame_count += 1
        elapsed = time.time() - fps_start
        fps = frame_count / elapsed if elapsed > 0 else 0

        cv2.putText(output, f"FPS: {fps:.1f}", (10, 30),
                    cv2.FONT_HERSHEY_SIMPLEX, 1.0, (0, 255, 0), 2)

        cv2.imshow("Camera Test - Grayscale", output)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--camera", "-c", default="0",
        help="Camera source: index (0,1) or URL"
    )
    parser.add_argument(
        "--list", "-l", action="store_true",
        help="List available /dev/video* devices"
    )
    args = parser.parse_args()

    if args.list:
        list_cameras()
    else:
        run(args.camera)