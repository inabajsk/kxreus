# RealSense D405 viewer aliases.   source ~/kxreus/d405/alias.bash
# Extra options can be appended to any of them, e.g.  d405 --rotate 180 --filter

D405_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D405_PY="$D405_DIR/.venv/bin/python $D405_DIR/d405_viewer.py"

# viewer
alias d405="$D405_PY"                                              # all 9 processors
alias d405-floor="$D405_PY --proc depth,floor"                     # sensor depth + 3D floor plane + path
alias d405-tag="$D405_PY --proc apriltag,yolo,depth"               # AprilTag pose + YOLO distances
alias d405-mp="$D405_PY --proc mediapipe,depth --cols 2 --tile-height 360"   # skeleton / face / 3D gaze
alias d405-depth="$D405_PY --proc depth,dav2 --cols 2 --tile-height 360"     # sensor depth vs fitted DA-V2
alias d405-rec="$D405_PY --record $D405_DIR/rec --duration 60"     # record 60 s to rec/
alias d405-help="$D405_PY --help"

# device check
alias d405-list="python3 -c 'import pyrealsense2 as rs; [print(d.get_info(rs.camera_info.name), d.get_info(rs.camera_info.serial_number), \"USB\", d.get_info(rs.camera_info.usb_type_descriptor)) for d in rs.context().devices] or print(\"no RealSense found\")'"

alias d405-cd="cd $D405_DIR"
