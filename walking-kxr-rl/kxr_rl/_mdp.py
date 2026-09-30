"""The MDP namespace env_cfgs.py builds against: upstream's velocity mdp plus
this repo's one addition (``getup_hold``), merged into one namespace so the
env cfg can write ``mdp.foot_gait`` and ``mdp.getup_hold`` side by side.
"""

from src.tasks.velocity.mdp import *  # noqa: F401, F403

from .rewards import *  # noqa: F401, F403
