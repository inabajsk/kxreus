#!/usr/bin/env python3
"""M5Camera Wi-Fi viewer + parallel vision processing.

Window "M5Camera": the received image, its capture time (device clock mapped
to this PC's clock), the receive interval and the capture->receive latency.

Window "Processing": one tile per processor, each running in its own thread
on the newest received frame (frames that arrive while a processor is busy are
skipped, not queued). Each tile shows inference time, output period and the
age of the frame it was computed from.

    .venv/bin/python m5camera_viewer.py                       # auto-discover, all processors
    .venv/bin/python m5camera_viewer.py --host 192.168.1.61 --proc apriltag,yolo,depth
    .venv/bin/python m5camera_viewer.py --proc depth,floor --robot-width 0.4
    .venv/bin/python m5camera_viewer.py --proc gdino --gdino-text "a person. a cup."

Keys (either window): q/ESC quit, s save snapshot, r rotate 90deg.
Firmware protocol: see firmware/src/main.cpp.
"""
import argparse
import datetime
import os
import socket
import struct
import threading
import time
import traceback
from collections import deque
from pathlib import Path

import cv2
import numpy as np

HERE = Path(__file__).resolve().parent
WEIGHTS = HERE / "weights"
TCP_PORT, SYNC_PORT, BEACON_PORT = 8000, 8001, 8002
FONT = cv2.FONT_HERSHEY_SIMPLEX


def now_us():
    return time.time_ns() // 1000


def fmt_time(us):
    return datetime.datetime.fromtimestamp(us / 1e6).strftime("%H:%M:%S.%f")[:-3]


def put_lines(img, lines, org=(6, 6), scale=0.5, color=(255, 255, 255)):
    """Text on a dark box, top-left, one entry per line."""
    if not lines:
        return img
    th = int(22 * scale / 0.5)
    w = max(cv2.getTextSize(s, FONT, scale, 1)[0][0] for s in lines) + 10
    x, y = org
    sub = img[y:y + th * len(lines) + 6, x:x + w]
    sub[:] = (sub * 0.35).astype(np.uint8)
    for i, s in enumerate(lines):
        cv2.putText(img, s, (x + 5, y + th * (i + 1) - 4), FONT, scale, color, 1, cv2.LINE_AA)
    return img


def discover(timeout=5.0):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("", BEACON_PORT))
    s.settimeout(timeout)
    try:
        while True:
            data, (ip, _) = s.recvfrom(128)
            if data.startswith(b"M5CAM "):
                return ip
    except socket.timeout:
        pass
    finally:
        s.close()
    try:
        return socket.gethostbyname("m5camera.local")
    except OSError:
        return None


