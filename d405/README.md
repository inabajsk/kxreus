# RealSense D405 colour + depth viewer with parallel vision processing

`d405_viewer.py` reads colour and aligned metric depth from a USB RealSense D405 and runs
9 processors in parallel threads, each on the newest frame:

| `--proc` | what it shows (depth-aware additions in bold) |
|---|---|
| `apriltag` | AprilTag 36h11 IDs, **6-DoF pose (solvePnP, `--tag-size`) and depth distance** |
| `yolo` | YOLO26n detection **with the median depth in each box** |
| `depth` | **the D405 depth in metres** (`--min-depth`/`--max-depth`) |
| `dav2` | Depth Anything V2 **fitted to the D405 depth (scale + shift), filling holes** |
| `floor` | **3D floor plane (RANSAC on the point cloud), obstacles, top-down grid, path in cm** |
| `sam2` | SAM2.1 masks (YOLO boxes as prompts) **with distances** |
| `detr` | DETR ResNet-50 detection **with distances** |
| `dino` | DINOv2-small patch-feature PCA |
| `mediapipe` | MediaPipe Holistic pose / hands / face parts, **face distance and a metric 3D gaze ray** |
| `gdino` | (optional) Grounding DINO tiny with distances |

```bash
# first time: venv sharing the system torch / cv2 / pyrealsense2
python3 -m venv --system-site-packages .venv
.venv/bin/pip install ultralytics transformers mediapipe "torch==2.4.1" "numpy<2"

source ~/kxreus/d405/alias.bash
d405              # all processors
d405-floor        # depth + floor + path
d405-tag          # AprilTag pose + YOLO
d405-mp           # MediaPipe + 3D gaze
d405-rec          # record 60 s to rec/
```

Windows: "D405" (colour | depth with capture time, receive interval, latency) and
"Processing" (colour over depth on the left, processor tiles on the right).
Keys: `q`/ESC quit, `s` snapshot, `r` rotate 90°.

This tree is independent of the M5Camera version in `~/kxreus/m5stack/m5camera`.
