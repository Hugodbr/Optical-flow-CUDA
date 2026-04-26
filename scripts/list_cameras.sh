#!/bin/bash
# Quick shell alternative to --list flag
# Also shows camera names via v4l2-ctl

echo "=== /dev/video* devices ==="
for dev in /dev/video*; do
    if [ -e "$dev" ]; then
        idx="${dev//[^0-9]/}"
        name=$(v4l2-ctl --device="$dev" --info 2>/dev/null \
               | grep "Card type" | awk -F: '{print $2}' | xargs)
        echo "  [$idx] $dev  — ${name:-unknown}"
    fi
done
echo ""
echo "Droidcam (if app is running on your phone):"
echo "  HTTP:  http://<phone-ip>:4747/video"
echo "  RTSP:  rtsp://<phone-ip>:4747/h264_ulaw.sdp"
echo ""
echo "Find your phone IP: check Droidcam app screen or run:"
echo "  arp -a | grep -i android"