class TimeSync(threading.Thread):
    """NTP-style offset between the device's esp_timer and this PC's clock.

    Keeps the minimum-RTT sample of a sliding window: that one's midpoint
    assumption is least wrong.
    """

    def __init__(self, host):
        super().__init__(daemon=True)
        self.host = host
        self.samples = deque(maxlen=30)
        self.offset_us = None
        self.rtt_us = None

    def run(self):
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.settimeout(0.5)
        while True:
            t0 = now_us()
            try:
                sock.sendto(b"PING" + struct.pack("<q", t0), (self.host, SYNC_PORT))
                data, _ = sock.recvfrom(64)
            except OSError:
                time.sleep(0.5)
                continue
            t1 = now_us()
            if len(data) == 20 and data[:4] == b"PONG":
                echo, esp = struct.unpack("<qq", data[4:])
                if echo == t0:
                    self.samples.append((t1 - t0, (t0 + t1) // 2 - esp))
                    self.rtt_us, self.offset_us = min(self.samples)
            time.sleep(0.2 if len(self.samples) < 10 else 1.0)

    def to_pc(self, esp_us):
        return None if self.offset_us is None else esp_us + self.offset_us


class Frame:
    __slots__ = ("seq", "img", "jpeg_len", "cap_us", "recv_us", "interval_ms", "cap_interval_ms")


class Receiver(threading.Thread):
    def __init__(self, host, sync, rotate_ref, framesize=None, quality=None):
        super().__init__(daemon=True)
        self.host, self.sync, self.rotate_ref = host, sync, rotate_ref
        self.framesize, self.quality = framesize, quality
        self.cond = threading.Condition()
        self.latest = None
        self.status = "connecting"
        self.fps = 0.0

    def run(self):
        while True:
            try:
                self._stream()
            except (OSError, ValueError) as e:
                self.status = f"reconnecting ({e})"
                time.sleep(1.0)

    def _stream(self):
        sock = socket.create_connection((self.host, TCP_PORT), timeout=5)
        sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        if self.framesize is not None:
            sock.sendall(f"fs {self.framesize}\n".encode())
        if self.quality is not None:
            sock.sendall(f"q {self.quality}\n".encode())
        f = sock.makefile("rb")
        self.status = "streaming"
        last_recv = last_cap = None
        while True:
            hdr = f.read(28)
            if len(hdr) < 28:
                raise ValueError("connection closed")
            magic, seq, cap, _send, length = struct.unpack("<4sIqqI", hdr)
            if magic != b"M5CF" or length > 2_000_000:
                raise ValueError("bad header")
            jpeg = f.read(length)
            recv = now_us()
            img = cv2.imdecode(np.frombuffer(jpeg, np.uint8), cv2.IMREAD_COLOR)
            if img is None:
                continue
            rot = self.rotate_ref[0]
            if rot:
                img = cv2.rotate(img, {90: cv2.ROTATE_90_CLOCKWISE, 180: cv2.ROTATE_180,
                                       270: cv2.ROTATE_90_COUNTERCLOCKWISE}[rot])
            fr = Frame()
            fr.seq, fr.img, fr.jpeg_len, fr.recv_us = seq, img, length, recv
            fr.cap_us = self.sync.to_pc(cap)
            fr.interval_ms = (recv - last_recv) / 1000 if last_recv else 0.0
            fr.cap_interval_ms = (cap - last_cap) / 1000 if last_cap else 0.0
            last_recv, last_cap = recv, cap
            if fr.interval_ms > 0:
                self.fps = 0.9 * self.fps + 0.1 * (1000 / fr.interval_ms) if self.fps else 1000 / fr.interval_ms
            with self.cond:
                self.latest = fr
                self.cond.notify_all()

    def wait_newer(self, seq, timeout=1.0):
        with self.cond:
            self.cond.wait_for(lambda: self.latest is not None and self.latest.seq != seq, timeout)
            return self.latest


# --------------------------------------------------------------------------
# Processors. Each runs in its own thread: load() once, then process(bgr) ->
# annotated bgr on every newest frame.

class Processor(threading.Thread):
    name = "base"
    LOAD_LOCK = threading.Lock()

    def __init__(self, receiver, args, shared):
        super().__init__(daemon=True)
        self.rx, self.args, self.shared = receiver, args, shared
        self.device = args.device
        self.result = None
        self.status = "waiting"
        self.infer_ms = 0.0
        self.period_ms = 0.0
        self.age_ms = 0.0
        self.src_seq = -1

    def load(self):
        pass

    def process(self, img):
        raise NotImplementedError

    def process_frame(self, fr):
        return self.process(fr.img)

    def next_input(self, seq):
        """Newest frame whose seq differs from `seq` (None on timeout)."""
        return self.rx.wait_newer(seq)

    def run(self):
        self.status = "loading model..."
        try:
            # one at a time: concurrent from_pretrained() calls race inside
            # transformers, and serial loading keeps the GPU memory peak down
            with Processor.LOAD_LOCK:
                self.load()
        except Exception as e:  # noqa: BLE001 - shown in the tile
            traceback.print_exc()
            self.status = f"load failed: {e}"
            return
        self.status = "running"
        seq, last_done = -1, None
        while True:
            fr = self.next_input(seq)
            if fr is None or fr.seq == seq:
                continue
            seq = fr.seq
            t0 = time.perf_counter()
            try:
                out = self.process_frame(fr)
            except Exception as e:  # noqa: BLE001
                traceback.print_exc()
                self.status = f"error: {e}"
                time.sleep(1.0)
                continue
            t1 = time.perf_counter()
            self.infer_ms = (t1 - t0) * 1000
            if last_done is not None:
                p = (t1 - last_done) * 1000
                self.period_ms = 0.8 * self.period_ms + 0.2 * p if self.period_ms else p
            last_done = t1
            self.age_ms = (now_us() - (fr.cap_us or fr.recv_us)) / 1000
            self.src_seq = fr.seq
            self.result = out
            self.status = "running"

    def tile(self, w, h):
        img = np.zeros((h, w, 3), np.uint8) if self.result is None else cv2.resize(self.result, (w, h))
        hz = 1000 / self.period_ms if self.period_ms else 0
        lines = [self.name,
                 f"infer {self.infer_ms:6.1f} ms  period {self.period_ms:6.1f} ms ({hz:4.1f} Hz)",
                 f"frame #{self.src_seq}  age {self.age_ms:6.0f} ms  [{self.device}]"]
        if self.status != "running":
            lines.append(self.status[:70])
        return put_lines(img, lines, scale=0.45)


class TorchProcessor(Processor):
    def pick_device(self):
        import torch
        if self.device.startswith("cuda") and not torch.cuda.is_available():
            self.device = "cpu"
        return self.device

    def to_device(self, model):
        """Move to the GPU, falling back to CPU if the 2 GB card is full."""
        import torch
        self.pick_device()
        try:
            return model.to(self.device).eval()
        except torch.cuda.OutOfMemoryError:
            torch.cuda.empty_cache()
            self.device = "cpu"
            return model.to("cpu").eval()


class AprilTagProc(Processor):
    name = "AprilTag (36h11)"

    def load(self):
        self.device = "cpu"
        fams = {"36h11": cv2.aruco.DICT_APRILTAG_36h11, "25h9": cv2.aruco.DICT_APRILTAG_25h9,
                "16h5": cv2.aruco.DICT_APRILTAG_16h5, "36h10": cv2.aruco.DICT_APRILTAG_36h10}
        fam = self.args.tag_family
        self.name = f"AprilTag ({fam})"
        params = cv2.aruco.DetectorParameters()
        params.cornerRefinementMethod = cv2.aruco.CORNER_REFINE_APRILTAG
        self.det = cv2.aruco.ArucoDetector(cv2.aruco.getPredefinedDictionary(fams[fam]), params)

    def process(self, img):
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        corners, ids, _ = self.det.detectMarkers(gray)
        out = img.copy()
        if ids is not None:
            cv2.aruco.drawDetectedMarkers(out, corners, ids)
            for c, i in zip(corners, ids.flatten()):
                cx, cy = c[0].mean(axis=0).astype(int)
                cv2.putText(out, f"id={i}", (cx - 20, cy), FONT, 0.7, (0, 255, 255), 2, cv2.LINE_AA)
        self.shared["tags"] = 0 if ids is None else len(ids)
        return out


class YoloProc(TorchProcessor):
    name = "YOLO"

    def load(self):
        from ultralytics import YOLO
        WEIGHTS.mkdir(exist_ok=True)
        last = None
        for w in self.args.yolo.split(","):
            try:
                self.model = YOLO(str(WEIGHTS / w))
                self.name = f"YOLO ({Path(w).stem})"
                break
            except Exception as e:  # noqa: BLE001 - try the next candidate
                last = e
        else:
            raise last
        self.pick_device()

    def process(self, img):
        r = self.model.predict(img, device=self.device, verbose=False, imgsz=self.args.imgsz, conf=0.35)[0]
        self.shared["yolo_boxes"] = (time.time(), r.boxes.xyxy.cpu().numpy())
        return r.plot()


class DepthProc(TorchProcessor):
    name = "Depth Anything V2 (S)"

    def load(self):
        import torch
        from transformers import AutoImageProcessor, AutoModelForDepthEstimation
        mid = self.args.depth_model
        self.name = f"Depth ({mid.split('/')[-1]})"
        self.proc = AutoImageProcessor.from_pretrained(mid)
        self.model = self.to_device(AutoModelForDepthEstimation.from_pretrained(mid))
        self.torch = torch

    def process_frame(self, fr):
        img = fr.img
        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        n = self.args.depth_size
        inp = self.proc(images=rgb, return_tensors="pt", size={"height": n, "width": n},
                        keep_aspect_ratio=True, ensure_multiple_of=14).to(self.device)
        with self.torch.inference_mode():
            d = self.model(**inp).predicted_depth[0].float().cpu().numpy()
        d = cv2.resize(d, (img.shape[1], img.shape[0]))
        d = (d - d.min()) / (d.max() - d.min() + 1e-6)  # relative disparity, near = 1
        # Hand the disparity to FloorProc together with the frame it came from.
        with self.shared["depth_cond"]:
            self.shared["depth"] = (fr, d)
            self.shared["depth_cond"].notify_all()
        return cv2.applyColorMap((d * 255).astype(np.uint8), cv2.COLORMAP_INFERNO)


class FloorProc(Processor):
    """Floor plane from the Depth thread's disparity map, plus a path across it.

    Depth Anything's output is disparity up to an unknown scale and shift,
    d = s/Z + t. For a plane in 3D, 1/Z is affine in pixel coordinates, so
    that stays true of d: the floor is the plane d = a*u + b*v + c in
    (u, v, d). RANSAC fits it on the lower part of the image (where the floor
    is if the camera looks forward), and the floor region is every pixel
    within a relative tolerance of it, connected to the bottom edge.

    The path is Dijkstra on that mask, from the bottom centre (the robot) to
    the farthest reachable floor cell, penalising cells whose clearance to
    the floor's edge is less than the robot's apparent half width there
    (apparent size is proportional to disparity).
    """
    name = "Floor plane + path (from depth)"
    GRID_W = 96

    def load(self):
        self.device = "cpu"
        self.rng = np.random.default_rng(0)
        self.plane = None

    def next_input(self, seq):
        cond = self.shared["depth_cond"]
        with cond:
            cond.wait_for(lambda: self.shared.get("depth") is not None and self.shared["depth"][0].seq != seq, 1.0)
            dep = self.shared.get("depth")
        if dep is None:
            return None
        self._depth = dep[1]
        return dep[0]

    # --- plane fit -------------------------------------------------------
    def fit_plane(self, d):
        h, w = d.shape
        vs, us = np.mgrid[0:h, 0:w]
        roi = vs > h * (1 - self.args.floor_roi)
        U, V, D = us[roi].astype(np.float32), vs[roi].astype(np.float32), d[roi]
        A = np.stack([U, V, np.ones_like(U)], 1)
        tol = self.args.floor_tol
        best, best_n = None, 0
        cands = [self.plane] if self.plane is not None else []
        for _ in range(150):
            idx = self.rng.choice(len(D), 3, replace=False)
            try:
                cands.append(np.linalg.solve(A[idx], D[idx]))
            except np.linalg.LinAlgError:
                continue
        for p in cands:
            # floor: nearer (larger disparity) further down the image, and in front of the camera
            if p[1] <= 0:
                continue
            pred = A @ p
            n = np.count_nonzero(np.abs(D - pred) < tol * np.maximum(pred, 0.05))
            if n > best_n:
                best, best_n = p, n
        if best is None or best_n < 0.15 * len(D):
            return None, best_n / max(len(D), 1)
        pred = A @ best
        inl = np.abs(D - pred) < tol * np.maximum(pred, 0.05)
        best = np.linalg.lstsq(A[inl], D[inl], rcond=None)[0]
        return best, best_n / len(D)

    # --- path ------------------------------------------------------------
    @staticmethod
    def dijkstra(cost, start):
        import heapq
        h, w = cost.shape
        dist = np.full((h, w), np.inf)
        prev = -np.ones((h, w), np.int64)
        dist[start] = 0.0
        pq = [(0.0, start[0], start[1])]
        nb = [(-1, 0, 1.0), (0, -1, 1.0), (0, 1, 1.0), (1, 0, 1.0),
              (-1, -1, 1.414), (-1, 1, 1.414), (1, -1, 1.414), (1, 1, 1.414)]
        while pq:
            dc, y, x = heapq.heappop(pq)
            if dc > dist[y, x]:
                continue
            for dy, dx, step in nb:
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and np.isfinite(cost[ny, nx]):
                    nd = dc + step * cost[ny, nx]
                    if nd < dist[ny, nx]:
                        dist[ny, nx] = nd
                        prev[ny, nx] = y * w + x
                        heapq.heappush(pq, (nd, ny, nx))
        return dist, prev

    def plan(self, floor, plane_d):
        """Path on a coarse grid; returns list of (u, v) in grid coords."""
        h, w = floor.shape
        # clearance to the floor's edge; the bottom image border is where the
        # robot stands, not an obstacle, so it is padded with floor instead.
        padded = np.pad(floor, 1).astype(np.uint8)
        padded[-1, 1:-1] = floor[-1]
        clear = cv2.distanceTransform(padded, cv2.DIST_L2, 3)[1:-1, 1:-1]
        start = (h - 1, w // 2)
        ref = max(plane_d[start], 1e-3)
        halfw = 0.5 * self.args.robot_width * w * plane_d / ref  # apparent half width (grid px)
        ok = floor & (clear >= 0.5 * halfw)
        if not ok[start]:
            ys, xs = np.nonzero(ok[h - 3:])
            if len(xs) == 0:
                return None, halfw
            i = np.argmin(np.abs(xs - w // 2))
            start = (h - 3 + ys[i], xs[i])
        cost = np.where(ok, 1.0 + 4.0 * np.clip(1.0 - clear / (2 * halfw + 1e-6), 0, 1), np.inf)
        dist, prev = self.dijkstra(cost, start)
        reach = np.isfinite(dist)
        if reach.sum() < 5:
            return None, halfw
        # goal: farthest along the floor (smallest disparity), mildly preferring straight ahead
        score = np.where(reach, plane_d / ref + 0.3 * np.abs(np.arange(w) - w / 2)[None] / w, np.inf)
        gy, gx = np.unravel_index(np.argmin(score), score.shape)
        path, k = [], gy * w + gx
        while k >= 0:
            path.append((k % w, k // w))
            k = prev[k // w, k % w]
        path = np.array(path[::-1], np.float32)
        if len(path) > 5:  # smooth the 8-connected staircase
            ker = np.ones(5) / 5
            pad = np.pad(path, ((2, 2), (0, 0)), mode="edge")
            path = np.stack([np.convolve(pad[:, i], ker, "valid") for i in range(2)], 1)
        return path, halfw

    def process_frame(self, fr):
        img, d = fr.img, self._depth
        H, W = img.shape[:2]
        gw = self.GRID_W
        gh = max(8, round(gw * H / W))
        ds = cv2.resize(d, (gw, gh), interpolation=cv2.INTER_AREA)
        plane, ratio = self.fit_plane(ds)
        out = img.copy()
        if plane is None:
            self.plane = None
            cv2.putText(out, f"no floor plane (inliers {ratio:.0%})", (10, H - 12), FONT, 0.7, (0, 0, 255), 2)
            return out
        self.plane = plane
        vs, us = np.mgrid[0:gh, 0:gw].astype(np.float32)
        plane_d = plane[0] * us + plane[1] * vs + plane[2]
        floor = (np.abs(ds - plane_d) < self.args.floor_tol * np.maximum(plane_d, 0.05)) & (plane_d > 0)
        floor = cv2.morphologyEx(floor.astype(np.uint8), cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
        n, lab = cv2.connectedComponents(floor)
        bottom = lab[-2:][lab[-2:] > 0]
        if len(bottom) == 0:
            cv2.putText(out, "floor not connected to robot", (10, H - 12), FONT, 0.7, (0, 0, 255), 2)
            return out
        floor = lab == np.bincount(bottom).argmax()
        path, halfw = self.plan(floor, plane_d)

        # floor region: green tint + outline
        fm = cv2.resize(floor.astype(np.uint8), (W, H), interpolation=cv2.INTER_NEAREST).astype(bool)
        tint = out.copy()
        tint[fm] = (0.4 * tint[fm] + 0.6 * np.array([60, 200, 60])).astype(np.uint8)
        out = cv2.addWeighted(tint, 0.8, out, 0.2, 0)
        cs, _ = cv2.findContours(fm.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        cv2.drawContours(out, cs, -1, (0, 255, 0), 2)
        # horizon: where the fitted plane's disparity reaches 0 (t assumed ~0)
        sx, sy = W / gw, H / gh
        a, b, c = plane[0] / sx, plane[1] / sy, plane[2]
        vh0, vh1 = -(c + a * 0) / b, -(c + a * W) / b
        if -H < min(vh0, vh1) and max(vh0, vh1) < 2 * H:
            cv2.line(out, (0, int(vh0)), (W, int(vh1)), (255, 255, 0), 1, cv2.LINE_AA)

        if path is not None and len(path) > 1:
            pts = path * [sx, sy]
            # ribbon: robot footprint swept along the path, magenta, width ~ apparent size
            hw_img = np.array([halfw[min(int(y), gh - 1), min(int(x), gw - 1)] * sx for x, y in path])
            tang = np.gradient(pts, axis=0)
            tang /= np.linalg.norm(tang, axis=1, keepdims=True) + 1e-6
            nrm = np.stack([-tang[:, 1], tang[:, 0]], 1)
            poly = np.vstack([pts + nrm * hw_img[:, None], (pts - nrm * hw_img[:, None])[::-1]]).astype(np.int32)
            rib = out.copy()
            cv2.fillPoly(rib, [poly], (200, 40, 220))
            out = cv2.addWeighted(rib, 0.35, out, 0.65, 0)
            # centre line, coloured near (red) -> far (yellow), with relative-distance ticks
            pd = np.array([plane_d[min(int(y), gh - 1), min(int(x), gw - 1)] for x, y in path])
            z = pd[0] / np.maximum(pd, 1e-3)  # depth relative to the robot's own position
            for i in range(len(pts) - 1):
                t = min(1.0, (z[i] - 1) / max(z[-1] - 1, 1e-3))
                col = (0, int(255 * t), 255)
                th = max(2, int(6 * pd[i] / pd[0]))
                cv2.line(out, tuple(pts[i].astype(int)), tuple(pts[i + 1].astype(int)), col, th, cv2.LINE_AA)
            for zt in np.arange(2, z[-1], 1.0):
                i = int(np.argmax(z >= zt))
                cv2.circle(out, tuple(pts[i].astype(int)), 5, (255, 255, 255), -1)
                cv2.putText(out, f"x{zt:.0f}", tuple((pts[i] + [8, 4]).astype(int)), FONT, 0.45, (255, 255, 255), 1)
            cv2.circle(out, tuple(pts[0].astype(int)), 8, (0, 0, 255), -1)
            cv2.drawMarker(out, tuple(pts[-1].astype(int)), (0, 255, 255), cv2.MARKER_STAR, 22, 2)
            info = f"floor {fm.mean():.0%} of image, inliers {ratio:.0%}, goal at x{z[-1]:.1f} start depth"
        else:
            info = f"floor {fm.mean():.0%}, inliers {ratio:.0%}, no traversable path"
        cv2.putText(out, info, (8, H - 10), FONT, 0.5, (255, 255, 255), 1, cv2.LINE_AA)
        return out


class Sam2Proc(TorchProcessor):
    """SAM 2.1 prompted with the YOLO thread's latest boxes, else a point grid."""
    name = "SAM2"

    def load(self):
        from ultralytics import SAM
        WEIGHTS.mkdir(exist_ok=True)
        self.model = SAM(str(WEIGHTS / self.args.sam2))
        self.name = f"SAM2 ({Path(self.args.sam2).stem})"
        self.pick_device()
        self.rng = np.random.default_rng(0)
        self.colors = self.rng.integers(60, 255, (64, 3))

    def process(self, img):
        h, w = img.shape[:2]
        boxes = self.shared.get("yolo_boxes")
        kw = {}
        if boxes is not None and time.time() - boxes[0] < 1.0 and len(boxes[1]):
            kw["bboxes"] = boxes[1].tolist()
            mode = "prompt: YOLO boxes"
        else:
            g = [[w * (i + 1) / 4, h * (j + 1) / 4] for j in range(3) for i in range(3)]
            kw["points"], kw["labels"] = g, [1] * len(g)
            mode = "prompt: 3x3 points"
        r = self.model.predict(img, device=self.device, verbose=False, imgsz=self.args.sam_imgsz, **kw)[0]
        out = img.copy()
        if r.masks is not None:
            masks = r.masks.data.cpu().numpy().astype(bool)
            overlay = out.copy()
            for k, m in enumerate(masks):
                if m.shape != (h, w):
                    m = cv2.resize(m.astype(np.uint8), (w, h)) > 0
                overlay[m] = self.colors[k % len(self.colors)]
                cs, _ = cv2.findContours(m.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
                cv2.drawContours(out, cs, -1, (255, 255, 255), 1)
            out = cv2.addWeighted(overlay, 0.5, out, 0.5, 0)
        if "points" in kw:
            for x, y in kw["points"]:
                cv2.circle(out, (int(x), int(y)), 4, (0, 255, 0), -1)
        cv2.putText(out, mode, (6, h - 10), FONT, 0.6, (0, 255, 0), 2, cv2.LINE_AA)
        return out


def draw_dets(img, boxes, labels, scores, color=(0, 200, 255)):
    out = img.copy()
    for (x0, y0, x1, y1), lab, s in zip(boxes, labels, scores):
        p0, p1 = (int(x0), int(y0)), (int(x1), int(y1))
        cv2.rectangle(out, p0, p1, color, 2)
        txt = f"{lab} {s:.2f}"
        (tw, th), _ = cv2.getTextSize(txt, FONT, 0.55, 1)
        cv2.rectangle(out, (p0[0], p0[1] - th - 6), (p0[0] + tw + 4, p0[1]), color, -1)
        cv2.putText(out, txt, (p0[0] + 2, p0[1] - 4), FONT, 0.55, (0, 0, 0), 1, cv2.LINE_AA)
    return out


class DetrProc(TorchProcessor):
    name = "DETR (resnet-50)"

    def load(self):
        import torch
        from transformers import DetrForObjectDetection, DetrImageProcessor
        mid = "facebook/detr-resnet-50"
        # "no_timm" revision: torchvision backbone, so no timm dependency.
        self.proc = DetrImageProcessor.from_pretrained(mid, revision="no_timm")
        self.model = self.to_device(DetrForObjectDetection.from_pretrained(mid, revision="no_timm"))
        self.torch = torch

    def process(self, img):
        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        inp = self.proc(images=rgb, return_tensors="pt", size={"shortest_edge": self.args.detr_size,
                                                               "longest_edge": 1333}).to(self.device)
        with self.torch.inference_mode():
            outs = self.model(**inp)
        r = self.proc.post_process_object_detection(outs, threshold=0.7, target_sizes=[img.shape[:2]])[0]
        labels = [self.model.config.id2label[int(i)] for i in r["labels"]]
        return draw_dets(img, r["boxes"].cpu().numpy(), labels, r["scores"].cpu().numpy())


class DinoProc(TorchProcessor):
    """DINOv2 patch features, first three PCA components shown as RGB."""
    name = "DINOv2 (S) PCA"

    def load(self):
        import torch
        from transformers import AutoModel
        mid = self.args.dino_model
        self.name = f"DINOv2 PCA ({mid.split('/')[-1]})"
        self.model = self.to_device(AutoModel.from_pretrained(mid))
        self.torch = torch
        self.mean = np.array([0.485, 0.456, 0.406], np.float32)
        self.std = np.array([0.229, 0.224, 0.225], np.float32)
        self.basis = None

    def process(self, img):
        torch = self.torch
        h, w = img.shape[:2]
        p = 14
        s = self.args.dino_size / max(h, w)
        gh, gw = max(1, round(h * s / p)), max(1, round(w * s / p))
        x = cv2.resize(cv2.cvtColor(img, cv2.COLOR_BGR2RGB), (gw * p, gh * p)).astype(np.float32) / 255
        x = torch.from_numpy(((x - self.mean) / self.std).transpose(2, 0, 1))[None].to(self.device)
        with torch.inference_mode():
            feat = self.model(pixel_values=x).last_hidden_state[0, 1:].float()  # (gh*gw, C)
        feat = feat - feat.mean(0)
        _, _, v = torch.pca_lowrank(feat, q=3, center=False)
        if self.basis is not None:  # keep component signs stable between frames
            v = v * torch.sign((v * self.basis).sum(0, keepdim=True))
        self.basis = v
        proj = (feat @ v).cpu().numpy().reshape(gh, gw, 3)
        lo, hi = np.percentile(proj, 2, axis=(0, 1)), np.percentile(proj, 98, axis=(0, 1))
        rgb = np.clip((proj - lo) / (hi - lo + 1e-6), 0, 1)
        vis = cv2.resize((rgb * 255).astype(np.uint8), (w, h), interpolation=cv2.INTER_NEAREST)
        return cv2.cvtColor(vis, cv2.COLOR_RGB2BGR)


class GroundingDinoProc(TorchProcessor):
    """Open-vocabulary detection from a text prompt (Grounding DINO tiny)."""
    name = "Grounding DINO"

    def load(self):
        import torch
        from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor
        mid = "IDEA-Research/grounding-dino-tiny"
        self.proc = AutoProcessor.from_pretrained(mid)
        self.model = self.to_device(AutoModelForZeroShotObjectDetection.from_pretrained(mid))
        self.torch = torch
        self.name = f"Grounding DINO: {self.args.gdino_text}"

    def process(self, img):
        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        inp = self.proc(images=rgb, text=self.args.gdino_text, return_tensors="pt").to(self.device)
        with self.torch.inference_mode():
            outs = self.model(**inp)
        r = self.proc.post_process_grounded_object_detection(
            outs, inp.input_ids, box_threshold=0.35, text_threshold=0.25, target_sizes=[img.shape[:2]])[0]
        return draw_dets(img, r["boxes"].cpu().numpy(), r["labels"], r["scores"].cpu().numpy(), (255, 160, 0))


class MediaPipeProc(Processor):
    """MediaPipe Holistic: body pose, both hands, face parts, and 3D gaze rays.

    Gaze: MediaPipe's face landmarks are 3D (x, y in image units, z in the
    same scale as x, smaller = nearer). Per eye, the eyeball centre is put
    0.4 eye-widths behind the eye-corner midpoint along the face normal; the
    gaze ray runs from there through the iris centre (refined landmarks
    468/473). Rays are drawn as 3D lines projected back onto the image, and a
    top/side inset shows them in 3D.
    """
    name = "MediaPipe pose/hands/face/gaze"
    # (outer corner, inner corner, iris centre) per eye -- subject's right, left
    EYES = ((33, 133, 468), (263, 362, 473))

    def load(self):
        import mediapipe as mp
        self.device = "cpu"
        self.mp = mp
        self.holistic = mp.solutions.holistic.Holistic(
            model_complexity=self.args.mp_complexity, refine_face_landmarks=True,
            min_detection_confidence=0.5, min_tracking_confidence=0.5)
        fm = mp.solutions.face_mesh
        self.face_parts = [(fm.FACEMESH_LIPS, (60, 60, 255)), (fm.FACEMESH_LEFT_EYE, (255, 160, 40)),
                           (fm.FACEMESH_RIGHT_EYE, (255, 160, 40)), (fm.FACEMESH_LEFT_EYEBROW, (0, 200, 255)),
                           (fm.FACEMESH_RIGHT_EYEBROW, (0, 200, 255)), (fm.FACEMESH_FACE_OVAL, (200, 200, 200)),
                           (fm.FACEMESH_IRISES, (255, 255, 0))]
        self.face_parts = [(list(c), col) for c, col in self.face_parts]

    @staticmethod
    def _xyz(lms, w, h):
        return np.array([[p.x * w, p.y * h, p.z * w] for p in lms.landmark], np.float32)

    def _lines(self, out, pts, conns, color, th=1):
        for a, b in conns:
            if a < len(pts) and b < len(pts):
                cv2.line(out, tuple(pts[a][:2].astype(int)), tuple(pts[b][:2].astype(int)), color, th, cv2.LINE_AA)

    def gaze(self, P):
        """Face normal and per-eye (iris, unit gaze direction), all 3D."""
        across = P[263] - P[33]
        down = P[152] - P[10]
        n = np.cross(down, across)
        n /= np.linalg.norm(n) + 1e-6
        if n[2] > 0:  # make it point toward the camera (z decreases toward the camera)
            n = -n
        rays = []
        for outer, inner, iris in self.EYES:
            mid = 0.5 * (P[outer] + P[inner])
            w = np.linalg.norm(P[outer] - P[inner])
            center = mid - n * 0.4 * w
            d = P[iris] - center
            rays.append((P[iris], d / (np.linalg.norm(d) + 1e-6), w))
        return n, rays

    def draw_inset(self, out, P, n, rays):
        """Top view (x-z) and side view (z-y) of head direction and gaze rays."""
        s = 120
        h = out.shape[0]
        nose = P[1]
        for k, (ax0, ax1, label) in enumerate(((0, 2, "top"), (2, 1, "side"))):
            x0, y0 = 8 + k * (s + 8), h - s - 8
            sub = out[y0:y0 + s, x0:x0 + s]
            sub[:] = (sub * 0.3).astype(np.uint8)
            cv2.rectangle(out, (x0, y0), (x0 + s, y0 + s), (180, 180, 180), 1)
            cv2.putText(out, label, (x0 + 4, y0 + 14), FONT, 0.4, (220, 220, 220), 1)
            scale = 0.5 * s / (np.linalg.norm(P[263] - P[33]) * 2.5 + 1e-6)

            def proj(p):
                q = (p - nose) * scale
                return int(x0 + s / 2 + q[ax0]), int(y0 + s / 2 + q[ax1])
            for a, b in ((33, 263), (10, 152)):
                cv2.line(out, proj(P[a]), proj(P[b]), (200, 200, 200), 1)
            cv2.arrowedLine(out, proj(nose), proj(nose + n * 60 / scale), (0, 255, 0), 1, tipLength=0.2)
            for (iris, d, w), col in zip(rays, ((255, 0, 255), (255, 255, 0))):
                cv2.line(out, proj(iris), proj(iris + d * 55 / scale), col, 1, cv2.LINE_AA)

    def process(self, img):
        H, W = img.shape[:2]
        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        rgb.flags.writeable = False
        r = self.holistic.process(rgb)
        out = (img * 0.6).astype(np.uint8)
        hol = self.mp.solutions.holistic
        info = []
        if r.pose_landmarks:
            P = self._xyz(r.pose_landmarks, W, H)
            self._lines(out, P, hol.POSE_CONNECTIONS, (80, 255, 80), 2)
            vis = [lm.visibility > 0.5 for lm in r.pose_landmarks.landmark]
            for p, v in zip(P, vis):
                if v:
                    cv2.circle(out, tuple(p[:2].astype(int)), 3, (255, 255, 255), -1)
            info.append("pose")
        for lms, col, lab in ((r.left_hand_landmarks, (0, 220, 255), "L-hand"),
                              (r.right_hand_landmarks, (255, 180, 0), "R-hand")):
            if lms:
                P = self._xyz(lms, W, H)
                self._lines(out, P, hol.HAND_CONNECTIONS, col, 2)
                for p in P:
                    cv2.circle(out, tuple(p[:2].astype(int)), 3, (255, 255, 255), -1)
                info.append(lab)
        if r.face_landmarks:
            P = self._xyz(r.face_landmarks, W, H)
            for conns, col in self.face_parts:
                self._lines(out, P, conns, col, 1)
            n, rays = self.gaze(P)
            L = 7.0 * rays[0][2]
            # head direction (green) and per-eye gaze rays, projected 3D lines
            cv2.arrowedLine(out, tuple(P[1][:2].astype(int)), tuple((P[1] + n * L)[:2].astype(int)),
                            (0, 255, 0), 2, cv2.LINE_AA, tipLength=0.15)
            for (iris, d, w), col in zip(rays, ((255, 0, 255), (255, 255, 0))):
                cv2.circle(out, tuple(iris[:2].astype(int)), 3, col, -1)
                cv2.arrowedLine(out, tuple(iris[:2].astype(int)), tuple((iris + d * L)[:2].astype(int)),
                                col, 3, cv2.LINE_AA, tipLength=0.15)
            g = rays[0][1] + rays[1][1]
            g /= np.linalg.norm(g) + 1e-6
            yaw = np.degrees(np.arctan2(g[0], -g[2]))
            pitch = np.degrees(np.arctan2(-g[1], -g[2]))
            info.append(f"face  gaze yaw {yaw:+.0f} pitch {pitch:+.0f} deg")
            self.draw_inset(out, P, n, rays)
        # bottom left, above the 3D inset (the tile header covers the top left)
        cv2.putText(out, ", ".join(info) or "no person", (8, H - 140), FONT, 0.5, (255, 255, 255), 1, cv2.LINE_AA)
        return out


PROCESSORS = {"apriltag": AprilTagProc, "yolo": YoloProc, "depth": DepthProc, "sam2": Sam2Proc,
              "detr": DetrProc, "dino": DinoProc, "gdino": GroundingDinoProc, "floor": FloorProc,
              "mediapipe": MediaPipeProc}


# --------------------------------------------------------------------------

def raw_view(rx, sync, host):
    fr = rx.latest
    if fr is None:
        img = np.zeros((480, 640, 3), np.uint8)
        return put_lines(img, [f"M5Camera {host}: {rx.status}"], scale=0.6)
    img = fr.img.copy()
    lines = [f"capture  {fmt_time(fr.cap_us) if fr.cap_us else '(syncing clock)'}",
             f"receive  {fmt_time(fr.recv_us)}",
             f"recv interval {fr.interval_ms:6.1f} ms   ({rx.fps:4.1f} fps)",
             f"cam  interval {fr.cap_interval_ms:6.1f} ms"]
    if fr.cap_us:
        lines.append(f"latency capture->recv {(fr.recv_us - fr.cap_us) / 1000:6.1f} ms")
    rtt = f"{sync.rtt_us / 1000:.1f} ms" if sync.rtt_us else "-"
    lines.append(f"#{fr.seq} {img.shape[1]}x{img.shape[0]} {fr.jpeg_len / 1024:.1f} KB  sync rtt {rtt}")
    if rx.status != "streaming":
        lines.append(rx.status)
    return put_lines(img, lines, scale=0.55)


def mosaic(rx, procs, tile_h, cols):
    """Input image on the left (spanning all rows), processor tiles on the right.

    Tile width follows the input's aspect ratio, so a camera mounted sideways
    (--rotate 90) gets portrait tiles instead of squashed ones.
    """
    fr = rx.latest
    ih, iw = fr.img.shape[:2] if fr is not None else (480, 640)
    tile_w = int(round(tile_h * iw / ih))
    tiles = [p.tile(tile_w, tile_h) for p in procs]
    rows = (len(tiles) + cols - 1) // cols
    tiles += [np.zeros((tile_h, tile_w, 3), np.uint8)] * (rows * cols - len(tiles))
    grid = np.vstack([np.hstack(tiles[r * cols:(r + 1) * cols]) for r in range(rows)])
    big_h = grid.shape[0]
    big_w = int(round(big_h * iw / ih))
    if fr is None:
        left = put_lines(np.zeros((big_h, big_w, 3), np.uint8), [f"input: {rx.status}"], scale=0.6)
    else:
        left = cv2.resize(fr.img, (big_w, big_h))
        lines = [f"input #{fr.seq}",
                 f"capture {fmt_time(fr.cap_us) if fr.cap_us else '(syncing clock)'}",
                 f"recv interval {fr.interval_ms:6.1f} ms ({rx.fps:4.1f} fps)"]
        left = put_lines(left, lines, scale=0.55)
    cv2.line(left, (big_w - 1, 0), (big_w - 1, big_h), (255, 255, 255), 2)
    return np.hstack([left, grid])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--host", help="camera IP (default: UDP beacon / m5camera.local)")
    ap.add_argument("--proc", default="apriltag,yolo,depth,floor,sam2,detr,dino,mediapipe",
                    help=f"comma list from {','.join(PROCESSORS)}")
    ap.add_argument("--device", default="cuda", help="torch device for the DNN processors (cuda/cpu)")
    ap.add_argument("--framesize", type=int, help="camera framesize_t: 5=QVGA 8=VGA 9=SVGA 10=XGA (saved on device)")
    ap.add_argument("--quality", type=int, help="JPEG quality 4..63, lower is better (saved on device)")
    ap.add_argument("--rotate", type=int, default=0, choices=[0, 90, 180, 270])
    ap.add_argument("--tag-family", default="36h11", choices=["36h11", "36h10", "25h9", "16h5"])
    ap.add_argument("--yolo", default="yolo26n.pt,yolo11n.pt", help="weights, first loadable wins")
    ap.add_argument("--imgsz", type=int, default=640, help="YOLO input size")
    ap.add_argument("--sam2", default="sam2.1_t.pt")
    ap.add_argument("--sam-imgsz", type=int, default=512)
    ap.add_argument("--depth-model", default="depth-anything/Depth-Anything-V2-Small-hf")
    ap.add_argument("--depth-size", type=int, default=392, help="Depth Anything input size (multiple of 14)")
    ap.add_argument("--floor-roi", type=float, default=0.4, help="bottom fraction of the image used to fit the floor")
    ap.add_argument("--floor-tol", type=float, default=0.06, help="relative disparity tolerance for floor pixels")
    ap.add_argument("--robot-width", type=float, default=0.3,
                    help="robot width as a fraction of image width at the bottom edge")
    ap.add_argument("--detr-size", type=int, default=480, help="DETR shortest edge")
    ap.add_argument("--dino-model", default="facebook/dinov2-small")
    ap.add_argument("--dino-size", type=int, default=448, help="DINOv2 input long edge")
    ap.add_argument("--gdino-text", default="a person. a cup. a bottle. a robot.")
    ap.add_argument("--tile-height", type=int, default=300, help="processing tile height (width follows the image)")
    ap.add_argument("--cols", type=int, default=4, help="processing tiles per row (right of the input image)")
    ap.add_argument("--mp-complexity", type=int, default=1, choices=[0, 1, 2], help="MediaPipe pose model size")
    ap.add_argument("--record", metavar="DIR", help="record both windows to DIR/raw.mp4, DIR/proc.mp4 (real-time 10 fps)")
    ap.add_argument("--duration", type=float, default=0, help="quit after N seconds (0 = run until q)")
    ap.add_argument("--snapshot-interval", type=float, default=0, help="also save snapshots every N seconds")
    args = ap.parse_args()

    host = args.host or discover()
    if not host:
        raise SystemExit("M5Camera not found; pass --host <ip> (the IP is printed on its serial console)")
    print(f"M5Camera at {host}")
    os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")

    rotate_ref = [args.rotate]
    sync = TimeSync(host)
    sync.start()
    rx = Receiver(host, sync, rotate_ref, args.framesize, args.quality)
    rx.start()

    shared = {"depth_cond": threading.Condition()}
    names = [n.strip() for n in args.proc.split(",") if n.strip()]
    for n in names:
        if n not in PROCESSORS:
            raise SystemExit(f"unknown processor {n!r}; choose from {','.join(PROCESSORS)}")
    if "floor" in names and "depth" not in names:
        raise SystemExit("--proc floor needs depth as well")
    # transformers' lazy module loader is not thread-safe: resolve every class
    # here, once, before the processor threads import them concurrently.
    if "mediapipe" in names:
        import mediapipe  # noqa: F401
    if set(names) - {"apriltag", "floor", "mediapipe"}:
        import transformers  # noqa: F401
        from transformers import (AutoImageProcessor, AutoModel, AutoModelForDepthEstimation,  # noqa: F401
                                  AutoModelForZeroShotObjectDetection, AutoProcessor,
                                  DetrForObjectDetection, DetrImageProcessor)
        from ultralytics import SAM, YOLO  # noqa: F401
    procs = [PROCESSORS[n](rx, args, shared) for n in names]
    for p in procs:
        p.start()

    th = args.tile_height
    cv2.namedWindow("M5Camera", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("M5Camera", 640, 480)
    if procs:
        cols = min(args.cols, len(procs))
        cv2.namedWindow("Processing", cv2.WINDOW_NORMAL)
        rows = (len(procs) + cols - 1) // cols
        full_w, full_h = int(th * 4 / 3 * (rows + cols)), th * rows  # 4:3 input + tiles
        fit = min(1.0, 1900 / full_w)
        cv2.resizeWindow("Processing", int(full_w * fit), int(full_h * fit))
    last_snap = t_start = time.time()
    writers, rec_fps, next_rec = {}, 10.0, time.time()
    while True:
        raw = raw_view(rx, sync, host)
        cv2.imshow("M5Camera", raw)
        mos = None
        if procs:
            mos = mosaic(rx, procs, th, min(args.cols, len(procs)))
            cv2.imshow("Processing", mos)
        # recording: fixed-rate sampling of what is on screen, so playback is real time
        if args.record and rx.latest is not None and time.time() >= next_rec:
            # repeat the current frame for every 1/rec_fps that passed, so a slow
            # display loop still gives a video that plays back in real time
            reps = int((time.time() - next_rec) * rec_fps) + 1
            next_rec += reps / rec_fps
            for key, im in (("raw", raw), ("proc", mos)):
                if im is None:
                    continue
                if key not in writers:
                    Path(args.record).mkdir(parents=True, exist_ok=True)
                    writers[key] = cv2.VideoWriter(str(Path(args.record) / f"{key}.mp4"),
                                                   cv2.VideoWriter_fourcc(*"mp4v"), rec_fps, im.shape[1::-1])
                for _ in range(reps):
                    writers[key].write(im)
        if args.duration and time.time() - t_start > args.duration:
            break
        k = cv2.waitKey(15) & 0xFF
        if k in (ord("q"), 27):
            break
        if k == ord("r"):
            rotate_ref[0] = (rotate_ref[0] + 90) % 360
        if k == ord("s") or (args.snapshot_interval and time.time() - last_snap > args.snapshot_interval):
            last_snap = time.time()
            stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
            snap = HERE / "snapshots"
            snap.mkdir(exist_ok=True)
            cv2.imwrite(str(snap / f"{stamp}_raw.jpg"), raw)
            if mos is not None:
                cv2.imwrite(str(snap / f"{stamp}_proc.jpg"), mos)
            print(f"saved snapshots/{stamp}_*.jpg")
    for w in writers.values():
        w.release()
    cv2.destroyAllWindows()
    os._exit(0)  # processor threads may be inside CUDA calls; don't wait for them


if __name__ == "__main__":
    main()
