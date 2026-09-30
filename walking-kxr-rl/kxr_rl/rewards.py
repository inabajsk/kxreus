"""The one reward term every KXR robot needs that upstream does not ship:
rising to a target height and HOLDING there, for the get-up task.

Everything else (locomotion, orientation, gait, posture) is upstream's own
``src.tasks.velocity.mdp`` stock recipe -- unlike walking-hand-rl's fingertip
crawl, a KXR biped IS the morphology mjlab's velocity task was built for, so no
bespoke gait-shaping reward is needed. Ported verbatim from
``walking_hand_rl/rewards.py`` (it was already fully generic -- reads only
``root_link_pos_w`` / ``root_com_lin_vel_w``, nothing hand-specific).
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import torch

from mjlab.entity import Entity
from mjlab.managers.scene_entity_config import SceneEntityCfg

if TYPE_CHECKING:
  from mjlab.envs import ManagerBasedRlEnv


def getup_hold(
  env: ManagerBasedRlEnv,
  target_height: float,
  asset_cfg: SceneEntityCfg = SceneEntityCfg("robot"),
) -> torch.Tensor:
  """Reward RISING to a target height and HOLDING there -- for the get-up task.

  A plain exp-kernel on height is farmable by a lunge: spike through the target
  for one frame, bank the reward, fall back. This closes it two ways: ONE-SIDED
  height (clamp at the target, so overshoot earns nothing extra) and a
  STILLNESS gate (multiply by exp(-|root linear velocity|), so a bouncing body
  scores ~0 even while passing through the target height).

  ``target_height`` is meant to be a robot's own kinematic height ceiling
  (``measure_home.py:max_kinematic_height``), not its settled resting height
  -- a crouched robot can sit near its resting height without ever pushing
  its torso further up, which for a multi-limb sprawler (arms and legs both
  reaching the floor) scores a collapsed-looking pose as a success. Height
  alone, one-sided, is what keeps this the SAME reward for a 2-leg biped
  standing up straight and a 6-limb robot pushing its torso up on fully
  extended limbs -- no per-robot special-casing.
  """
  asset: Entity = env.scene[asset_cfg.name]
  height = asset.data.root_link_pos_w[:, 2]
  reached = torch.clamp(height / target_height, max=1.0)
  vel = torch.norm(asset.data.root_com_lin_vel_w, dim=1)
  still = torch.exp(-4.0 * vel)
  return reached * still
