"""
Fit the Soul's silhouette to the owner's reference sheet BY MEASUREMENT.

Why this exists
---------------
The owner's acceptance criterion is "make it exactly the reference image".
The reference (`tools/reference/golden-sun-character-turnaround.png`) is a
picture: it carries no metres, so nothing about it can be compared to the model
in absolute units. Only SCALE-INVARIANT ratios can be compared legitimately --
per-row silhouette width / figure height, and 2-D silhouette IoU.

This script drives `tools/build_soul_blender.py` (which reads its geometry
knobs from the SOUL_TUNING environment variable), renders the orthographic
4-view turnaround, and scores it against the reference. Run a sweep, keep the
winning knobs, and write them back into the build script.

Usage
-----
    # score the current committed geometry
    python tools/tune_silhouette.py --score

    # coordinate-descent sweep over the tunables
    python tools/tune_silhouette.py --sweep

    # score an arbitrary turnaround png
    python tools/tune_silhouette.py --png /tmp/soul_turnaround_v4.png
"""

import argparse
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "tools", "build_soul_blender.py")
TURNAROUND = "/tmp/soul_turnaround_v4.png"
REFERENCE = os.path.join(ROOT, "tools", "reference",
                         "golden-sun-character-turnaround.png")

# Blender lives in a venv under /tmp that a sandbox restart wipes; rebuild it
# on demand rather than failing with a confusing import error.
BVENV = "/tmp/bvenv"
STUBS = "/tmp/x11stubs"


def ensure_blender():
    py = os.path.join(BVENV, "bin", "python")
    if os.path.exists(py):
        return py
    setup = os.path.join(ROOT, "tools", "setup_headless_blender.sh")
    subprocess.run(["bash", setup], check=True, cwd=ROOT)
    return py


def build(tuning):
    """Rebuild the character with `tuning` applied; returns the turnaround path."""
    py = ensure_blender()
    env = dict(os.environ)
    env["SOUL_TUNE"] = "1"
    env["SOUL_TUNING"] = json.dumps(tuning)
    env["LD_LIBRARY_PATH"] = STUBS
    if os.path.exists(TURNAROUND):
        os.remove(TURNAROUND)
    r = subprocess.run([py, BUILD], cwd=ROOT, env=env,
                       capture_output=True, text=True)
    if not os.path.exists(TURNAROUND):
        sys.stderr.write(r.stdout[-4000:] + "\n" + r.stderr[-4000:] + "\n")
        raise SystemExit("build failed to produce a turnaround")
    return TURNAROUND


# --------------------------------------------------------------------------
# scoring (scale-invariant)
# --------------------------------------------------------------------------
from PIL import Image  # noqa: E402
import numpy as np  # noqa: E402

REF_BOX = [(20, 400, 100, 940), (445, 760, 100, 940),
           (765, 1150, 100, 940), (1185, 1536, 100, 940)]
OUR_BOX = [(i * 394, i * 394 + 384, 0, 420) for i in range(4)]
NAMES = ["front", "sideR", "back", "sideL"]


def _largest(m):
    """Keep only the biggest connected blob (kills backdrop speckle)."""
    h, w = m.shape
    seen = np.zeros_like(m, bool)
    best = None
    for sy in range(h):
        for sx in range(w):
            if m[sy, sx] and not seen[sy, sx]:
                stack = [(sy, sx)]
                seen[sy, sx] = True
                comp = []
                while stack:
                    y, x = stack.pop()
                    comp.append((y, x))
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1),
                                   (1, 1), (1, -1), (-1, 1), (-1, -1)):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            stack.append((ny, nx))
                if best is None or len(comp) > len(best):
                    best = comp
    out = np.zeros_like(m)
    for y, x in best:
        out[y, x] = True
    return out


def _mask(path, box):
    x0, x1, y0, y1 = box
    A = np.asarray(Image.open(path).convert("RGB")).astype(float)[y0:y1, x0:x1]
    # The reference backdrop is a vertical gradient: model it per row from the
    # outer columns, otherwise the whole frame reads as "character".
    edge = np.concatenate([A[:, :10, :].reshape(A.shape[0], -1, 3),
                           A[:, -10:, :].reshape(A.shape[0], -1, 3)], axis=1)
    bg = np.median(edge, axis=1)[:, None, :]
    return _largest(np.abs(A - bg).max(2) > 16)


_REF = None


def ref_masks():
    global _REF
    if _REF is None:
        _REF = [_mask(REFERENCE, b) for b in REF_BOX]
    return _REF


def _row_widths(m, n=60):
    """Width of each silhouette row, in units of the figure's own height."""
    h = m.shape[0]
    idx = np.linspace(0, h - 1, n).astype(int)
    out = []
    for j in idx:
        xs = np.nonzero(m[j])[0]
        out.append(((xs.max() - xs.min() + 1) if len(xs) else 0) / h)
    return np.array(out)


def _iou(R, O, gh=60, gw=72):
    def norm(m):
        h, w = m.shape
        s = gh / h
        nw = max(1, int(round(w * s)))
        a = np.asarray(Image.fromarray((m * 255).astype("uint8")).resize(
            (nw, gh), Image.BILINEAR)) > 127
        out = np.zeros((gh, gw), bool)
        x0 = (gw - nw) // 2
        out[:, x0:x0 + nw] = a[:, :gw] if nw > gw else a
        return out
    Rn, On = norm(R), norm(O)
    return (Rn & On).sum() / (Rn | On).sum()


