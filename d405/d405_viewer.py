#!/usr/bin/env python3
"""RealSense D405 (USB) colour + depth viewer with parallel vision processing.

Window "D405": colour and depth side by side, with the capture time (frame
timestamp), receive time, receive interval and capture->receive latency.

Window "Processing": colour and depth stacked on the left, then one tile per
processor, each running in its own thread on the newest frame (frames that
arrive while a processor is busy are skipped). Every processor that can, uses
the metric depth too:

    apriltag   AprilTag detection + 6-DoF pose (solvePnP with the D405 intrinsics) and depth distance
    yolo       YOLO26n detection, labelled with the median depth inside each box
    depth      the D405's own depth, colour-mapped in metres
    dav2       Depth Anything V2 fitted to the D405 depth (scale+shift), filling the sensor's holes
    floor      3D floor plane (RANSAC on the point cloud), obstacles, top-down grid and a path
    sam2       SAM2.1 masks (prompted with YOLO boxes) with each mask's distance
    detr       DETR detection with distances
    dino       DINOv2 patch-feature PCA
    mediapipe  MediaPipe pose / hands / face parts, face distance and a metric 3D gaze ray
    gdino      (optional) Grounding DINO open-vocabulary detection with distances

    .venv/bin/python d405_viewer.py
    .venv/bin/python d405_viewer.py --proc apriltag,floor --tag-size 0.03
    .venv/bin/python d405_viewer.py --width 848 --height 480 --fps 30 --filter

Keys (either window): q/ESC quit, s save snapshot, r rotate 90deg.
"""
import argparse
import datetime
import os
import threading
import time
import traceback
from pathlib import Path

import cv2
import numpy as np

HERE = Path(__file__).resolve().parent
WEIGHTS = HERE / "weights"
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


# --------------------------------------------------------------------------
# Camera geometry helpers. K = (fx, fy, cx, cy) of the colour image, which the
# depth is aligned to, so one K serves both.

def deproject(u, v, z, K):
    fx, fy, cx, cy = K
    return np.stack([(u - cx) * z / fx, (v - cy) * z / fy, z], -1)


def project(P, K):
    fx, fy, cx, cy = K
    P = np.atleast_2d(P)
    z = np.maximum(P[:, 2], 1e-6)
    return np.stack([fx * P[:, 0] / z + cx, fy * P[:, 1] / z + cy], -1)


def depth_in_box(depth, x0, y0, x1, y1, shrink=0.5):
    """Median valid depth of the central part of a box (metres, or None)."""
    h, w = depth.shape
    cx, cy, bw, bh = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) * shrink / 2, (y1 - y0) * shrink / 2
    a, b = int(max(0, cx - bw)), int(min(w, cx + bw + 1))
    c, d = int(max(0, cy - bh)), int(min(h, cy + bh + 1))
    roi = depth[c:d, a:b]
    roi = roi[roi > 0]
    return float(np.median(roi)) if roi.size > 10 else None


def depth_colormap(depth, lo, hi):
    d = np.clip((depth - lo) / (hi - lo), 0, 1)
    vis = cv2.applyColorMap((255 - d * 255).astype(np.uint8), cv2.COLORMAP_TURBO)
    vis[depth <= 0] = 0
    return vis


def fmt_m(z):
    return "--" if z is None else (f"{z * 100:.1f}cm" if z < 1 else f"{z:.2f}m")


class Frame:
    __slots__ = ("seq", "img", "depth", "K", "cap_us", "recv_us", "interval_ms", "cap_interval_ms", "clock")


class RealSenseSource(threading.Thread):
    """Colour + aligned depth from the D405, as Frames with a host-clock capture time."""

    def __init__(self, args, rotate_ref):
        super().__init__(daemon=True)
        self.args, self.rotate_ref = args, rotate_ref
        self.cond = threading.Condition()
        self.latest = None
        self.status = "starting"
        self.fps = 0.0
        self.info = ""
        self.hw_offset_us = None

    def run(self):
        while True:
            try:
                self._stream()
            except Exception as e:  # noqa: BLE001 - unplugged etc.; retry
                traceback.print_exc()
                self.status = f"retrying ({e})"
                time.sleep(2.0)

    def _stream(self):
        import pyrealsense2 as rs
        a = self.args
        pipe, cfg = rs.pipeline(), rs.config()
        if a.serial:
            cfg.enable_device(a.serial)
        cfg.enable_stream(rs.stream.depth, a.width, a.height, rs.format.z16, a.fps)
        cfg.enable_stream(rs.stream.color, a.width, a.height, rs.format.bgr8, a.fps)
        prof = pipe.start(cfg)
        dev = prof.get_device()
        scale = dev.first_depth_sensor().get_depth_scale()
        intr = prof.get_stream(rs.stream.color).as_video_stream_profile().get_intrinsics()
        self.K0 = (intr.fx, intr.fy, intr.ppx, intr.ppy)
        self.dist = np.array(intr.coeffs, np.float64)
        self.info = (f"{dev.get_info(rs.camera_info.name)} SN {dev.get_info(rs.camera_info.serial_number)} "
                     f"FW {dev.get_info(rs.camera_info.firmware_version)} USB {dev.get_info(rs.camera_info.usb_type_descriptor)}")
        print(self.info, f"depth scale {scale}", f"K {self.K0}")
        align = rs.align(rs.stream.color)
        filters = [rs.spatial_filter(), rs.temporal_filter(), rs.hole_filling_filter()] if a.filter else []
        self.status = "streaming"
        last_recv = last_cap = None
        seq = 0
        try:
            while True:
                frames = pipe.wait_for_frames(3000)
                recv = now_us()
                frames = align.process(frames)
                c, d = frames.get_color_frame(), frames.get_depth_frame()
                if not c or not d:
                    continue
                for f in filters:
                    d = f.process(d)
                img = np.asanyarray(c.get_data()).copy()
                depth = np.asanyarray(d.get_data()).astype(np.float32) * scale
                cap, clock = self._capture_time(c, recv, rs)
                img, depth, K = self._rotate(img, depth, self.K0)
                fr = Frame()
                fr.seq, fr.img, fr.depth, fr.K, fr.recv_us, fr.cap_us, fr.clock = seq, img, depth, K, recv, cap, clock
                fr.interval_ms = (recv - last_recv) / 1000 if last_recv else 0.0
                fr.cap_interval_ms = (cap - last_cap) / 1000 if last_cap else 0.0
                last_recv, last_cap = recv, cap
                if fr.interval_ms > 0:
                    f = 1000 / fr.interval_ms
                    self.fps = 0.9 * self.fps + 0.1 * f if self.fps else f
                seq += 1
                with self.cond:
                    self.latest = fr
                    self.cond.notify_all()
        finally:
            pipe.stop()

    def _capture_time(self, frame, recv_us, rs):
        """Frame timestamp on the host clock (us). The SDK's global time domain
        already is the host clock; a raw hardware clock gets an offset from the
        smallest receive-minus-capture seen so far (i.e. assumes ~0 latency then)."""
        ts_us = int(frame.get_timestamp() * 1000)
        dom = frame.get_frame_timestamp_domain()
        if dom in (rs.timestamp_domain.global_time, rs.timestamp_domain.system_time) or abs(recv_us - ts_us) < 10_000_000:
            return ts_us, "host"
        off = recv_us - ts_us
        self.hw_offset_us = off if self.hw_offset_us is None else min(self.hw_offset_us, off)
        return ts_us + self.hw_offset_us, "hw-est"

    def _rotate(self, img, depth, K):
        rot = self.rotate_ref[0]
        if not rot:
            return img, depth, K
        fx, fy, cx, cy = K
        h, w = depth.shape
        code = {90: cv2.ROTATE_90_CLOCKWISE, 180: cv2.ROTATE_180, 270: cv2.ROTATE_90_COUNTERCLOCKWISE}[rot]
        K = {90: (fy, fx, h - 1 - cy, cx), 180: (fx, fy, w - 1 - cx, h - 1 - cy), 270: (fy, fx, cy, w - 1 - cx)}[rot]
        return cv2.rotate(img, code), cv2.rotate(depth, code), K

    def wait_newer(self, seq, timeout=1.0):
        with self.cond:
            self.cond.wait_for(lambda: self.latest is not None and self.latest.seq != seq, timeout)
            return self.latest


