"""Honest evaluation of a trained KXR walk policy: does it WALK, or fake it?

    uv run tools/gait_diag.py --robot kxrl4t --checkpoint policies/kxrl4t_walk.pt

Mean reward and episode length both go up for a policy that has learned to
stand very still, and for one that plants its feet and skates along without
lifting them. Neither shows up in the training log, so this measures the
things that actually distinguish walking:

* **net travel / speed** in the world frame, and the base height trace, so a
  fall or a collapse cannot hide behind a long episode;
* **stance slip ratio** -- how fast a limb tip slides over the ground while it
  is carrying load, relative to how fast the body is moving. Near 0 means the
  tip is planted and the body is pulled past it (walking); near 1 means the tip
  is travelling with the body (skating). This is the metric that caught a
  skating gait on JAXON, where the cause turned out to be MuJoCo's default
  ``impratio=1`` making sliding physically optimal, not a reward-shaping
  problem -- see $KXR_IMPRATIO in kxr_rl/env_cfgs.py;
* **duty factor and the contact pattern** per limb, so "it never actually
  picked a foot up" is visible rather than inferred.
"""

import argparse
import os
import sys

import mujoco
import numpy as np
import torch

_TOOLS = os.path.dirname(os.path.abspath(__file__))
_REPO_ROOT = os.path.dirname(_TOOLS)
sys.path.insert(0, _REPO_ROOT)
sys.path.insert(0, _TOOLS)

import kxr_rl  # noqa: F401,E402
from kxr_rl.robot_cfg import foot_site_name  # noqa: E402
from kxr_rl.robots import load_robot_spec  # noqa: E402
from render_robot import build_env_and_policy  # noqa: E402

# A limb tip is "in stance" when its body is genuinely pressing on the floor,
# not merely grazing it.
STANCE_FORCE_N = 0.05

# mjlab namespaces every entity's sites and bodies in the scene it compiles.
_ENTITY_PREFIX = "robot/"


def _resolve(model, objtype: int, name: str) -> int:
  """Look a name up in the compiled SCENE model, which prefixes entity names."""
  for candidate in (_ENTITY_PREFIX + name, name):
    found = mujoco.mj_name2id(model, objtype, candidate)
    if found >= 0:
      return found
  raise KeyError("{!r} not found in the compiled model".format(name))


