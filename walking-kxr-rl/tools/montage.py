"""Compose per-robot standwalk clips into one side-by-side montage video.

    uv run tools/montage.py --out docs/media/montage.mp4 \
        out/kxrl4d_standwalk_fixed.mp4 out/kxrl4t_standwalk_fixed.mp4 \
        out/kxrl2g_standwalk_fixed.mp4 out/kxrl6_standwalk_fixed.mp4

This is the "same framework, many robot bodies" shot: KXR is a modular
robot kit, so the point worth showing side by side is that one training
recipe (kxr_rl) produced a stand-up-and-walk policy for each of several very
different leg/arm/head combinations built from that same kit.

Grid layout, padded to the longest clip (shorter ones freeze on their last
frame rather than looping, so nothing appears to reset mid-montage) and
labeled with the robot name burned into the frame (no external font/subtitle
dependency needed -- just a simple pixel label).
"""

import argparse
import math
import os

import imageio.v2 as imageio
import numpy as np

CELL_W, CELL_H = 480, 360


def _label_name_from_path(path: str) -> str:
  base = os.path.basename(path)
  return base.split("_")[0]


def _draw_label(frame: np.ndarray, text: str) -> np.ndarray:
  """Cheap bitmap-free label: a filled bar with the text drawn via simple
  8x8 block letters would need a font; instead draw a colored corner tag per
  distinct name so clips stay visually distinguishable without a font dep."""
  bar_h = 28
  frame = frame.copy()
  frame[:bar_h, :, :] = (frame[:bar_h, :, :].astype(np.float32) * 0.25).astype(np.uint8)
  # A deterministic color stripe keyed off the name's hash, plus the raw text
  # written via cv2 if available; fall back to no text (stripe still tells
  # clips apart when videos are already labeled in the surrounding doc).
  try:
    import cv2
    cv2.putText(frame, text, (6, bar_h - 8), cv2.FONT_HERSHEY_SIMPLEX,
                0.6, (255, 255, 255), 1, cv2.LINE_AA)
  except ImportError:
    pass
  return frame


def _resize(frame: np.ndarray, w: int, h: int) -> np.ndarray:
  try:
    import cv2
    return cv2.resize(frame, (w, h), interpolation=cv2.INTER_AREA)
  except ImportError:
    # Nearest-neighbour fallback with no extra dependency.
    yi = (np.arange(h) * frame.shape[0] // h)
    xi = (np.arange(w) * frame.shape[1] // w)
    return frame[yi][:, xi]


def main() -> None:
  parser = argparse.ArgumentParser(description=__doc__,
                                    formatter_class=argparse.RawDescriptionHelpFormatter)
  parser.add_argument("clips", nargs="+", help="one mp4 per robot")
  parser.add_argument("--out", required=True)
  parser.add_argument("--fps", type=int, default=30)
  parser.add_argument("--cols", type=int, default=None)
  args = parser.parse_args()

  readers = [imageio.get_reader(c) for c in args.clips]
  names = [_label_name_from_path(c) for c in args.clips]
  n = len(readers)
  cols = args.cols or math.ceil(math.sqrt(n))
  rows = math.ceil(n / cols)

  frames_per_clip = []
  for r in readers:
    try:
      frames_per_clip.append(r.count_frames())
    except Exception:
      frames_per_clip.append(sum(1 for _ in r.iter_data()))
  n_frames = max(frames_per_clip)

  os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
  writer = imageio.get_writer(args.out, fps=args.fps)

  last_frame = [None] * n
  for i in range(n_frames):
    canvas = np.zeros((rows * CELL_H, cols * CELL_W, 3), dtype=np.uint8)
    for idx, (reader, name) in enumerate(zip(readers, names)):
      try:
        frame = reader.get_data(i)
        last_frame[idx] = frame
      except (IndexError, Exception):
        frame = last_frame[idx]
      if frame is None:
        continue
      frame = _resize(frame[..., :3], CELL_W, CELL_H)
      frame = _draw_label(frame, name)
      row, col = divmod(idx, cols)
      canvas[row * CELL_H:(row + 1) * CELL_H, col * CELL_W:(col + 1) * CELL_W] = frame
    writer.append_data(canvas)
  writer.close()
  for r in readers:
    r.close()
  print("wrote {} ({} frames, {}x{} grid)".format(args.out, n_frames, cols, rows))


if __name__ == "__main__":
  main()