# --------------------------------------------------------------------------
# Processors. Each runs in its own thread: load() once, then process_frame(fr)
# -> annotated BGR image on every newest frame.

class Processor(threading.Thread):
    name = "base"
    LOAD_LOCK = threading.Lock()

    def __init__(self, source, args, shared):
        super().__init__(daemon=True)
        self.rx, self.args, self.shared = source, args, shared
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
            self.age_ms = (now_us() - fr.cap_us) / 1000
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
        return put_lines(img, lines, scale=0.42)


class TorchProcessor(Processor):
    def pick_device(self):
        import torch
        if self.device.startswith("cuda") and not torch.cuda.is_available():
            self.device = "cpu"
        return self.device

    def to_device(self, model):
        """Move to the GPU, falling back to CPU if the card is full."""
        import torch
        self.pick_device()
        try:
            return model.to(self.device).eval()
        except torch.cuda.OutOfMemoryError:
            torch.cuda.empty_cache()
            self.device = "cpu"
            return model.to("cpu").eval()


def draw_dets(img, boxes, labels, scores, depth, color=(0, 200, 255)):
    out = img.copy()
    for (x0, y0, x1, y1), lab, s in zip(boxes, labels, scores):
        p0, p1 = (int(x0), int(y0)), (int(x1), int(y1))
        cv2.rectangle(out, p0, p1, color, 2)
        txt = f"{lab} {s:.2f} {fmt_m(depth_in_box(depth, x0, y0, x1, y1))}"
        (tw, th), _ = cv2.getTextSize(txt, FONT, 0.5, 1)
        cv2.rectangle(out, (p0[0], p0[1] - th - 6), (p0[0] + tw + 4, p0[1]), color, -1)
        cv2.putText(out, txt, (p0[0] + 2, p0[1] - 4), FONT, 0.5, (0, 0, 0), 1, cv2.LINE_AA)
    return out


class AprilTagProc(Processor):
    """AprilTag IDs, 6-DoF pose from the tag corners, and the D405 depth at the tag."""
    name = "AprilTag"

    def load(self):
        self.device = "cpu"
        fams = {"36h11": cv2.aruco.DICT_APRILTAG_36h11, "25h9": cv2.aruco.DICT_APRILTAG_25h9,
                "16h5": cv2.aruco.DICT_APRILTAG_16h5, "36h10": cv2.aruco.DICT_APRILTAG_36h10}
        fam = self.args.tag_family
        self.name = f"AprilTag ({fam}, {self.args.tag_size * 100:.1f} cm) + pose"
        params = cv2.aruco.DetectorParameters()
        params.cornerRefinementMethod = cv2.aruco.CORNER_REFINE_APRILTAG
        self.det = cv2.aruco.ArucoDetector(cv2.aruco.getPredefinedDictionary(fams[fam]), params)
        s = self.args.tag_size / 2
        self.obj = np.array([[-s, s, 0], [s, s, 0], [s, -s, 0], [-s, -s, 0]], np.float64)

    def process_frame(self, fr):
        img = fr.img
        corners, ids, _ = self.det.detectMarkers(cv2.cvtColor(img, cv2.COLOR_BGR2GRAY))
        out = img.copy()
        fx, fy, cx, cy = fr.K
        Km = np.array([[fx, 0, cx], [0, fy, cy], [0, 0, 1]], np.float64)
        tags = []
        if ids is not None:
            cv2.aruco.drawDetectedMarkers(out, corners, ids)
            for c, i in zip(corners, ids.flatten()):
                ok, rvec, tvec = cv2.solvePnP(self.obj, c[0].astype(np.float64), Km, None,
                                              flags=cv2.SOLVEPNP_IPPE_SQUARE)
                ctr = c[0].mean(axis=0)
                zd = depth_in_box(fr.depth, *c[0].min(0), *c[0].max(0), shrink=0.6)
                if ok:
                    cv2.drawFrameAxes(out, Km, None, rvec, tvec, self.args.tag_size * 0.75, 2)
                    t = tvec.ravel()
                    txt = [f"id={i} pnp {fmt_m(float(np.linalg.norm(t)))}", f"depth {fmt_m(zd)}"]
                    tags.append((int(i), t))
                else:
                    txt = [f"id={i}", f"depth {fmt_m(zd)}"]
                for k, s in enumerate(txt):
                    cv2.putText(out, s, (int(ctr[0]) - 40, int(ctr[1]) + 20 + 16 * k), FONT, 0.5, (0, 255, 255), 1,
                                cv2.LINE_AA)
        self.shared["tags"] = tags
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
                self.name = f"YOLO ({Path(w).stem}) + distance"
                break
            except Exception as e:  # noqa: BLE001 - try the next candidate
                last = e
        else:
            raise last
        self.pick_device()

    def process_frame(self, fr):
        r = self.model.predict(fr.img, device=self.device, verbose=False, imgsz=self.args.imgsz, conf=0.35)[0]
        b = r.boxes
        boxes = b.xyxy.cpu().numpy()
        self.shared["yolo_boxes"] = (time.time(), boxes)
        labels = [r.names[int(k)] for k in b.cls.cpu().numpy()]
        return draw_dets(fr.img, boxes, labels, b.conf.cpu().numpy(), fr.depth, (60, 220, 60))


