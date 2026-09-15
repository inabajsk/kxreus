"""PPO hyperparameters, shared across every KXR robot's velocity task.

Same recipe as walking-hand-rl (a small network is enough: these are 10-22
actuator flat-ground problems, not a rough-terrain quadruped), parameterized
only by ``experiment_name`` so each robot's checkpoints land in their own
``logs/rsl_rl/<robot>_<preset>/`` directory.
"""

from mjlab.rl import RslRlModelCfg, RslRlOnPolicyRunnerCfg, RslRlPpoAlgorithmCfg


def kxr_ppo_runner_cfg(
  experiment_name: str, max_iterations: int = 1501
) -> RslRlOnPolicyRunnerCfg:
  return RslRlOnPolicyRunnerCfg(
    actor=RslRlModelCfg(
      hidden_dims=(256, 128, 64),
      activation="elu",
      obs_normalization=True,
      distribution_cfg={
        "class_name": "GaussianDistribution",
        "init_std": 0.8,
        "std_type": "scalar",
      },
    ),
    critic=RslRlModelCfg(
      hidden_dims=(256, 128, 64),
      activation="elu",
      obs_normalization=True,
    ),
    algorithm=RslRlPpoAlgorithmCfg(
      value_loss_coef=1.0,
      use_clipped_value_loss=True,
      clip_param=0.2,
      entropy_coef=0.005,
      num_learning_epochs=5,
      num_mini_batches=4,
      learning_rate=1.0e-3,
      schedule="adaptive",
      gamma=0.99,
      lam=0.95,
      desired_kl=0.01,
      max_grad_norm=1.0,
    ),
    experiment_name=experiment_name,
    save_interval=100,
    num_steps_per_env=24,
    max_iterations=max_iterations,
  )
