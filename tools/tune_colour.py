"""
Fit the Soul's COLOUR to the owner's reference sheet by measurement.

Companion to `tools/tune_silhouette.py` (which fits the shape). The reference
is a picture, so the only honest comparison is between the mean sRGB of the
CHARACTER PIXELS ONLY -- background excluded via the silhouette mask -- never
the mean of the whole frame, which is dominated by backdrop.

The palette knobs live in `ember_gradient()` in `tools/build_soul_blender.py`
and are overridden through the SOUL_TUNING environment variable, the same
mechanism the silhouette fitter uses.

Usage
-----
    python tools/tune_colour.py --score     # current palette vs reference
    python tools/tune_colour.py --sweep     # coordinate descent on the ramp
"""

import argparse
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tune_silhouette as ts  # noqa: E402

import numpy as np  # noqa: E402
from PIL import Image  # noqa: E402

NAMES = ts.NAMES


def mean_colour(path, box, mask):
    x0, x1, y0, y1 = box
    A = np.asarray(Image.open(path).convert("RGB")).astype(float)[y0:y1, x0:x1]
    return A[:mask.shape[0], :mask.shape[1]][mask].mean(0)


def colour_score(png):
    """Return (mean over views of |delta|, per-view rows)."""
    ref = ts.ref_masks()
    ours = [ts._mask(png, b) for b in ts.OUR_BOX]
    rows = []
    for i in range(4):
        r = mean_colour(ts.REFERENCE, ts.REF_BOX[i], ref[i])
        o = mean_colour(png, ts.OUR_BOX[i], ours[i])
        rows.append((NAMES[i], r, o))
    R = np.mean([r for _, r, _ in rows], 0)
    O = np.mean([o for _, _, o in rows], 0)
    return R, O, rows


def report(R, O, rows, label=""):
    print(f"\n=== {label} ===")
    print(f"{'view':8s} {'reference':>22s} {'ours':>22s}   delta")
    for n, r, o in rows:
        print(f"{n:8s} ({r[0]:5.1f},{r[1]:5.1f},{r[2]:5.1f})   "
              f"({o[0]:5.1f},{o[1]:5.1f},{o[2]:5.1f})   "
              f"{o[0]-r[0]:+6.1f}{o[1]-r[1]:+6.1f}{o[2]-r[2]:+6.1f}")
    d = O - R
    print(f"{'ALL':8s} ({R[0]:5.1f},{R[1]:5.1f},{R[2]:5.1f})   "
          f"({O[0]:5.1f},{O[1]:5.1f},{O[2]:5.1f})   "
          f"{d[0]:+6.1f}{d[1]:+6.1f}{d[2]:+6.1f}")
    print(f"  ratios  G/R ref {R[1]/R[0]:.3f} ours {O[1]/O[0]:.3f}   "
          f"B/R ref {R[2]/R[0]:.3f} ours {O[2]/O[0]:.3f}")
    return d


def loss(tuning):
    ts.build(tuning)
    R, O, rows = colour_score(ts.TURNAROUND)
    d = O - R
    # Hue error (ratios) matters more than overall exposure for "does it look
    # like the same character", so weight the ratio error too.
    ratio_err = abs(O[1] / O[0] - R[1] / R[0]) + abs(O[2] / O[0] - R[2] / R[0])
    return float(np.abs(d).mean() + 60.0 * ratio_err), R, O, rows


GRID = {
    "rust_r": [0.30, 0.36, 0.42],
    "rust_g": [0.09, 0.14, 0.19],
    "rust_b": [0.03, 0.06, 0.09],
    "ember_r": [0.88, 0.94, 0.99],
    "ember_g": [0.38, 0.46, 0.54],
    "ember_b": [0.04, 0.09, 0.14],
    "gold_r": [0.94, 0.99, 1.00],
    "gold_g": [0.63, 0.70, 0.77],
    "gold_b": [0.10, 0.18, 0.26],
    "cream_r": [0.96, 1.00],
    "cream_g": [0.88, 0.92, 0.96],
    "cream_b": [0.40, 0.52, 0.64],
}
ORDER = ["ember_g", "gold_g", "ember_b", "gold_b", "cream_b", "gold_r",
         "rust_g", "rust_b", "ember_r", "cream_g", "rust_r", "cream_r"]


def sweep(rounds=3):
    best = {}
    L, R, O, rows = loss(best)
    print(f"start loss {L:.4f}", flush=True)
    for r in range(rounds):
        improved = False
        for key in ORDER:
            if key not in GRID:
                continue
            for v in GRID[key]:
                trial = dict(best)
                trial[key] = v
                L2, R2, O2, rows2 = loss(trial)
                if L2 < L - 1e-3:
                    L, best, improved = L2, trial, True
                    print(f"  r{r} {key}={v}  loss {L:.4f}", flush=True)
        print(f"round {r} loss {L:.4f}", flush=True)
        if not improved:
            break
    return best, L


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--score", action="store_true")
    ap.add_argument("--sweep", action="store_true")
    ap.add_argument("--rounds", type=int, default=3)
    ap.add_argument("--tuning")
    a = ap.parse_args()

    if a.tuning:
        t = json.loads(a.tuning)
        ts.build(t)
        R, O, rows = colour_score(ts.TURNAROUND)
        report(R, O, rows, f"tuning={t}")
        return
    if a.sweep:
        best, L = sweep(a.rounds)
        print("\nBEST COLOUR TUNING:", json.dumps(best, indent=2))
        ts.build(best)
        R, O, rows = colour_score(ts.TURNAROUND)
        report(R, O, rows, "best")
        return
    ts.build({})
    R, O, rows = colour_score(ts.TURNAROUND)
    report(R, O, rows, "current palette")


if __name__ == "__main__":
    main()
