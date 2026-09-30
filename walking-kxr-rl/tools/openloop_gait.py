"""What can this morphology do WITHOUT a policy? An open-loop trot, searched.

    uv run tools/openloop_gait.py --robot kxrl4t
    uv run tools/openloop_gait.py --robot kxrl4t --render out/kxrl4t_openloop

Drives every support limb with a hand-written gait -- its stride joint on a
sine, its lift joint on the swing half of the same cycle, diagonal limbs in
phase -- over a small grid of period / swing amplitude / lift, and reports the
fastest one. No learning, no reward.

This exists because "the policy walks at 0.001 m/s" does not say whether the
robot cannot walk, the reward is wrong, or the physics is wrong -- and the
answer changes what to fix. On kxrl4t the answer was 0.194 m/s open loop
against 0.0013 m/s learned, which located the problem squarely in the reward
(the posture term priced the only workable gait at zero) rather than in the
morphology. It also gives the speed the commanded band has to be sized
against: the derivation in env_cfgs._SpeedScale is calibrated against this.

Joint directions are measured, not assumed: the sign that swings a tip forward
and the sign that lifts it are read off the model at the home pose, so a limb
kxreus mounted mirrored still gets driven the right way.
"""

import argparse
import itertools
import os
import sys

# Must precede the mujoco import -- the renderer picks its backend at load.
os.environ.setdefault("MUJOCO_GL", "egl")

import mujoco  # noqa: E402
import numpy as np  # noqa: E402

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _REPO_ROOT)

import kxr_rl  # noqa: F401,E402
from kxr_rl import robot_cfg  # noqa: E402
from kxr_rl.robots import load_robot_spec  # noqa: E402

PERIODS = (0.6, 1.0, 1.6)
AMPLITUDES = (0.3, 0.6, 0.9)
# Negative lift presses the swing limb DOWN instead of picking it up. That is a
# real strategy for a sprawling crawler whose tips cannot clear much: modulate
# normal load so the pushing limbs grip and the returning ones slide.
LIFTS = (0.0, 0.3, 0.6, 0.9, -0.3, -0.6)
# Excursion used to read off which way a joint swings its tip. Small enough to
# stay in the neighbourhood of the home stance, large enough not to be read
# across a local extremum -- a central difference at +-0.2 rad reports the
# WRONG lift direction on kxrl4t, whose home roll angle sits exactly at the
# minimum of its tip-height curve (both directions lift from there).
PROBE_RAD = 0.6


def build(name):
  from mjlab.entity.entity import Entity

  spec = Entity(robot_cfg.get_robot_cfg(name)).spec
  spec.worldbody.add_geom(
    name="floor", type=mujoco.mjtGeom.mjGEOM_PLANE, size=[5.0, 5.0, 0.1],
    contype=1, conaffinity=1)
  # The scene mjlab builds brings its own lighting; this bare one does not, and
  # an unlit render is a black rectangle.
  spec.worldbody.add_light(
    pos=[0.0, 0.0, 2.0], dir=[0.0, 0.0, -1.0],
    type=mujoco.mjtLightType.mjLIGHT_DIRECTIONAL,
    diffuse=[0.8, 0.8, 0.8], ambient=[0.3, 0.3, 0.3])
  return spec.compile()


def _home_qpos(model, home):
  qpos = np.zeros(model.nq)
  qpos[0:3] = home.pos
  qpos[3:7] = home.rot
  for joint, value in home.joint_pos.items():
    jid = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_JOINT, joint)
    if jid >= 0:
      qpos[model.jnt_qposadr[jid]] = value
  return qpos


def limb_drive(model, robot, home_qpos, offsets):
  """Per support limb: (stride joint, its forward sign, lift joint, up sign).

  Signs come from the tip's measured response at the home pose, so "+amplitude
  swings this tip forward" holds for every limb regardless of how it is
  mounted.
  """
  data = mujoco.MjData(model)
  drive = {}
  for key, limb in robot.support.items():
    tip = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_BODY, limb.foot_link)
    sole = np.array(offsets.get(key, (0.0, 0.0, 0.0)))

    def contact_at(joint, delta):
      data.qpos[:] = home_qpos
      jid = mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_JOINT, joint)
      data.qpos[model.jnt_qposadr[jid]] += delta
      mujoco.mj_forward(model, data)
      return data.xpos[tip] + data.xmat[tip].reshape(3, 3) @ sole

    rest = contact_at(limb.joints[0], 0.0)
    best_x = best_z = None
    for joint in limb.joints:
      plus, minus = contact_at(joint, PROBE_RAD), contact_at(joint, -PROBE_RAD)
      # Stride: fore-aft travel is monotonic in the swing joint, so the two
      # ends bracket it. Lift: take whichever end raises the tip furthest
      # above where it rests, which is well defined even at a minimum.
      dx = plus[0] - minus[0]
      if best_x is None or abs(dx) > abs(best_x[1]):
        best_x = (joint, dx)
      for sign, end in ((1.0, plus), (-1.0, minus)):
        gain = end[2] - rest[2]
        if best_z is None or gain > best_z[1]:
          best_z = (joint, gain, sign)
    drive[key] = (best_x[0], float(np.sign(best_x[1]) or 1.0),
                  best_z[0], best_z[2])
  return drive


