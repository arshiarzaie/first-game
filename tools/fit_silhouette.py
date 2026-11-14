"""
Coordinate-descent driver for `tools/tune_silhouette.py`.

Kept separate so the sweep can be started with a seed (values a previous,
interrupted run already proved out) instead of always restarting from the
committed defaults -- each evaluation costs a full Blender rebuild.

    python tools/fit_silhouette.py --seed '{"head_ry":0.60,"head_rx":0.70,"head_rz":0.64}'
"""

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tune_silhouette as ts  # noqa: E402

ORDER = ["head_ry", "head_rx", "head_rz", "head_cz",
         "yoke_r0", "yoke_r1", "chest_rx", "chest_ry", "chest_cz",
         "shoulder_z", "elbow_x", "elbow_z", "wrist_x", "wrist_z",
         "paw_x", "paw_z", "shoulder_x",
         "tummy_rx", "pelvis_rx",
         "thigh_r", "knee_r", "ankle_r", "boot_r", "hip_x"]


def run(seed, rounds=3):
    best = dict(seed)
    best_loss = ts.loss(best)
    print(f"seed {seed} -> loss {best_loss:.4f}", flush=True)
    for r in range(rounds):
        improved = False
        for key in ORDER:
            if key not in ts.GRID:
                continue
            for v in ts.GRID[key]:
                trial = dict(best)
                trial[key] = v
                L = ts.loss(trial)
                if L < best_loss - 1e-4:
                    best_loss, best, improved = L, trial, True
                    print(f"  r{r} {key}={v}  loss {L:.4f}", flush=True)
        print(f"round {r} loss {best_loss:.4f}", flush=True)
        if not improved:
            break
    return best, best_loss


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", default="{}")
    ap.add_argument("--rounds", type=int, default=3)
    a = ap.parse_args()
    best, L = run(json.loads(a.seed), a.rounds)
    print("\nBEST_TUNING=" + json.dumps(best))
    print(f"BEST_LOSS={L:.5f}")
    io, rm, wb, d = ts.objective(best)
    ts.report(io, d, "best")


if __name__ == "__main__":
    main()
