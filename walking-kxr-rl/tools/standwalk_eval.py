"""Stand-up-THEN-walk for one KXR robot, switching between its Getup and Walk
policies by root-height hysteresis. Same idea as walking-hand-rl's
tools/standwalk_eval.py, generalized: the switch thresholds scale with the
robot's OWN measured standing height instead of a fixed number, since these
range from kxrl4t's 0.026 m crouch to kxrl2g's 0.175 m stand.

    z = root height
    mode = "getup" if z < z_low   (z_low  = 0.55 * home_height)
         = "walk"  if z > z_high  (z_high = 0.75 * home_height)
         = previous mode otherwise (hysteresis dead-band)

No episode reset happens during the eval (huge episode length, play mode), so
the whole clip is one continuous physical trajectory -- any apparent "warp" in
a training-time video is the episode reset, not this.
"""

import argparse
import json
import os
import sys

import imageio.v2 as imageio
import mujoco
import numpy as np
import torch

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _REPO_ROOT)

import kxr_rl  # noqa: F401
from kxr_rl.robot_cfg import home_path  # noqa: E402


def _to_numpy(array):
  if hasattr(array, "detach"):
    return array.detach().cpu().numpy()
  return array.numpy()


def build_env(task, device):
  from mjlab.envs import ManagerBasedRlEnv
  from mjlab.rl import RslRlVecEnvWrapper
  from mjlab.tasks.registry import load_env_cfg, load_rl_cfg

  import kxr_rl.tasks  # noqa: F401

  env_cfg = load_env_cfg(task, play=True)
  env_cfg.scene.num_envs = 1
  agent_cfg = load_rl_cfg(task)

  env = ManagerBasedRlEnv(cfg=env_cfg, device=device, render_mode=None)
  wrapped = RslRlVecEnvWrapper(env, clip_actions=agent_cfg.clip_actions)
  return env, wrapped, agent_cfg


def load_policy(wrapped, agent_cfg, checkpoint, device, task):
  from dataclasses import asdict

  from mjlab.rl import MjlabOnPolicyRunner
  from mjlab.tasks.registry import load_runner_cls

  runner_cls = load_runner_cls(task) or MjlabOnPolicyRunner
  runner = runner_cls(wrapped, asdict(agent_cfg), device=device)
  runner.load(os.path.abspath(checkpoint), load_cfg={"actor": True},
              strict=True, map_location=device)
  return runner.get_inference_policy(device=device)