def score(png):
    """Return (mean IoU, per-view detail). Lower/better error included."""
    ours = [_mask(png, b) for b in OUR_BOX]
    ref = ref_masks()
    ious, detail = [], []
    for i in range(4):
        iou = _iou(ref[i], ours[i])
        ious.append(iou)
        wr = _row_widths(ref[i])
        wo = _row_widths(ours[i])
        d = wo - wr
        detail.append({
            "view": NAMES[i], "iou": iou,
            "ref_max": float(wr.max()), "our_max": float(wo.max()),
            "row_mae": float(np.abs(d).mean()),
            "bands": {lbl: float(wo[int(a / 100 * 59):int(b / 100 * 59) + 1].mean()
                                - wr[int(a / 100 * 59):int(b / 100 * 59) + 1].mean())
                      for lbl, a, b in [("crown", 0, 30), ("head", 30, 50),
                                        ("torso", 50, 75), ("legs", 75, 100)]},
        })
    return float(np.mean(ious)), detail


def report(mean_iou, detail, label=""):
    print(f"\n=== {label} mean IoU {mean_iou:.4f} ===")
    for d in detail:
        b = d["bands"]
        print(f"  {d['view']:6s} IoU {d['iou']:.3f}  maxW/H ref {d['ref_max']:.3f} "
              f"ours {d['our_max']:.3f}  rowMAE {d['row_mae']:.3f}   "
              + "  ".join(f"{k} {v:+.3f}" for k, v in b.items()))


# --------------------------------------------------------------------------
# objective: IoU is the headline, row-MAE stops it trading shape for overlap
# --------------------------------------------------------------------------
def objective(tuning):
    png = build(tuning)
    mean_iou, detail = score(png)
    row_mae = float(np.mean([d["row_mae"] for d in detail]))
    # penalise the worst band so no single region can be ignored
    worst_band = max(max(abs(v) for v in d["bands"].values()) for d in detail)
    return mean_iou, row_mae, worst_band, detail


def loss(tuning):
    mean_iou, row_mae, worst_band, _ = objective(tuning)
    return -(mean_iou - 0.5 * row_mae - 0.5 * worst_band)


# --------------------------------------------------------------------------
# coordinate descent
# --------------------------------------------------------------------------
GRID = {
    "head_rx": [0.55, 0.60, 0.65, 0.70, 0.74],
    "head_ry": [0.42, 0.48, 0.54, 0.60, 0.66],
    "head_rz": [0.52, 0.56, 0.60, 0.64],
    "head_cz": [0.98, 1.01, 1.03, 1.06],
    "chest_rx": [0.37, 0.42, 0.47, 0.52],
    "chest_ry": [0.34, 0.39, 0.44],
    "chest_rz": [0.24, 0.265, 0.30],
    "chest_cz": [0.47, 0.495, 0.53],
    "tummy_rx": [0.41, 0.46, 0.51],
    "pelvis_rx": [0.42, 0.47, 0.52],
    "yoke_r0": [0.106, 0.14, 0.175, 0.21],
    "yoke_r1": [0.098, 0.13, 0.16, 0.20],
    "shoulder_x": [0.112, 0.14, 0.17],
    "shoulder_z": [0.55, 0.60, 0.65],
    "elbow_x": [0.205, 0.235, 0.265],
    "elbow_z": [0.495, 0.545, 0.595],
    "wrist_x": [0.25, 0.28, 0.31],
    "wrist_z": [0.43, 0.48, 0.53],
    "paw_x": [0.25, 0.28, 0.312],
    "paw_z": [0.416, 0.47, 0.52],
    "thigh_r": [0.068, 0.085, 0.10],
    "knee_r": [0.058, 0.072, 0.086],
    "ankle_r": [0.048, 0.060, 0.072],
    "boot_r": [0.050, 0.065, 0.080],
    "hip_x": [0.078, 0.095, 0.112],
}


def sweep(rounds=3, order=None):
    order = order or ["head_ry", "head_rx", "head_rz", "head_cz",
                      "yoke_r0", "yoke_r1", "chest_rx", "chest_ry", "chest_cz",
                      "shoulder_z", "elbow_x", "elbow_z", "wrist_x", "wrist_z",
                      "paw_x", "paw_z", "shoulder_x",
                      "tummy_rx", "pelvis_rx",
                      "thigh_r", "knee_r", "ankle_r", "boot_r", "hip_x"]
    best = {}
    best_loss = loss(best)
    print(f"start loss {best_loss:.4f}", flush=True)
    for r in range(rounds):
        improved = False
        for key in order:
            if key not in GRID:
                continue
            cur = best.get(key)
            for v in GRID[key]:
                if cur is not None and v == cur:
                    continue
                trial = dict(best)
                trial[key] = v
                L = loss(trial)
                if L < best_loss - 1e-4:
                    best_loss, best, improved = L, trial, True
                    cur = v
                    print(f"  r{r} {key}={v}  loss {L:.4f}", flush=True)
        print(f"round {r} done, loss {best_loss:.4f}", flush=True)
        if not improved:
            break
    return best, best_loss


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--score", action="store_true")
    ap.add_argument("--sweep", action="store_true")
    ap.add_argument("--png")
    ap.add_argument("--rounds", type=int, default=3)
    ap.add_argument("--tuning")
    a = ap.parse_args()

    if a.png:
        m, d = score(a.png)
        report(m, d, a.png)
        return
    if a.tuning:
        t = json.loads(a.tuning)
        io, rm, wb, d = objective(t)
        report(io, d, f"tuning={t}")
        print(f"  rowMAE {rm:.4f}  worstBand {wb:.4f}  LOSS {-(io - 0.5*rm - 0.5*wb):.4f}")
        return
    if a.sweep:
        best, L = sweep(a.rounds)
        print("\nBEST TUNING:", json.dumps(best, indent=2))
        print("LOSS", L)
        io, rm, wb, d = objective(best)
        report(io, d, "best")
        return
    m, d = score(build({}))
    report(m, d, "current committed geometry")


if __name__ == "__main__":
    main()