def rollout(model, robot, home_qpos, drive, phases, period, amplitude, lift,
            seconds, frames=None, renderer=None, camera=None):
  data = mujoco.MjData(model)
  data.qpos[:] = home_qpos
  mujoco.mj_forward(model, data)
  actuator = {
    mujoco.mj_id2name(model, mujoco.mjtObj.mjOBJ_JOINT, model.actuator_trnid[a, 0]): a
    for a in range(model.nu)
  }
  home_of = {
    joint: home_qpos[model.jnt_qposadr[
      mujoco.mj_name2id(model, mujoco.mjtObj.mjOBJ_JOINT, joint)]]
    for limb in robot.support.values() for joint in limb.joints
  }
  start = data.qpos[0:2].copy()
  stride_every = max(1, int(round(1.0 / (30.0 * model.opt.timestep))))
  for step in range(int(seconds / model.opt.timestep)):
    t = step * model.opt.timestep
    for key, (stride_joint, fwd, lift_joint, up) in drive.items():
      phase = 2.0 * np.pi * (t / period + phases[key])
      data.ctrl[actuator[stride_joint]] = (
        home_of[stride_joint] + fwd * amplitude * np.sin(phase))
      swing = max(0.0, np.cos(phase))
      data.ctrl[actuator[lift_joint]] = home_of[lift_joint] + up * lift * swing
    mujoco.mj_step(model, data)
    if not np.all(np.isfinite(data.qpos)):
      return None
    if frames is not None and step % stride_every == 0:
      renderer.update_scene(data, camera=camera)
      frames.append(renderer.render())
  displacement = data.qpos[0:2] - start
  return float(displacement[0]), float(data.qpos[2])


def main() -> None:
  parser = argparse.ArgumentParser(description=__doc__)
  parser.add_argument("--robot", required=True)
  parser.add_argument("--seconds", type=float, default=6.0)
  parser.add_argument("--render", default=None,
                      help="write <prefix>_openloop.mp4 of the best gait")
  args = parser.parse_args()
  os.environ.setdefault("MUJOCO_GL", "egl")

  import json

  robot = load_robot_spec(args.robot)
  home = robot_cfg.get_home_keyframe(args.robot)
  with robot_cfg.home_path(args.robot).open() as f:
    offsets = json.load(f).get("foot_offsets") or {}

  model = build(args.robot)
  home_qpos = _home_qpos(model, home)
  drive = limb_drive(model, robot, home_qpos, offsets)
  phases = dict(zip(robot.support, robot.gait_offsets()))

  print("=== {} open-loop trot search ===".format(args.robot))
  for key, (sj, fwd, lj, up) in drive.items():
    print("  {:<6s} stride {:<20s} ({:+.0f})  lift {:<20s} ({:+.0f})  phase {:.1f}"
          .format(key, sj, fwd, lj, up, phases[key]))

  best = None
  for period, amplitude, lift in itertools.product(PERIODS, AMPLITUDES, LIFTS):
    result = rollout(model, robot, home_qpos, drive, phases,
                     period, amplitude, lift, args.seconds)
    if result is None:
      continue
    forward, height = result
    if best is None or forward > best[0]:
      best = (forward, height, period, amplitude, lift)

  if best is None or best[0] <= 0.0:
    print("\nno open-loop gait moved this robot forward -- the morphology, the "
          "home stance or the contact model is the problem, not the reward")
    sys.exit(1)

  forward, height, period, amplitude, lift = best
  print("\nbest: {:+.3f} m in {:.1f}s = {:.3f} m/s   (final base z {:.4f} m)"
        .format(forward, args.seconds, forward / args.seconds, height))
  print("      period {:.1f}s  swing {:.1f} rad  lift {:.1f} rad".format(
    period, amplitude, lift))
  print("\nThis is the speed the commanded band should be sized against; see "
        "env_cfgs._SpeedScale.")

  if args.render:
    import imageio.v2 as imageio

    renderer = mujoco.Renderer(model, height=480, width=640)
    # World-fixed, framed on the whole run: a camera that tracks the robot
    # makes walking and treadmilling look identical.
    camera = mujoco.MjvCamera()
    camera.type = mujoco.mjtCamera.mjCAMERA_FREE
    camera.azimuth, camera.elevation = 90.0, -12.0
    camera.distance = max(1.0, 1.6 * abs(forward))
    camera.lookat[:] = [forward / 2.0, 0.0, home.pos[2]]
    frames = []
    rollout(model, robot, home_qpos, drive, phases, period, amplitude, lift,
            args.seconds, frames=frames, renderer=renderer, camera=camera)
    out = os.path.abspath("{}_openloop.mp4".format(args.render))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    imageio.mimsave(out, frames, fps=30)
    print("wrote {}".format(out))


if __name__ == "__main__":
  main()
