"""Headless rollout + render of a trained KXR robot policy (walk or getup).

Same reason as walking-hand-rl/tools/render_hand.py for going around mjlab's
own ``play``: its viser command-slider widget hard-codes a 0.1 m/s minimum,
which some of these robots' commanded speeds sit under.
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


def build_env_and_policy(task, checkpoint, device):
  from dataclasses import asdict

  from mjlab.envs import ManagerBasedRlEnv
  from mjlab.rl import MjlabOnPolicyRunner, RslRlVecEnvWrapper
  from mjlab.tasks.registry import load_env_cfg, load_rl_cfg, load_runner_cls

  import kxr_rl.tasks  # noqa: F401  (registers <Robot>-Walk / -Getup)

  env_cfg = load_env_cfg(task, play=True)
  env_cfg.scene.num_envs = 1
  agent_cfg = load_rl_cfg(task)

  env = ManagerBasedRlEnv(cfg=env_cfg, device=device, render_mode=None)
  wrapped = RslRlVecEnvWrapper(env, clip_actions=agent_cfg.clip_actions)

  runner_cls = load_runner_cls(task) or MjlabOnPolicyRunner
  runner = runner_cls(wrapped, asdict(agent_cfg), device=device)
  runner.load(checkpoint, load_cfg={"actor": True}, strict=True, map_location=device)
  policy = runner.get_inference_policy(device=device)
  return env, wrapped, policy


def make_cameras(base_height, expected_travel=0.0):
  """Side view (contact/posture) + a WORLD-FIXED view (translation is
  unambiguous there -- a tracking camera makes a walking and a treadmilling
  robot look identical).

  The fixed camera has to be framed on the DISTANCE, not on the robot: sized
  off base height alone it gives kxrl4t a 0.6 m field of view for a 1.5 m walk
  and the robot simply leaves the shot.
  """
  side = mujoco.MjvCamera()
  side.type = mujoco.mjtCamera.mjCAMERA_FREE
  side.azimuth = 90.0
  side.elevation = -12.0
  side.distance = max(0.5, 8.0 * base_height)
  side.lookat[:] = [0.0, 0.0, base_height]

  fixed = mujoco.MjvCamera()
  fixed.type = mujoco.mjtCamera.mjCAMERA_FREE
  fixed.azimuth = 90.0
  fixed.elevation = -20.0
  fixed.distance = max(1.0, 16.0 * base_height, 1.3 * expected_travel)
  fixed.lookat[:] = [max(0.3, 0.5 * expected_travel), 0.0, base_height]

  top = mujoco.MjvCamera()
  top.type = mujoco.mjtCamera.mjCAMERA_FREE
  top.azimuth = 90.0
  top.elevation = -89.0
  top.distance = max(0.6, 10.0 * base_height)
  top.lookat[:] = [0.0, 0.0, base_height]
  return {"fixed": fixed, "side": side, "top": top}


def main():
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--robot", required=True)
  parser.add_argument("--mode", choices=("walk", "getup"), default="walk")
  parser.add_argument("--checkpoint", type=os.path.abspath, required=True)
  parser.add_argument("--seconds", type=float, default=None)
  parser.add_argument("--fps", type=int, default=30)
  parser.add_argument("--width", type=int, default=640)
  parser.add_argument("--height", type=int, default=480)
  parser.add_argument("--out-prefix", type=os.path.abspath, required=True)
  parser.add_argument("--device", default="cuda:0")
  args = parser.parse_args()

  os.environ.setdefault("MUJOCO_GL", "egl")
  out_prefix = os.path.abspath(args.out_prefix)
  os.makedirs(os.path.dirname(out_prefix), exist_ok=True)

  import kxr_rl.tasks as tasks
  task = tasks.task_id(args.robot, args.mode)

  with home_path(args.robot).open() as f:
    home_height = float(json.load(f)["base_height"])

  env, wrapped, policy = build_env_and_policy(task, args.checkpoint, args.device)

  seconds_hint = args.seconds if args.seconds is not None else (
    6.0 if args.mode == "getup" else 10.0)
  command = env.command_manager.get_command("twist")
  commanded_speed = 0.0 if command is None else abs(float(command[0, 0]))

  model = env.sim.mj_model
  data = mujoco.MjData(model)
  renderer = mujoco.Renderer(model, height=args.height, width=args.width)
  cameras = make_cameras(base_height=home_height,
                         expected_travel=commanded_speed * seconds_hint)
  writers = {
    name: imageio.get_writer("{}_{}.mp4".format(out_prefix, name), fps=args.fps)
    for name in cameras
  }

  seconds = args.seconds if args.seconds is not None else (6.0 if args.mode == "getup" else 10.0)

  obs = wrapped.get_observations()
  if isinstance(obs, tuple):
    obs = obs[0]
  n_steps = int(seconds / env.step_dt)
  stride = max(1, int(round(1.0 / (args.fps * env.step_dt))))

  positions = []
  with torch.inference_mode():
    for step in range(n_steps):
      step_out = wrapped.step(policy(obs))
      obs = step_out[0]

      qpos = env.scene["robot"].data.root_link_pos_w[0].cpu().numpy()
      positions.append(qpos.copy())

      if step % stride:
        continue
      data.qpos[:] = _to_numpy(env.sim.data.qpos)[0]
      data.qvel[:] = _to_numpy(env.sim.data.qvel)[0]
      mujoco.mj_forward(model, data)
      for name, cam in cameras.items():
        if name != "fixed":
          cam.lookat[0] = float(data.qpos[0])
          cam.lookat[1] = float(data.qpos[1])
        renderer.update_scene(data, camera=cam)
        writers[name].append_data(renderer.render())

  for writer in writers.values():
    writer.close()

  positions = np.array(positions)
  travel_xy = np.linalg.norm(positions[-1][:2] - positions[0][:2])
  height_final = positions[-1][2]
  print("{} {}: rendered {:.1f}s, net travel {:.3f} m ({:.4f} m/s), final z={:.3f} m".format(
    args.robot, args.mode, seconds, travel_xy, travel_xy / seconds, height_final))
  for name in cameras:
    print("wrote {}_{}.mp4".format(out_prefix, name))


if __name__ == "__main__":
  main()
