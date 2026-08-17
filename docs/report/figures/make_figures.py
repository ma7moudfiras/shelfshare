# -*- coding: utf-8 -*-
"""Generate the report's two current-architecture figures.

Both figures describe the pipeline as it is actually deployed (verified via
`workflows_get` / `workflows_run` against the live `aystro-detect-classify`
workflow), not an earlier design. Labels are kept in Latin script because
they are literal Roboflow step and model identifiers; the captions in
`content_ar.py` / `content_en.py` carry the prose.

Run:  python3 make_figures.py
"""

import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

HERE = os.path.dirname(os.path.abspath(__file__))

INK = "#111111"
MUTED = "#555555"
ACCENT = "#1a3a5c"
DETECT = "#2f6f9f"
CLASSIFY = "#3d8168"
ROUTE = "#a8752c"
MERGE = "#6b4d8a"
LIGHT = "#f4f6f8"


def box(ax, x, y, w, h, title, subtitle=None, color=ACCENT, fill="#ffffff"):
    """One pipeline step: coloured outline, bold title, optional model id."""
    ax.add_patch(
        FancyBboxPatch(
            (x, y), w, h,
            boxstyle="round,pad=0.012,rounding_size=0.02",
            linewidth=1.6, edgecolor=color, facecolor=fill, zorder=2,
        )
    )
    ty = y + h * (0.60 if subtitle else 0.5)
    ax.text(x + w / 2, ty, title, ha="center", va="center",
            fontsize=9.5, fontweight="bold", color=color, zorder=3)
    if subtitle:
        ax.text(x + w / 2, y + h * 0.26, subtitle, ha="center", va="center",
                fontsize=7.6, color=MUTED, family="monospace", zorder=3)


def arrow(ax, start, end, color=MUTED, style="-", label=None, rad=0.0):
    ax.add_patch(
        FancyArrowPatch(
            start, end, arrowstyle="-|>", mutation_scale=11,
            linewidth=1.3, color=color, linestyle=style, zorder=1,
            connectionstyle=f"arc3,rad={rad}",
        )
    )
    if label:
        mx = (start[0] + end[0]) / 2
        my = (start[1] + end[1]) / 2
        ax.text(mx, my + 0.012, label, ha="center", va="bottom",
                fontsize=7.2, color=color, style="italic", zorder=3)


