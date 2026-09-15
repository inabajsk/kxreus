"""Self-penetration audit for a posed KXR model.

Self-collision is switched off for every robot here (the MJCF conversion does
it, and the get-up task needs a body that can lie on itself). That has a
consequence nothing in the physics will ever report: a pose whose arm passes
through its own torso is held by the simulator without complaint. The first
solved stance for kxrl6 did exactly that -- level, on all four tips, and with
one arm driven 14.8 mm into the other -- so both ``measure_home.py`` and
``check.py`` measure it explicitly. A stance the hardware cannot adopt is not a
stance.

``mj_geomDistance`` is a pure distance query and ignores contype/conaffinity,
which is what lets this run against the same model the tasks use.
"""

from __future__ import annotations

import mujoco

# Distance beyond which the query need not look.
_DISTANCE_HORIZON = 0.05


def collision_geoms(model: mujoco.MjModel) -> list[int]:
  return [g for g in range(model.ngeom)
          if (model.geom_contype[g] or model.geom_conaffinity[g])
          and model.geom_dataid[g] >= 0]


def baseline_overlaps(model: mujoco.MjModel) -> set[tuple[int, int]]:
  """Link pairs that already interpenetrate with every joint at zero.

  The KXR meshes ship with a few of these -- the two halves of a gripper
  overlap by 2.4 mm on kxrl4d and kxrl2g straight out of the URDF. They are
  modelling artifacts, not something a stance caused, so they are measured once
  and excluded; what matters is overlap the POSE introduces.
  """
  data = mujoco.MjData(model)
  mujoco.mj_resetData(model, data)
  data.qpos[2] = 1.0  # clear of the floor; only link-vs-link matters here
  mujoco.mj_forward(model, data)
  geoms = collision_geoms(model)
  out: set[tuple[int, int]] = set()
  for i, g1 in enumerate(geoms):
    for g2 in geoms[i + 1:]:
      if model.geom_bodyid[g1] == model.geom_bodyid[g2]:
        continue
      if mujoco.mj_geomDistance(model, data, g1, g2, _DISTANCE_HORIZON, None) < 0.0:
        out.add((g1, g2))
  return out


def self_penetration(model: mujoco.MjModel, data: mujoco.MjData,
                     baseline: set[tuple[int, int]]):
  """Deepest NEW link-link overlap in the current pose: (metres, (body, body))."""
  geoms = collision_geoms(model)
  worst = 0.0
  worst_pair = None
  for i, g1 in enumerate(geoms):
    for g2 in geoms[i + 1:]:
      b1, b2 = model.geom_bodyid[g1], model.geom_bodyid[g2]
      if b1 == b2 or (g1, g2) in baseline:
        continue
      # Parent/child links touch by construction at every joint.
      if model.body_parentid[b1] == b2 or model.body_parentid[b2] == b1:
        continue
      dist = mujoco.mj_geomDistance(model, data, g1, g2, _DISTANCE_HORIZON, None)
      if dist < -worst:
        worst = -dist
        worst_pair = (mujoco.mj_id2name(model, mujoco.mjtObj.mjOBJ_BODY, b1),
                      mujoco.mj_id2name(model, mujoco.mjtObj.mjOBJ_BODY, b2))
  return worst, worst_pair
