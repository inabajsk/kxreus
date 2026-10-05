# M5Camera Wi-Fi viewer + vision processing

- `firmware/` — PlatformIO firmware for M5Camera (ESP32 + OV2640 + PSRAM). Streams JPEG over TCP:8000, UDP:8001 for clock sync, UDP:8002 for the discovery beacon. The pinout (A/B) is detected automatically.
- `provision_wifi.py` — writes Wi-Fi settings to the device's NVS over serial (the ESP32 supports **2.4 GHz only**)
- `m5camera_viewer.py` — PC-side viewer + one thread per processor

```bash
# Firmware
cd firmware && pio run -t upload --upload-port /dev/ttyUSB1 && cd ..
./provision_wifi.py /dev/ttyUSB1 JSK300 '<password>'   # without arguments, uses the PC's current Wi-Fi

# Environment (first time only; reuses the system torch/cv2)
python3 -m venv --system-site-packages .venv
.venv/bin/pip install ultralytics transformers mediapipe "torch==2.4.1" "numpy<2"

# Run (camera found automatically via the UDP beacon)
.venv/bin/python m5camera_viewer.py
.venv/bin/python m5camera_viewer.py --proc depth,floor --robot-width 0.4
.venv/bin/python m5camera_viewer.py --proc apriltag,yolo --framesize 9   # SVGA
.venv/bin/python m5camera_viewer.py --rotate 90                         # mounted upright on a KXR head
.venv/bin/python m5camera_viewer.py --record rec/ --duration 60         # record both windows to mp4
```

The Processing window shows the input image on the left and the processor tiles on the right (`--cols`, `--tile-height`).

Processors (`--proc`): `apriltag` (cv2.aruco 36h11), `yolo` (YOLO26n → yolo11n),
`depth` (Depth Anything V2 Small), `floor` (floor plane + path from depth),
`sam2` (SAM2.1-tiny, prompted with YOLO boxes / a 3x3 point grid), `detr` (DETR R50),
`dino` (DINOv2-small feature PCA), `mediapipe` (MediaPipe Holistic: body, hand and finger skeletons, face parts, 3D gaze rays), `gdino` (Grounding DINO tiny, not in the default set; runs out of memory on a 2 GB GPU when used alongside the others).

Keys: `q`/ESC quit, `s` save snapshot to `snapshots/`, `r` rotate 90°.

`factory_backup/m5camera_factory_4MB.bin` is the factory firmware (restore with
`esptool.py --port /dev/ttyUSB1 write_flash 0 factory_backup/m5camera_factory_4MB.bin`).


Aliases: `source ~/kxreus/m5stack/m5camera/alias.bash` (m5cam, m5cam-kxr, m5cam-floor, m5cam-mp, ...).