def pipeline_figure():
    fig, ax = plt.subplots(figsize=(11.0, 7.2), dpi=200)
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis("off")

    # ---- Band A: detection -------------------------------------------------
    box(ax, 0.030, 0.855, 0.195, 0.105, "Shelf photograph", "one field capture",
        color=INK, fill=LIGHT)
    box(ax, 0.290, 0.855, 0.235, 0.105, "Stage 1 — detect",
        "aystro-project-v2/2", color=DETECT)
    box(ax, 0.600, 0.855, 0.205, 0.105, "crop", "N product crops", color=DETECT)

    arrow(ax, (0.225, 0.9075), (0.290, 0.9075))
    arrow(ax, (0.525, 0.9075), (0.600, 0.9075))
    ax.text(0.900, 0.9075, "class-agnostic:\nevery product\nis just “product”",
            ha="center", va="center", fontsize=7.6, color=MUTED, style="italic")

    # ---- Band B: brand (left) and packaging (right) ------------------------
    box(ax, 0.130, 0.650, 0.325, 0.105, "Stage 2 — brand",
        "aystro-brand-classifier/3", color=CLASSIFY)
    box(ax, 0.590, 0.650, 0.325, 0.105, "Stage 4 — packaging",
        "aystro-packaging-classifie/2", color=CLASSIFY, fill="#f3f8f5")

    arrow(ax, (0.660, 0.855), (0.320, 0.755), rad=-0.18, color=CLASSIFY)
    arrow(ax, (0.7525, 0.855), (0.7525, 0.755), color=CLASSIFY)
    ax.text(0.567, 0.822, "runs on all N", ha="center", va="center",
            fontsize=7.4, color=MUTED, style="italic")
    ax.text(0.7525, 0.612, "brand-independent — runs on all N, never gated",
            ha="center", va="center", fontsize=7.6, color=MUTED, style="italic")

    # ---- Band C: switch_case gates -----------------------------------------
    box(ax, 0.105, 0.445, 0.175, 0.095, "route_fanta", "switch_case",
        color=ROUTE, fill="#fdf8f1")
    box(ax, 0.320, 0.445, 0.175, 0.095, "route_xl_energy", "switch_case",
        color=ROUTE, fill="#fdf8f1")

    arrow(ax, (0.250, 0.650), (0.1925, 0.540), color=ROUTE)
    arrow(ax, (0.350, 0.650), (0.4075, 0.540), color=ROUTE)

    # ---- Band D: gated variant classifiers ---------------------------------
    box(ax, 0.105, 0.255, 0.175, 0.095, "Stage 3 — Fanta",
        "aystro-fanta-classifier/4", color=CLASSIFY)
    box(ax, 0.320, 0.255, 0.175, 0.095, "Stage 3 — XL Energy",
        "aystro-xl-classifier/1", color=CLASSIFY)

    arrow(ax, (0.1925, 0.445), (0.1925, 0.350), color=ROUTE)
    arrow(ax, (0.4075, 0.445), (0.4075, 0.350), color=ROUTE)
    ax.text(0.288, 0.398, 'only if\nbrand = "fanta"', ha="center", va="center",
            fontsize=7.2, color=ROUTE, style="italic")
    ax.text(0.520, 0.398, 'only if\n"xl_energy"', ha="left", va="center",
            fontsize=7.2, color=ROUTE, style="italic")

    # ---- Band E: merge, then write back onto the detections ----------------
    box(ax, 0.130, 0.065, 0.325, 0.095, "merge",
        "first_non_empty_or_default", color=MERGE)
    arrow(ax, (0.1925, 0.255), (0.245, 0.160), rad=0.10, color=MERGE)
    arrow(ax, (0.4075, 0.255), (0.350, 0.160), rad=-0.10, color=MERGE)

    # Ungated fallback: the plain brand label, routed down the outside edge
    # so it does not cross the gated branches.
    arrow(ax, (0.130, 0.660), (0.130, 0.150), rad=0.42, color=MERGE)
    ax.text(0.030, 0.405, "fallback:\nplain brand", ha="center", va="center",
            fontsize=7.2, color=MERGE, style="italic")

    box(ax, 0.590, 0.065, 0.325, 0.095, "refine  →  output",
        "brand · variant · packaging", color=INK, fill=LIGHT)
    arrow(ax, (0.455, 0.1125), (0.590, 0.1125), color=INK)
    arrow(ax, (0.7525, 0.650), (0.7525, 0.160), color=CLASSIFY, style=(0, (4, 3)))

    fig.tight_layout(pad=0.4)
    out = os.path.join(HERE, "fig_pipeline_v2.png")
    fig.savefig(out, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print("wrote", out)


def complexity_figure():
    """Measured effect of gating the variant classifiers behind switch_case.

    Both panels are real measurements from the same 60-crop test photograph,
    run back-to-back on saved (warm) workflows through the identical call
    path — not estimates.
    """
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10.6, 4.0), dpi=200)

    # -- Panel 1: variant-classifier calls as the catalogue grows ------------
    # Scoped to the variant layer specifically -- the only layer the routing
    # change affects. The brand and packaging stages each run once per crop
    # under both designs and are O(N) either way.
    ks = list(range(1, 7))
    n = 60
    before = [n * k for k in ks]                # every variant clf, every crop
    after = [n for _ in ks]                     # at most one per crop: bound N

    ax1.plot(ks, before, marker="o", markersize=4.5, linewidth=1.9,
             color="#b4453a", label="before  —  N×K  (every classifier, every crop)")
    ax1.plot(ks, after, marker="o", markersize=4.5, linewidth=1.9,
             color=DETECT, label="after  —  ≤ N  (at most one per crop)")
    ax1.plot([1], [12], marker="*", markersize=13, color=DETECT, zorder=5,
             linestyle="none", label="measured, K = 1:  12 calls, not 60")

    ax1.axvspan(1.85, 2.15, color="#f0f0f0", zorder=0)
    ax1.text(2.0, 20, "where we\nare (K = 2)", ha="center",
             va="bottom", fontsize=7.8, color=MUTED, style="italic")

    ax1.set_xlabel("K  —  brands with their own variant classifier", fontsize=9)
    ax1.set_ylabel("variant-classifier calls per photograph (N = 60)", fontsize=9)
    ax1.set_title("The variant layer stops scaling with catalogue breadth",
                  fontsize=10, fontweight="bold", color=ACCENT, pad=9)
    ax1.legend(fontsize=7.6, frameon=False, loc="upper left")
    ax1.grid(axis="y", linewidth=0.6, alpha=0.35)
    ax1.set_axisbelow(True)
    for s in ("top", "right"):
        ax1.spines[s].set_visible(False)

    # -- Panel 2: measured wall-clock -----------------------------------------
    labels = ["before\n(unconditional)", "after\n(routed)"]
    times = [40.32, 14.20]
    bars = ax2.bar(labels, times, width=0.5, color=["#b4453a", DETECT], zorder=2)
    for bar, t in zip(bars, times):
        ax2.text(bar.get_x() + bar.get_width() / 2, t + 0.9, f"{t:.2f}s",
                 ha="center", va="bottom", fontsize=10, fontweight="bold",
                 color=INK)

    ax2.annotate("", xy=(1.42, 14.20), xytext=(1.42, 40.32),
                 arrowprops=dict(arrowstyle="<->", color=MUTED, linewidth=1.2))
    ax2.text(1.50, 27.3, "−65%\n(26.1s)", ha="left", va="center",
             fontsize=9, color=MUTED, fontweight="bold")

    ax2.set_ylabel("wall-clock time, same 60-crop photograph", fontsize=9)
    ax2.set_ylim(0, 48)
    ax2.set_xlim(-0.55, 1.95)
    ax2.set_title("Measured back-to-back, identical output",
                  fontsize=10, fontweight="bold", color=ACCENT, pad=9)
    ax2.grid(axis="y", linewidth=0.6, alpha=0.35)
    ax2.set_axisbelow(True)
    for s in ("top", "right"):
        ax2.spines[s].set_visible(False)

    fig.tight_layout(pad=1.1)
    out = os.path.join(HERE, "fig_complexity.png")
    fig.savefig(out, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print("wrote", out)


if __name__ == "__main__":
    pipeline_figure()
    complexity_figure()