def main() -> None:
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--robot", required=True)
  parser.add_argument("--checkpoint", type=os.path.abspath, required=True)
  parser.add_argument("--seconds", type=float, default=10.0)
  parser.add_argument("--seed", type=int, default=0,
                      help="seed for this rollout. Play-mode resets randomize "
                           "terrain, friction and base COM and this policy is "
                           "bimodal across those draws, so measure the spread "
                           "by running the tool once PER SEED. Resetting inside "
                           "one process does NOT resample -- every rollout "
                           "after the first comes back byte-identical, which "
                           "reads as perfect repeatability rather than the flat "
                           "line it actually is.")
  parser.add_argument("--device", default="cuda:0")
  args = parser.parse_args()

  os.environ.setdefault("MUJOCO_GL", "egl")

  import kxr_rl.tasks as tasks
  robot = load_robot_spec(args.robot)
  limb_keys = list(robot.support)
  env, wrapped, policy = build_env_and_policy(
    tasks.task_id(args.robot, "walk"), args.checkpoint, args.device)

  model = env.sim.mj_model
  data = mujoco.MjData(model)
  site_ids = [_resolve(model, mujoco.mjtObj.mjOBJ_SITE, foot_site_name(k))
              for k in limb_keys]
  body_ids = [_resolve(model, mujoco.mjtObj.mjOBJ_BODY, link)
              for link in robot.support_links]

  dt = env.step_dt
  n_steps = int(args.seconds / dt)
  base_xy, base_z = [], []
  body_vel = []    # [T, 2] velocity in the BODY frame -- what the reward sees
  yaw = []
  tip_xy = []      # [T, L, 2] world position of each tip
  in_stance = []   # [T, L] bool

  obs = wrapped.get_observations()
  if isinstance(obs, tuple):
    obs = obs[0]

  with torch.inference_mode():
    for _ in range(n_steps):
      obs = wrapped.step(policy(obs))[0]
      data.qpos[:] = env.sim.data.qpos.detach().cpu().numpy()[0]
      data.qvel[:] = env.sim.data.qvel.detach().cpu().numpy()[0]
      mujoco.mj_forward(model, data)

      base_xy.append(data.qpos[0:2].copy())
      base_z.append(float(data.qpos[2]))
      vel_b = env.scene["robot"].data.root_link_lin_vel_b[0].cpu().numpy()
      body_vel.append(vel_b[:2].copy())
      qw, qx, qy, qz = data.qpos[3:7]
      yaw.append(np.arctan2(2 * (qw * qz + qx * qy),
                            1 - 2 * (qy * qy + qz * qz)))
      tip_xy.append(np.array([data.site_xpos[i][:2] for i in site_ids]))

      load = np.zeros(len(body_ids))
      force = np.zeros(6)
      for c in range(data.ncon):
        contact = data.contact[c]
        pair = (model.geom_bodyid[contact.geom1], model.geom_bodyid[contact.geom2])
        for limb, bid in enumerate(body_ids):
          if bid in pair:
            mujoco.mj_contactForce(model, data, c, force)
            load[limb] += abs(float(force[0]))
      in_stance.append(load > STANCE_FORCE_N)

  base_xy = np.array(base_xy)
  base_z = np.array(base_z)
  body_vel = np.array(body_vel)
  yaw = np.unwrap(np.array(yaw))
  tip_xy = np.array(tip_xy)
  in_stance = np.array(in_stance)

  base_speed = np.linalg.norm(np.diff(base_xy, axis=0), axis=1) / dt      # [T-1]
  tip_speed = np.linalg.norm(np.diff(tip_xy, axis=0), axis=2) / dt        # [T-1, L]
  stance = in_stance[1:] & in_stance[:-1]  # in contact across the whole interval

  travel = float(np.linalg.norm(base_xy[-1] - base_xy[0]))
  path = float(np.sum(np.linalg.norm(np.diff(base_xy, axis=0), axis=1)))
  moving = base_speed > 1e-4
  command = env.command_manager.get_command("twist")[0].cpu().numpy()
  print("=== {} walk, {:.1f}s ===".format(args.robot, args.seconds))
  print("commanded       vx={:.4f}  vy={:.4f}  wz={:.4f}".format(*command[:3]))
  print("net travel      {:.3f} m   ({:.4f} m/s mean)".format(travel, travel / args.seconds))
  print("path length     {:.3f} m   (path/net = {:.1f}; >>1 means it wanders "
        "rather than travels)".format(path, path / max(travel, 1e-6)))
  print("body-frame vel  vx {:+.4f} +- {:.4f}   vy {:+.4f} +- {:.4f} m/s".format(
    body_vel[:, 0].mean(), body_vel[:, 0].std(),
    body_vel[:, 1].mean(), body_vel[:, 1].std()))
  print("yaw             drift {:+.1f} deg over the clip".format(
    float(np.degrees(yaw[-1] - yaw[0]))))
  print("base z          min {:.4f}  mean {:.4f}  final {:.4f} m".format(
    base_z.min(), base_z.mean(), base_z[-1]))

  slip_mask = stance & moving[:, None]
  if slip_mask.any():
    slip = tip_speed[slip_mask] / np.maximum(
      np.broadcast_to(base_speed[:, None], tip_speed.shape)[slip_mask], 1e-6)
    print("stance slip     {:.3f}  (tip speed / base speed while loaded; "
          "~0 planted, ~1 skating)".format(float(slip.mean())))
  else:
    print("stance slip     n/a -- no limb was ever loaded while the body moved")

  print()
  print("per limb:      duty   mean stance-tip speed")
  for i, key in enumerate(limb_keys):
    duty = float(in_stance[:, i].mean())
    sp = tip_speed[:, i][stance[:, i]]
    print("  {:<10s}  {:5.1%}   {:.4f} m/s".format(
      key, duty, float(sp.mean()) if sp.size else float("nan")))

  # Contact pattern over the first two gait periods, one character per step.
  window = min(len(in_stance), int(2 * 0.6 / dt))
  print()
  print("contact pattern (first {:.1f}s, '#' = loaded):".format(window * dt))
  for i, key in enumerate(limb_keys):
    print("  {:<10s} {}".format(
      key, "".join("#" if v else "." for v in in_stance[:window, i])))



if __name__ == "__main__":
  main()