def make_cameras(base_height):
  fixed = mujoco.MjvCamera()
  fixed.type = mujoco.mjtCamera.mjCAMERA_FREE
  fixed.azimuth = 90.0
  fixed.elevation = -18.0
  fixed.distance = max(1.0, 16.0 * base_height)
  fixed.lookat[:] = [0.3, 0.0, base_height]

  side = mujoco.MjvCamera()
  side.type = mujoco.mjtCamera.mjCAMERA_FREE
  side.azimuth = 90.0
  side.elevation = -12.0
  side.distance = max(0.5, 8.0 * base_height)
  side.lookat[:] = [0.0, 0.0, base_height]
  return {"fixed": fixed, "side": side}


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--robot", required=True)
  parser.add_argument("--getup-checkpoint", type=os.path.abspath, required=True)
  parser.add_argument("--walk-checkpoint", type=os.path.abspath, required=True)
  parser.add_argument("--z-low-frac", type=float, default=0.55)
  parser.add_argument("--z-high-frac", type=float, default=0.75)
  parser.add_argument("--walk-vx", type=float, default=0.15)
  parser.add_argument("--seconds", type=float, default=12.0)
  parser.add_argument("--settle-seconds", type=float, default=1.0)
  parser.add_argument("--fps", type=int, default=30)
  parser.add_argument("--width", type=int, default=640)
  parser.add_argument("--height", type=int, default=480)
  parser.add_argument("--out-prefix", type=os.path.abspath, default=None)
  parser.add_argument("--device", default="cuda:0")
  args = parser.parse_args()

  os.environ.setdefault("MUJOCO_GL", "egl")

  with home_path(args.robot).open() as f:
    home_height = float(json.load(f)["base_height"])
  z_low = args.z_low_frac * home_height
  z_high = args.z_high_frac * home_height

  import kxr_rl.tasks as tasks
  # Both policies were trained on their own preset's env cfg (Getup starts
  # flat, Walk starts standing); running the eval on the GETUP task's env is
  # what makes the clip start from a fallen robot.
  task = tasks.task_id(args.robot, "getup")

  env, wrapped, agent_cfg = build_env(task, args.device)
  getup_policy = load_policy(wrapped, agent_cfg, args.getup_checkpoint, args.device, task)
  walk_policy = load_policy(wrapped, agent_cfg, args.walk_checkpoint, args.device, task)

  cmd = env.command_manager.get_term("twist")

  render = args.out_prefix is not None
  if render:
    out_prefix = os.path.abspath(args.out_prefix)
    os.makedirs(os.path.dirname(out_prefix), exist_ok=True)
    model = env.sim.mj_model
    data = mujoco.MjData(model)
    renderer = mujoco.Renderer(model, height=args.height, width=args.width)
    cameras = make_cameras(base_height=home_height)
    writers = {
      name: imageio.get_writer("{}_{}.mp4".format(out_prefix, name), fps=args.fps)
      for name in cameras
    }
    stride = max(1, int(round(1.0 / (args.fps * env.step_dt))))

  obs = wrapped.get_observations()
  if isinstance(obs, tuple):
    obs = obs[0]

  n_steps = int(args.seconds / env.step_dt)
  settle_steps = int(args.settle_seconds / env.step_dt)
  mode = "getup"
  z_hist, x_hist, mode_hist = [], [], []
  resets = 0

  with torch.inference_mode():
    for step in range(n_steps):
      root = env.scene["robot"].data.root_link_pos_w[0].cpu().numpy()
      z = float(root[2])

      if step >= settle_steps:
        if z < z_low:
          mode = "getup"
        elif z > z_high:
          mode = "walk"

      vx = args.walk_vx if mode == "walk" else 0.0
      cmd.command[:, 0] = vx
      cmd.command[:, 1] = 0.0
      cmd.command[:, 2] = 0.0

      policy = walk_policy if mode == "walk" else getup_policy
      step_out = wrapped.step(policy(obs))
      obs = step_out[0]
      dones = step_out[2] if len(step_out) > 2 else None
      if dones is not None and float(dones[0].cpu()) > 0.5:
        resets += 1

      z_hist.append(z)
      x_hist.append(float(root[0]))
      mode_hist.append(mode)

      if render and step % stride == 0:
        data.qpos[:] = _to_numpy(env.sim.data.qpos)[0]
        data.qvel[:] = _to_numpy(env.sim.data.qvel)[0]
        mujoco.mj_forward(model, data)
        for name, cam in cameras.items():
          if name == "side":
            cam.lookat[0] = float(data.qpos[0])
            cam.lookat[1] = float(data.qpos[1])
          renderer.update_scene(data, camera=cam)
          writers[name].append_data(renderer.render())

  if render:
    for writer in writers.values():
      writer.close()

  z_hist = np.array(z_hist)
  x_hist = np.array(x_hist)
  dt = env.step_dt

  print("=== {} stand-then-walk eval ===".format(args.robot))
  print("home_height={:.4f}  z_low={:.4f}  z_high={:.4f}".format(home_height, z_low, z_high))
  print("z: start {:.3f}  peak {:.3f}  final {:.3f} m".format(
    z_hist[0], z_hist.max(), z_hist[-1]))
  first_walk = mode_hist.index("walk") if "walk" in mode_hist else None
  if first_walk is None:
    print("mode: NEVER entered walk (z never crossed z_high={:.3f})".format(z_high))
  else:
    t_walk = first_walk * dt
    net_fwd = x_hist[-1] - x_hist[first_walk]
    dur = (len(x_hist) - 1 - first_walk) * dt
    print("first walk at t={:.2f}s (z={:.3f})".format(t_walk, z_hist[first_walk]))
    print("net forward during walk: {:+.3f} m over {:.1f}s ({:+.4f} m/s)".format(
      net_fwd, dur, net_fwd / dur if dur > 0 else 0.0))
  frac_walk = mode_hist.count("walk") / len(mode_hist)
  print("time in walk mode: {:.0%}   resets(dones): {}".format(frac_walk, resets))
  if render:
    for name in cameras:
      print("wrote {}_{}.mp4".format(out_prefix, name))


if __name__ == "__main__":
  main()
