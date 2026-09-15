"""KXR modular robots as mjlab task packages.

Importing this package makes the upstream unitree_rl_mjlab checkout importable
(fetched on first use, see ``_bootstrap.py``). It does NOT register tasks --
``import kxr_rl.tasks`` does that.
"""

from ._bootstrap import ensure_upstream, repo_root, upstream_dir

ensure_upstream()

__all__ = ["ensure_upstream", "repo_root", "upstream_dir"]