class SensorDepthProc(Processor):
    """The D405's own depth in metres, with holes in black and a scale bar."""
    name = "D405 depth (sensor)"

    def load(self):
        self.device = "cpu"

    def process_frame(self, fr):
        lo, hi = self.args.min_depth, self.args.max_depth
        d = fr.depth
        out = depth_colormap(d, lo, hi)
        h, w = d.shape
        z = depth_in_box(d, w / 2 - 6, h / 2 - 6, w / 2 + 6, h / 2 + 6, shrink=1.0)
        cv2.drawMarker(out, (w // 2, h // 2), (255, 255, 255), cv2.MARKER_CROSS, 18, 2)
        cv2.putText(out, fmt_m(z), (w // 2 + 10, h // 2 - 8), FONT, 0.6, (255, 255, 255), 2, cv2.LINE_AA)
        valid = (d > 0).mean()
        # scale bar
        bar = depth_colormap(np.tile(np.linspace(lo, hi, w - 40, dtype=np.float32), (10, 1)), lo, hi)
        out[h - 34:h - 24, 20:w - 20] = bar
        cv2.putText(out, f"{lo * 100:.0f}cm", (20, h - 8), FONT, 0.45, (255, 255, 255), 1, cv2.LINE_AA)
        cv2.putText(out, f"{hi * 100:.0f}cm", (w - 70, h - 8), FONT, 0.45, (255, 255, 255), 1, cv2.LINE_AA)
        cv2.putText(out, f"valid {valid:.0%}", (w // 2 - 40, h - 8), FONT, 0.45, (255, 255, 255), 1, cv2.LINE_AA)
        return out


class DAv2Proc(TorchProcessor):
    """Depth Anything V2 (relative disparity) fitted to the D405's metric depth.

    DA-V2 predicts disparity up to scale and shift, d = a/Z + b. Fitting a, b by
    least squares on the pixels where the D405 has depth (two passes, dropping
    the worst 20 % the second time) turns it into metric depth everywhere,
    including the sensor's holes. AbsRel against the sensor is shown.
    """
    name = "Depth Anything V2 fitted to D405"

    def load(self):
        import torch
        from transformers import AutoImageProcessor, AutoModelForDepthEstimation
        mid = self.args.depth_model
        self.proc = AutoImageProcessor.from_pretrained(mid)
        self.model = self.to_device(AutoModelForDepthEstimation.from_pretrained(mid))
        self.torch = torch

    def process_frame(self, fr):
        img, Z = fr.img, fr.depth
        n = self.args.depth_size
        inp = self.proc(images=cv2.cvtColor(img, cv2.COLOR_BGR2RGB), return_tensors="pt",
                        size={"height": n, "width": n}, keep_aspect_ratio=True, ensure_multiple_of=14).to(self.device)
        with self.torch.inference_mode():
            d = self.model(**inp).predicted_depth[0].float().cpu().numpy()
        d = cv2.resize(d, (img.shape[1], img.shape[0]))
        m = (Z > self.args.min_depth) & (Z < self.args.max_depth * 1.5)
        out_info = "no sensor depth to fit"
        metric = None
        if m.sum() > 500:
            idx = np.flatnonzero(m)[::7]
            x, y = 1.0 / Z.flat[idx], d.flat[idx]
            keep = np.ones(len(x), bool)
            for _ in range(2):
                A = np.stack([x[keep], np.ones(keep.sum())], 1)
                (a, b), *_ = np.linalg.lstsq(A, y[keep], rcond=None)
                res = np.abs(a * x + b - y)
                keep = res <= np.percentile(res, 80)
            if a > 0:
                inv = (d - b) / a
                metric = np.where(inv > 1e-3, 1.0 / np.maximum(inv, 1e-3), 0).astype(np.float32)
                absrel = float(np.median(np.abs(metric[m] - Z[m]) / Z[m]))
                filled = float(((Z <= 0) & (metric > 0)).mean())
                out_info = f"fit vs D405: median AbsRel {absrel:.1%}, filled holes {filled:.0%}"
        if metric is None:
            dn = (d - d.min()) / (d.max() - d.min() + 1e-6)
            out = cv2.applyColorMap((dn * 255).astype(np.uint8), cv2.COLORMAP_INFERNO)
        else:
            out = depth_colormap(metric, self.args.min_depth, self.args.max_depth)
        h = out.shape[0]
        cv2.putText(out, out_info, (8, h - 10), FONT, 0.48, (255, 255, 255), 1, cv2.LINE_AA)
        return out


class FloorProc(Processor):
    """Metric floor plane, obstacles and a path, from the D405 point cloud.

    1. Point cloud from the aligned depth (every 4th pixel).
    2. RANSAC plane, |distance| < --floor-tol, whose normal is within
       --floor-max-tilt of the camera's "up" (-y) and lies below the camera.
    3. Height of every point above that plane: floor (green) within the
       tolerance, obstacles (red) between it and --robot-height.
    4. Top-down grid on the plane (--grid-res): x across, y forward from the
       camera's foot point. Obstacles are inflated by half the robot width;
       Dijkstra from the nearest floor cell to the camera's foot to the
       farthest reachable one, preferring cells with clearance.
    5. The path is mapped back into 3D and projected into the image, with
       distance ticks every --tick metres, and a top-down inset.
    """
    name = "Floor plane + obstacles + path (3D)"

    def load(self):
        self.device = "cpu"
        self.rng = np.random.default_rng(0)
        self.plane = None

    def fit_plane(self, P):
        tol = self.args.floor_tol
        cos_tilt = np.cos(np.radians(self.args.floor_max_tilt))
        best, best_n = None, 0
        cands = [self.plane] if self.plane is not None else []
        for _ in range(120):
            a, b, c = P[self.rng.choice(len(P), 3, replace=False)]
            n = np.cross(b - a, c - a)
            nn = np.linalg.norm(n)
            if nn < 1e-9:
                continue
            n /= nn
            if n[1] > 0:  # point "up", toward the camera side (-y in camera coordinates)
                n = -n
            cands.append(np.append(n, -n @ a))
        for pl in cands:
            n, dd = pl[:3], pl[3]
            if -n[1] < cos_tilt or dd <= 0.01:  # too steep, or not below the camera
                continue
            cnt = np.count_nonzero(np.abs(P @ n + dd) < tol)
            if cnt > best_n:
                best, best_n = pl, cnt
        if best is None or best_n < 0.08 * len(P):
            return None, best_n / max(len(P), 1)
        inl = P[np.abs(P @ best[:3] + best[3]) < tol]
        ctr = inl.mean(0)
        n = np.linalg.svd(inl - ctr, full_matrices=False)[2][2]
        if n[1] > 0:
            n = -n
        return np.append(n, -n @ ctr), best_n / len(P)

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

    def process_frame(self, fr):
        a = self.args
        img, Z, K = fr.img, fr.depth, fr.K
        H, W = Z.shape
        out = img.copy()
        s = 4
        vs, us = np.mgrid[0:H:s, 0:W:s]
        zs = Z[::s, ::s]
        ok = (zs > a.min_depth) & (zs < a.max_depth)
        if ok.sum() < 200:
            cv2.putText(out, "too little depth", (10, H - 12), FONT, 0.7, (0, 0, 255), 2)
            return out
        P = deproject(us[ok].astype(np.float32), vs[ok].astype(np.float32), zs[ok], K)
        plane, ratio = self.fit_plane(P)
        self.plane = plane
        if plane is None:
            cv2.putText(out, f"no floor plane (inliers {ratio:.0%})", (10, H - 12), FONT, 0.6, (0, 0, 255), 2)
            return out
        n, dd = plane[:3], plane[3]
        # per-pixel height above the floor (full resolution)
        vv, uu = np.mgrid[0:H, 0:W].astype(np.float32)
        Pf = deproject(uu, vv, Z, K)
        hgt = Pf @ n + dd
        valid = (Z > a.min_depth) & (Z < a.max_depth)
        floor = valid & (np.abs(hgt) < a.floor_tol)
        obst = valid & (hgt >= a.floor_tol * 1.5) & (hgt < a.robot_height)
        tint = out.copy()
        tint[floor] = (0.4 * tint[floor] + 0.6 * np.array([60, 200, 60])).astype(np.uint8)
        tint[obst] = (0.4 * tint[obst] + 0.6 * np.array([60, 60, 230])).astype(np.uint8)
        out = cv2.addWeighted(tint, 0.85, out, 0.15, 0)

        # plane frame: origin = camera's foot point, e1 = across, e2 = forward
        foot = -dd * n
        e1 = np.array([1.0, 0, 0]) - n * n[0]
        e1 /= np.linalg.norm(e1)
        e2 = np.cross(n, e1)
        if e2[2] < 0:
            e2, e1 = -e2, -e1
        res = a.grid_res
        sel = valid & (floor | obst)
        rel = Pf[sel] - foot
        gx, gy = rel @ e1, rel @ e2
        if len(gy) == 0 or gy.max() <= 0:
            return out
        xmax = max(0.1, np.percentile(np.abs(gx), 99))
        ymax = min(a.max_depth * 1.2, np.percentile(gy, 99.5))
        gw, gh = int(2 * xmax / res) + 1, int(ymax / res) + 1
        ix = np.clip(((gx + xmax) / res).astype(int), 0, gw - 1)
        iy = np.clip((gy / res).astype(int), 0, gh - 1)
        is_obst = obst[sel]
        free = np.zeros((gh, gw), bool)
        occ = np.zeros((gh, gw), bool)
        free[iy[~is_obst], ix[~is_obst]] = True
        occ[iy[is_obst], ix[is_obst]] = True
        free = cv2.morphologyEx(free.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)).astype(bool) & ~occ
        r_cells = max(1, int(a.robot_width / 2 / res))
        clear = cv2.distanceTransform((~occ).astype(np.uint8), cv2.DIST_L2, 3)
        ok_cells = free & (clear > r_cells)
        info = f"cam {dd * 100:.0f}cm above floor, tilt {np.degrees(np.arccos(min(1, -n[1]))):.0f}deg"
        path_pts = None
        ys, xs = np.nonzero(ok_cells)
        if len(xs) >= 2:
            k = np.argmin(ys * 2 + np.abs(xs - gw / 2))  # nearest to the foot, near the centre line
            start = (ys[k], xs[k])
            cost = np.where(ok_cells, 1.0 + 3.0 * np.clip(1 - (clear - r_cells) / (2 * r_cells), 0, 1), np.inf)
            dist, prev = self.dijkstra(cost, start)
            reach = np.isfinite(dist)
            score = np.where(reach, -np.arange(gh)[:, None] + 0.3 * np.abs(np.arange(gw) - gw / 2)[None], np.inf)
            gy_, gx_ = np.unravel_index(np.argmin(score), score.shape)
            path, kk = [], gy_ * gw + gx_
            while kk >= 0:
                path.append((kk % gw, kk // gw))
                kk = prev[kk // gw, kk % gw]
            path = np.array(path[::-1], np.float32)
            if len(path) > 5:
                ker = np.ones(5) / 5
                pad = np.pad(path, ((2, 2), (0, 0)), mode="edge")
                path = np.stack([np.convolve(pad[:, i], ker, "valid") for i in range(2)], 1)
            if len(path) < 2:  # start cell is already the farthest one
                path = np.repeat(path, 2, axis=0)
            px, py = path[:, 0] * res - xmax, path[:, 1] * res
            path_pts = foot + px[:, None] * e1 + py[:, None] * e2
            seg = np.linalg.norm(np.diff(path_pts, axis=0), axis=1)
            along = np.concatenate([[0], np.cumsum(seg)])
            info += f", path {along[-1] * 100:.0f}cm"
            # ribbon (robot width) and centre line, projected into the image
            tang = np.gradient(path_pts, axis=0)
            tang /= np.linalg.norm(tang, axis=1, keepdims=True) + 1e-9
            side = np.cross(n, tang) * (a.robot_width / 2)
            front = path_pts[:, 2] > 0.02
            if front.sum() > 1:
                L = project((path_pts + side)[front], K)
                R = project((path_pts - side)[front], K)
                rib = out.copy()
                cv2.fillPoly(rib, [np.vstack([L, R[::-1]]).astype(np.int32)], (200, 40, 220))
                out = cv2.addWeighted(rib, 0.35, out, 0.65, 0)
                C = project(path_pts[front], K)
                al = along[front]
                for i in range(len(C) - 1):
                    t = al[i] / max(al[-1], 1e-6)
                    cv2.line(out, tuple(C[i].astype(int)), tuple(C[i + 1].astype(int)), (0, int(255 * t), 255), 3,
                             cv2.LINE_AA)
                for tk in np.arange(a.tick, al[-1], a.tick):
                    i = int(np.argmax(al >= tk))
                    cv2.circle(out, tuple(C[i].astype(int)), 4, (255, 255, 255), -1)
                    cv2.putText(out, f"{tk * 100:.0f}cm", tuple((C[i] + [7, 4]).astype(int)), FONT, 0.42,
                                (255, 255, 255), 1, cv2.LINE_AA)
                cv2.drawMarker(out, tuple(C[-1].astype(int)), (0, 255, 255), cv2.MARKER_STAR, 20, 2)
        # top-down inset: free green, obstacle red, path yellow, camera foot at the bottom centre
        bev = np.zeros((gh, gw, 3), np.uint8)
        bev[free] = (60, 160, 60)
        bev[occ] = (60, 60, 230)
        bev = bev[::-1]  # forward = up
        sc = 150 / max(gh, gw)
        bev = cv2.resize(bev, (max(1, int(gw * sc)), max(1, int(gh * sc))), interpolation=cv2.INTER_NEAREST)
        if path_pts is not None:
            q = np.stack([(path[:, 0] + 0.5) * sc, (gh - path[:, 1] - 0.5) * sc], 1).astype(np.int32)
            cv2.polylines(bev, [q], False, (0, 255, 255), 2)
        cv2.circle(bev, (bev.shape[1] // 2, bev.shape[0] - 1), 4, (255, 255, 255), -1)
        bh, bw = bev.shape[:2]
        y0, x0 = H - bh - 30, W - bw - 8
        if y0 > 0 and x0 > 0:
            out[y0:y0 + bh, x0:x0 + bw] = bev
            cv2.rectangle(out, (x0, y0), (x0 + bw, y0 + bh), (220, 220, 220), 1)
            cv2.putText(out, f"top view {2 * xmax * 100:.0f}x{ymax * 100:.0f}cm", (x0, y0 - 5), FONT, 0.4,
                        (255, 255, 255), 1, cv2.LINE_AA)
        cv2.putText(out, info, (8, H - 10), FONT, 0.48, (255, 255, 255), 1, cv2.LINE_AA)
        return out


class Sam2Proc(TorchProcessor):
    """SAM 2.1 prompted with the YOLO thread's latest boxes, else a point grid; each mask's distance."""
    name = "SAM2"

    def load(self):
        from ultralytics import SAM
        WEIGHTS.mkdir(exist_ok=True)
        self.model = SAM(str(WEIGHTS / self.args.sam2))
        self.name = f"SAM2 ({Path(self.args.sam2).stem}) + distance"
        self.pick_device()
        self.colors = np.random.default_rng(0).integers(60, 255, (64, 3))

    def process_frame(self, fr):
        img = fr.img
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
        labels = []
        if r.masks is not None:
            overlay = out.copy()
            for k, m in enumerate(r.masks.data.cpu().numpy().astype(bool)):
                if m.shape != (h, w):
                    m = cv2.resize(m.astype(np.uint8), (w, h)) > 0
                overlay[m] = self.colors[k % len(self.colors)]
                cs, _ = cv2.findContours(m.astype(np.uint8), cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
                cv2.drawContours(out, cs, -1, (255, 255, 255), 1)
                zz = fr.depth[m]
                zz = zz[zz > 0]
                if zz.size > 20 and m.any():
                    yy, xx = np.nonzero(m)
                    labels.append(((int(xx.mean()), int(yy.mean())), fmt_m(float(np.median(zz)))))
            out = cv2.addWeighted(overlay, 0.5, out, 0.5, 0)
        for (x, y), t in labels:
            cv2.putText(out, t, (x - 20, y), FONT, 0.55, (255, 255, 255), 2, cv2.LINE_AA)
        cv2.putText(out, mode, (6, h - 10), FONT, 0.55, (0, 255, 0), 2, cv2.LINE_AA)
        return out


class DetrProc(TorchProcessor):
    name = "DETR (resnet-50) + distance"

    def load(self):
        import torch
        from transformers import DetrForObjectDetection, DetrImageProcessor
        mid = "facebook/detr-resnet-50"
        # "no_timm" revision: torchvision backbone, so no timm dependency.
        self.proc = DetrImageProcessor.from_pretrained(mid, revision="no_timm")
        self.model = self.to_device(DetrForObjectDetection.from_pretrained(mid, revision="no_timm"))
        self.torch = torch

    def process_frame(self, fr):
        img = fr.img
        inp = self.proc(images=cv2.cvtColor(img, cv2.COLOR_BGR2RGB), return_tensors="pt",
                        size={"shortest_edge": self.args.detr_size, "longest_edge": 1333}).to(self.device)
        with self.torch.inference_mode():
            outs = self.model(**inp)
        r = self.proc.post_process_object_detection(outs, threshold=0.7, target_sizes=[img.shape[:2]])[0]
        labels = [self.model.config.id2label[int(i)] for i in r["labels"]]
        return draw_dets(img, r["boxes"].cpu().numpy(), labels, r["scores"].cpu().numpy(), fr.depth)


class DinoProc(TorchProcessor):
    """DINOv2 patch features, first three PCA components shown as RGB."""
    name = "DINOv2 PCA"

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
            feat = self.model(pixel_values=x).last_hidden_state[0, 1:].float()
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
    """Open-vocabulary detection from a text prompt (Grounding DINO tiny), with distances."""
    name = "Grounding DINO"

    def load(self):
        import torch
        from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor
        mid = "IDEA-Research/grounding-dino-tiny"
        self.proc = AutoProcessor.from_pretrained(mid)
        self.model = self.to_device(AutoModelForZeroShotObjectDetection.from_pretrained(mid))
        self.torch = torch
        self.name = f"Grounding DINO: {self.args.gdino_text}"

    def process_frame(self, fr):
        img = fr.img
        inp = self.proc(images=cv2.cvtColor(img, cv2.COLOR_BGR2RGB), text=self.args.gdino_text,
                        return_tensors="pt").to(self.device)
        with self.torch.inference_mode():
            outs = self.model(**inp)
        r = self.proc.post_process_grounded_object_detection(
            outs, inp.input_ids, box_threshold=0.35, text_threshold=0.25, target_sizes=[img.shape[:2]])[0]
        return draw_dets(img, r["boxes"].cpu().numpy(), r["labels"], r["scores"].cpu().numpy(), fr.depth,
                         (255, 160, 0))


class MediaPipeProc(Processor):
    """MediaPipe Holistic with metric 3D from the D405.

    Face landmarks come with a relative z (pixel units, smaller = nearer).
    The D405 depth around the nose gives the face's distance Zf; each landmark
    then gets Z = Zf + z * Zf / fx and is deprojected with the intrinsics, so
    the face mesh is in metres in the camera frame. Per eye the eyeball centre
    is 0.4 eye-widths behind the eye-corner midpoint along the face normal;
    the gaze ray runs from it through the iris centre and is drawn 25 cm long
    with true perspective. Hands and body joints are labelled with distances.
    """
    name = "MediaPipe pose/hands/face + 3D gaze"
    EYES = ((33, 133, 468), (263, 362, 473))

    def load(self):
        import mediapipe as mp
        self.device = "cpu"
        self.mp = mp
        self.holistic = mp.solutions.holistic.Holistic(
            model_complexity=self.args.mp_complexity, refine_face_landmarks=True,
            min_detection_confidence=0.5, min_tracking_confidence=0.5)
        fm = mp.solutions.face_mesh
        self.face_parts = [(list(c), col) for c, col in (
            (fm.FACEMESH_LIPS, (60, 60, 255)), (fm.FACEMESH_LEFT_EYE, (255, 160, 40)),
            (fm.FACEMESH_RIGHT_EYE, (255, 160, 40)), (fm.FACEMESH_LEFT_EYEBROW, (0, 200, 255)),
            (fm.FACEMESH_RIGHT_EYEBROW, (0, 200, 255)), (fm.FACEMESH_FACE_OVAL, (200, 200, 200)),
            (fm.FACEMESH_IRISES, (255, 255, 0)))]

    @staticmethod
    def _px(lms, w, h):
        return np.array([[p.x * w, p.y * h, p.z * w] for p in lms.landmark], np.float32)

    def _lines(self, out, pts, conns, color, th=1):
        for a, b in conns:
            if a < len(pts) and b < len(pts):
                cv2.line(out, tuple(pts[a][:2].astype(int)), tuple(pts[b][:2].astype(int)), color, th, cv2.LINE_AA)

    def metric_face(self, F, depth, K):
        """Pixel-space face landmarks -> metres in the camera frame (None without depth)."""
        u, v = F[1][:2]
        zf = depth_in_box(depth, u - 6, v - 6, u + 6, v + 6, shrink=1.0)
        if zf is None:
            return None, None
        fx = K[0]
        Z = zf + (F[:, 2] - F[1, 2]) * zf / fx
        return deproject(F[:, 0], F[:, 1], Z, K), zf

    def gaze(self, P):
        n = np.cross(P[152] - P[10], P[263] - P[33])
        n /= np.linalg.norm(n) + 1e-9
        if n[2] > 0:  # toward the camera
            n = -n
        rays = []
        for outer, inner, iris in self.EYES:
            mid = 0.5 * (P[outer] + P[inner])
            w = np.linalg.norm(P[outer] - P[inner])
            d = P[iris] - (mid - n * 0.4 * w)
            rays.append((P[iris], d / (np.linalg.norm(d) + 1e-9)))
        return n, rays

    def draw_inset(self, out, P, n, rays):
        """Top (x-z) and side (z-y) views in metres around the face."""
        s, H = 120, out.shape[0]
        nose = P[1]
        scale = s / 0.5  # 50 cm across
        for k, (ax0, ax1, label) in enumerate(((0, 2, "top"), (2, 1, "side"))):
            x0, y0 = 8 + k * (s + 8), H - s - 30
            sub = out[y0:y0 + s, x0:x0 + s]
            sub[:] = (sub * 0.3).astype(np.uint8)
            cv2.rectangle(out, (x0, y0), (x0 + s, y0 + s), (180, 180, 180), 1)
            cv2.putText(out, label, (x0 + 4, y0 + 14), FONT, 0.4, (220, 220, 220), 1)

            def pr(p):
                q = (p - nose) * scale
                return int(x0 + s / 2 + q[ax0]), int(y0 + s / 2 + q[ax1])
            # camera position
            cv2.drawMarker(out, pr(np.zeros(3)), (255, 255, 255), cv2.MARKER_TRIANGLE_UP, 8, 1)
            for a, b in ((33, 263), (10, 152)):
                cv2.line(out, pr(P[a]), pr(P[b]), (200, 200, 200), 1)
            cv2.arrowedLine(out, pr(nose), pr(nose + n * 0.15), (0, 255, 0), 1, tipLength=0.2)
            for (iris, d), col in zip(rays, ((255, 0, 255), (255, 255, 0))):
                cv2.line(out, pr(iris), pr(iris + d * 0.2), col, 1, cv2.LINE_AA)

    def process_frame(self, fr):
        img, depth, K = fr.img, fr.depth, fr.K
        H, W = img.shape[:2]
        rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        rgb.flags.writeable = False
        r = self.holistic.process(rgb)
        out = (img * 0.6).astype(np.uint8)
        hol = self.mp.solutions.holistic
        info = []
        if r.pose_landmarks:
            P = self._px(r.pose_landmarks, W, H)
            self._lines(out, P, hol.POSE_CONNECTIONS, (80, 255, 80), 2)
            for p, lm in zip(P, r.pose_landmarks.landmark):
                if lm.visibility > 0.5:
                    cv2.circle(out, tuple(p[:2].astype(int)), 3, (255, 255, 255), -1)
            info.append("pose")
        for lms, col, lab in ((r.left_hand_landmarks, (0, 220, 255), "L-hand"),
                              (r.right_hand_landmarks, (255, 180, 0), "R-hand")):
            if lms:
                P = self._px(lms, W, H)
                self._lines(out, P, hol.HAND_CONNECTIONS, col, 2)
                for p in P:
                    cv2.circle(out, tuple(p[:2].astype(int)), 3, (255, 255, 255), -1)
                z = depth_in_box(depth, *P[:, :2].min(0), *P[:, :2].max(0), shrink=0.6)
                cv2.putText(out, f"{lab} {fmt_m(z)}", tuple(P[0][:2].astype(int) + [8, 16]), FONT, 0.5, col, 1,
                            cv2.LINE_AA)
                info.append(lab)
        if r.face_landmarks:
            F = self._px(r.face_landmarks, W, H)
            for conns, col in self.face_parts:
                self._lines(out, F, conns, col, 1)
            P, zf = self.metric_face(F, depth, K)
            if P is not None:
                n, rays = self.gaze(P)
                cv2.arrowedLine(out, tuple(project(P[1], K)[0].astype(int)),
                                tuple(project(P[1] + n * 0.12, K)[0].astype(int)), (0, 255, 0), 2, cv2.LINE_AA,
                                tipLength=0.15)
                for (iris, d), col in zip(rays, ((255, 0, 255), (255, 255, 0))):
                    a, b = project(iris, K)[0], project(iris + d * 0.25, K)[0]
                    cv2.circle(out, tuple(a.astype(int)), 3, col, -1)
                    cv2.arrowedLine(out, tuple(a.astype(int)), tuple(b.astype(int)), col, 3, cv2.LINE_AA,
                                    tipLength=0.15)
                g = rays[0][1] + rays[1][1]
                g /= np.linalg.norm(g) + 1e-9
                yaw, pitch = np.degrees(np.arctan2(g[0], -g[2])), np.degrees(np.arctan2(-g[1], -g[2]))
                info.append(f"face {fmt_m(zf)}  gaze yaw {yaw:+.0f} pitch {pitch:+.0f} deg")
                self.draw_inset(out, P, n, rays)
                self.shared["gaze"] = (time.time(), P[1], g)
            else:
                info.append("face (no depth at nose)")
        cv2.putText(out, ", ".join(info) or "no person", (8, H - 10), FONT, 0.48, (255, 255, 255), 1, cv2.LINE_AA)
        return out


PROCESSORS = {"apriltag": AprilTagProc, "yolo": YoloProc, "depth": SensorDepthProc, "dav2": DAv2Proc,
              "floor": FloorProc, "sam2": Sam2Proc, "detr": DetrProc, "dino": DinoProc,
              "mediapipe": MediaPipeProc, "gdino": GroundingDinoProc}
DEFAULT_PROCS = "apriltag,yolo,depth,dav2,floor,sam2,detr,dino,mediapipe"


# --------------------------------------------------------------------------

def raw_view(src, args):
    fr = src.latest
    if fr is None:
        img = np.zeros((480, 1280, 3), np.uint8)
        return put_lines(img, [f"D405: {src.status}"], scale=0.6)
    img = fr.img.copy()
    dv = depth_colormap(fr.depth, args.min_depth, args.max_depth)
    h, w = fr.depth.shape
    z = depth_in_box(fr.depth, w / 2 - 6, h / 2 - 6, w / 2 + 6, h / 2 + 6, shrink=1.0)
    for im in (img, dv):
        cv2.drawMarker(im, (w // 2, h // 2), (255, 255, 255), cv2.MARKER_CROSS, 16, 1)
    lines = [f"capture  {fmt_time(fr.cap_us)} ({fr.clock})",
             f"receive  {fmt_time(fr.recv_us)}",
             f"recv interval {fr.interval_ms:6.1f} ms   ({src.fps:4.1f} fps)",
             f"cam  interval {fr.cap_interval_ms:6.1f} ms",
             f"latency capture->recv {(fr.recv_us - fr.cap_us) / 1000:6.1f} ms",
             f"#{fr.seq} {w}x{h}  centre {fmt_m(z)}  valid {(fr.depth > 0).mean():.0%}"]
    if src.status != "streaming":
        lines.append(src.status)
    put_lines(img, lines, scale=0.5)
    put_lines(dv, [f"depth {args.min_depth * 100:.0f}-{args.max_depth * 100:.0f} cm (near = red)"], scale=0.5)
    return np.hstack([img, dv])


def mosaic(src, procs, tile_h, cols):
    """Colour over depth on the left (spanning all rows), processor tiles on the right."""
    fr = src.latest
    ih, iw = fr.img.shape[:2] if fr is not None else (480, 640)
    tile_w = int(round(tile_h * iw / ih))
    tiles = [p.tile(tile_w, tile_h) for p in procs]
    rows = (len(tiles) + cols - 1) // cols
    tiles += [np.zeros((tile_h, tile_w, 3), np.uint8)] * (rows * cols - len(tiles))
    grid = np.vstack([np.hstack(tiles[r * cols:(r + 1) * cols]) for r in range(rows)])
    half = grid.shape[0] // 2
    lw = int(round(half * iw / ih))
    if fr is None:
        left = put_lines(np.zeros((grid.shape[0], lw, 3), np.uint8), [f"input: {src.status}"], scale=0.6)
    else:
        c = put_lines(cv2.resize(fr.img, (lw, half)),
                      [f"colour #{fr.seq}", f"capture {fmt_time(fr.cap_us)}",
                       f"recv interval {fr.interval_ms:5.1f} ms ({src.fps:4.1f} fps)"], scale=0.5)
        d = put_lines(cv2.resize(depth_colormap(fr.depth, src.args.min_depth, src.args.max_depth), (lw, half)),
                      ["depth (aligned to colour)"], scale=0.5)
        left = np.vstack([c, d])
        if left.shape[0] < grid.shape[0]:
            left = np.vstack([left, np.zeros((grid.shape[0] - left.shape[0], lw, 3), np.uint8)])
    cv2.line(left, (lw - 1, 0), (lw - 1, left.shape[0]), (255, 255, 255), 2)
    return np.hstack([left, grid])


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--proc", default=DEFAULT_PROCS, help=f"comma list from {','.join(PROCESSORS)}")
    ap.add_argument("--serial", help="RealSense serial number (default: first device)")
    ap.add_argument("--width", type=int, default=640)
    ap.add_argument("--height", type=int, default=480)
    ap.add_argument("--fps", type=int, default=30)
    ap.add_argument("--filter", action="store_true", help="RealSense spatial/temporal/hole-filling depth filters")
    ap.add_argument("--min-depth", type=float, default=0.07, help="metres (D405 works from about 7 cm)")
    ap.add_argument("--max-depth", type=float, default=0.8, help="metres; depth colour range and point-cloud cut-off")
    ap.add_argument("--device", default="cuda", help="torch device for the DNN processors (cuda/cpu)")
    ap.add_argument("--rotate", type=int, default=0, choices=[0, 90, 180, 270])
    ap.add_argument("--tag-family", default="36h11", choices=["36h11", "36h10", "25h9", "16h5"])
    ap.add_argument("--tag-size", type=float, default=0.03, help="AprilTag black-square edge length [m]")
    ap.add_argument("--yolo", default="yolo26n.pt,yolo11n.pt", help="weights, first loadable wins")
    ap.add_argument("--imgsz", type=int, default=640, help="YOLO input size")
    ap.add_argument("--sam2", default="sam2.1_t.pt")
    ap.add_argument("--sam-imgsz", type=int, default=512)
    ap.add_argument("--depth-model", default="depth-anything/Depth-Anything-V2-Small-hf")
    ap.add_argument("--depth-size", type=int, default=392, help="Depth Anything input size (multiple of 14)")
    ap.add_argument("--floor-tol", type=float, default=0.008, help="floor plane distance tolerance [m]")
    ap.add_argument("--floor-max-tilt", type=float, default=60, help="max angle between floor normal and camera up [deg]")
    ap.add_argument("--robot-width", type=float, default=0.10, help="robot width for the path [m]")
    ap.add_argument("--robot-height", type=float, default=0.30, help="points higher than this above the floor are ignored [m]")
    ap.add_argument("--grid-res", type=float, default=0.01, help="top-down grid cell [m]")
    ap.add_argument("--tick", type=float, default=0.05, help="path distance tick [m]")
    ap.add_argument("--detr-size", type=int, default=480, help="DETR shortest edge")
    ap.add_argument("--dino-model", default="facebook/dinov2-small")
    ap.add_argument("--dino-size", type=int, default=448, help="DINOv2 input long edge")
    ap.add_argument("--gdino-text", default="a person. a cup. a bottle. a robot.")
    ap.add_argument("--mp-complexity", type=int, default=1, choices=[0, 1, 2], help="MediaPipe pose model size")
    ap.add_argument("--tile-height", type=int, default=240, help="processing tile height (width follows the image)")
    ap.add_argument("--cols", type=int, default=3, help="processing tiles per row (right of the input)")
    ap.add_argument("--record", metavar="DIR", help="record both windows to DIR/raw.mp4, DIR/proc.mp4 (real-time 10 fps)")
    ap.add_argument("--duration", type=float, default=0, help="quit after N seconds (0 = run until q)")
    ap.add_argument("--snapshot-interval", type=float, default=0, help="also save snapshots every N seconds")
    args = ap.parse_args()

    names = [n.strip() for n in args.proc.split(",") if n.strip()]
    for n in names:
        if n not in PROCESSORS:
            raise SystemExit(f"unknown processor {n!r}; choose from {','.join(PROCESSORS)}")
    os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
    # transformers' lazy module loader is not thread-safe: resolve every class
    # here, once, before the processor threads import them concurrently.
    if "mediapipe" in names:
        import mediapipe  # noqa: F401
    if set(names) & {"yolo", "dav2", "sam2", "detr", "dino", "gdino"}:
        import transformers  # noqa: F401
        from transformers import (AutoImageProcessor, AutoModel, AutoModelForDepthEstimation,  # noqa: F401
                                  AutoModelForZeroShotObjectDetection, AutoProcessor,
                                  DetrForObjectDetection, DetrImageProcessor)
        from ultralytics import SAM, YOLO  # noqa: F401

    rotate_ref = [args.rotate]
    src = RealSenseSource(args, rotate_ref)
    src.start()
    shared = {}
    procs = [PROCESSORS[n](src, args, shared) for n in names]
    for p in procs:
        p.start()

    th = args.tile_height
    cv2.namedWindow("D405", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("D405", 1280, 480)
    if procs:
        cols = min(args.cols, len(procs))
        rows = (len(procs) + cols - 1) // cols
        full_w, full_h = int(th * 4 / 3 * (cols + rows / 2)), th * rows
        fit = min(1.0, 1900 / full_w, 1000 / full_h)
        cv2.namedWindow("Processing", cv2.WINDOW_NORMAL)
        cv2.resizeWindow("Processing", int(full_w * fit), int(full_h * fit))
    last_snap = t_start = time.time()
    writers, rec_fps, next_rec = {}, 10.0, time.time()
    while True:
        raw = raw_view(src, args)
        cv2.imshow("D405", raw)
        mos = None
        if procs:
            mos = mosaic(src, procs, th, min(args.cols, len(procs)))
            cv2.imshow("Processing", mos)
        # recording: fixed-rate sampling of what is on screen, so playback is real time
        if args.record and src.latest is not None and time.time() >= next_rec:
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
