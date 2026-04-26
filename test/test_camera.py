import cv2

cap = cv2.VideoCapture(0)  # or "/dev/video0"
assert cap.isOpened(), "Cannot open camera"

while True:
    ret, frame = cap.read()
    if not ret:
        break

    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    # Convert back to BGR so imshow renders correctly
    gray_bgr = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

    cv2.imshow("Camera - Grayscale", gray_bgr)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()