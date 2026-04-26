# Ubuntu PC Setup

## 1. Install dependencies
```bash
bash scripts/install_deps.sh
```

## 2. List available cameras
```bash
bash scripts/list_cameras.sh
# or after building:
./build/optical_flow --list
```

## 3. Connect Droidcam (WiFi camera)
1. Install **Droidcam** on your Android/iOS phone
2. Open the app — it shows an IP and port (e.g. `192.168.1.42:4747`)
3. Use either:
   - HTTP MJPEG:  `http://192.168.1.42:4747/video`
   - RTSP:        `rtsp://192.168.1.42:4747/h264_ulaw.sdp`

## 4. Build and run
```bash
bash scripts/build.sh

# Built-in camera
./build/optical_flow --camera 0

# Droidcam over WiFi
./build/optical_flow --camera http://192.168.1.42:4747/video

# From config file
./build/optical_flow --config config/camera.yaml
```

## 5. Python quick-test (no build needed)
```bash
python3 test/test_camera.py --list
python3 test/test_camera.py --camera 0
python3 test/test_camera.py --camera http://192.168.1.42:4747/video
```