# -*- coding: utf-8 -*-
"""Generate the report's figures.

Every number plotted here is a measurement read back from the platform's own
tooling -- model evaluations, training timestamps, and live workflow runs --
not an estimate. The architecture figure describes the pipeline as actually
deployed (verified by reading the live workflow specification), not a design
sketch.

Labels are kept in Latin script because they are literal model and step
identifiers; the captions in `content_ar.py` / `content_en.py` carry the prose
in each language.

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
WARN = "#b4453a"
LIGHT = "#f4f6f8"


def box(ax, x, y, w, h, title, subtitle=None, color=ACCENT, fill="#ffffff",
        title_size=9.0, sub_size=7.0):
    """One pipeline step: coloured outline, bold title, optional model id."""
    ax.add_patch(
        FancyBboxPatch(
            (x, y), w, h,
            boxstyle="round,pad=0.010,rounding_size=0.018",
            linewidth=1.6, edgecolor=color, facecolor=fill, zorder=2,
        )
    )
    ty = y + h * (0.62 if subtitle else 0.5)
    ax.text(x + w / 2, ty, title, ha="center", va="center",
            fontsize=title_size, fontweight="bold", color=color, zorder=3)
    if subtitle:
        ax.text(x + w / 2, y + h * 0.25, subtitle, ha="center", va="center",
                fontsize=sub_size, color=MUTED, family="monospace", zorder=3)


def arrow(ax, start, end, color=MUTED, style="-", rad=0.0, width=1.3):
    ax.add_patch(
        FancyArrowPatch(
            start, end, arrowstyle="-|>", mutation_scale=10,
            linewidth=width, color=color, linestyle=style, zorder=1,
            connectionstyle=f"arc3,rad={rad}",
        )
    )


# --------------------------------------------------------------- figure 1

def pipeline_figure():
    """The deployed multi-stage architecture, all four routed branches."""
    fig, ax = plt.subplots(figsize=(12.0, 7.6), dpi=200)
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis("off")

    # ---- Band A: detection -------------------------------------------------
    box(ax, 0.030, 0.870, 0.180, 0.092, "Shelf photograph", "one field capture",
        color=INK, fill=LIGHT)
    box(ax, 0.265, 0.870, 0.215, 0.092, "Stage 1 — detect",
        "aystro-project-v2/2", color=DETECT)
    box(ax, 0.535, 0.870, 0.170, 0.092, "crop", "N product crops", color=DETECT)

    arrow(ax, (0.210, 0.916), (0.265, 0.916))
    arrow(ax, (0.480, 0.916), (0.535, 0.916))
    ax.text(0.855, 0.916,
            "class-agnostic:\nevery product is just “product”.\n"
            "No identity knowledge → never\nretrained when the catalogue grows.",
            ha="center", va="center", fontsize=7.4, color=MUTED, style="italic")

    # ---- Band B: brand (gating decision) and packaging (ungated) -----------
    box(ax, 0.078, 0.690, 0.551, 0.092, "Stage 2 — brand  (the routing decision)",
        "aystro-brand-classifier/3   ·   100% precision on every represented brand",
        color=CLASSIFY, title_size=9.5, sub_size=7.0)
    box(ax, 0.680, 0.690, 0.285, 0.092, "Stage 4 — packaging",
        "aystro-packaging-classifie/2", color=CLASSIFY, fill="#f3f8f5")

    arrow(ax, (0.590, 0.870), (0.400, 0.782), rad=-0.14, color=CLASSIFY)
    arrow(ax, (0.660, 0.870), (0.800, 0.782), rad=0.14, color=CLASSIFY)
    ax.text(0.8225, 0.655, "brand-independent — runs on all N, never gated",
            ha="center", va="center", fontsize=7.2, color=MUTED, style="italic")

    # ---- Band C: switch_case gates -----------------------------------------
    gates = [
        (0.078, "route_fanta", '"fanta"'),
        (0.220, "route_xl", '"xl_energy"'),
        (0.362, "route_cappy", '"cappy"'),
        (0.504, "route_coca", '"coca-cola"'),
    ]
    for gx, name, case in gates:
        box(ax, gx, 0.505, 0.125, 0.080, name, "switch_case",
            color=ROUTE, fill="#fdf8f1", title_size=8.2, sub_size=6.6)
        arrow(ax, (0.3535, 0.690), (gx + 0.0625, 0.585), color=ROUTE, rad=-0.05)
        ax.text(gx + 0.0625, 0.478, case, ha="center", va="top",
                fontsize=6.9, color=ROUTE, style="italic")

    # ---- Band D: gated variant classifiers ---------------------------------
    variants = [
        (0.078, "Fanta", "aystro-fanta-\nclassifier/5"),
        (0.220, "XL Energy", "aystro-xl-\nclassifier/1"),
        (0.362, "Cappy", "aystro-cappy-\nclassifier/1"),
        (0.504, "Coca-Cola", "aystro-coca-\nclassifier/1"),
    ]
    for vx, name, mid in variants:
        box(ax, vx, 0.300, 0.125, 0.100, f"Stage 3 — {name}", mid,
            color=CLASSIFY, title_size=8.2, sub_size=6.3)
        arrow(ax, (vx + 0.0625, 0.505), (vx + 0.0625, 0.400), color=ROUTE)
        arrow(ax, (vx + 0.0625, 0.300), (0.310, 0.170), rad=0.10, color=MERGE)

    ax.text(0.680, 0.400,
            "Each crop enters at most ONE branch.\n"
            "Cost grows with N, not with N×K —\n"
            "measured: 40.32 s → 14.20 s (−65%).",
            ha="center", va="center", fontsize=7.6, color=ROUTE, style="italic")

    # ---- Band E: merge, then write back onto the detections ----------------
    box(ax, 0.140, 0.075, 0.340, 0.092, "merge",
        "first_non_empty_or_default", color=MERGE)

    # Ungated fallback: the plain brand label, routed down the outside edge so
    # it never crosses the gated branches.
    arrow(ax, (0.078, 0.700), (0.170, 0.167), rad=0.34, color=MERGE,
          style=(0, (4, 3)))
    ax.text(0.004, 0.482, "fallback:\nplain brand\n(brand with no\nvariant classifier)",
            ha="left", va="center", fontsize=6.9, color=MERGE, style="italic")

    box(ax, 0.615, 0.075, 0.350, 0.092, "output",
        "brand · variant · packaging", color=INK, fill=LIGHT)
    arrow(ax, (0.480, 0.121), (0.615, 0.121), color=INK)
    arrow(ax, (0.8225, 0.690), (0.8225, 0.167), color=CLASSIFY, style=(0, (4, 3)))

    ax.text(0.790, 0.032, "+ size — the planned fourth axis",
            ha="center", va="center", fontsize=7.4, color=MUTED, style="italic")

    fig.tight_layout(pad=0.4)
    out = os.path.join(HERE, "fig_pipeline_v2.png")
    fig.savefig(out, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print("wrote", out)


# --------------------------------------------------------------- figure 2

def signal_starvation_figure():
    """Why splitting a fixed image budget across brand classes costs accuracy.

    Left:  the single-layer detector's per-class mAP50 -- the spread between
           represented classes, and the total collapse of the unrepresented
           one, are the mechanism the architecture argument rests on.
    Right: the headline detection metrics, both detectors, same eval tool.
    """
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11.4, 4.5), dpi=200,
                                   gridspec_kw={"width_ratios": [1.25, 1.0]})

    # -- Panel 1: per-class mAP50 of the single-layer detector ---------------
    classes = ["xl_energy", "coca-cola", "sprite", "fanta", "cappy", "pepsi"]
    vals = [91.97, 89.27, 88.29, 87.98, 85.62, 0.0]   # mAP@50, threshold-free
    colours = [DETECT] * 5 + [WARN]

    bars = ax1.bar(classes, vals, width=0.62, color=colours, zorder=2)
    # Values sit inside the bars: the 93.33 reference line runs just above the
    # tallest bar, and labels placed above would collide with it.
    for bar, v in zip(bars, vals):
        if v:
            ax1.text(bar.get_x() + bar.get_width() / 2, v - 3.2, f"{v:.2f}",
                     ha="center", va="top", fontsize=8.6, fontweight="bold",
                     color="white")
    ax1.text(5.0, 3.0, "0\nno test\nrepresentation", ha="center", va="bottom",
             fontsize=7.8, color=WARN, fontweight="bold")

    ax1.axhline(93.33, color=CLASSIFY, linewidth=1.8, linestyle=(0, (5, 3)),
                zorder=3)
    ax1.text(-0.75, 95.4,
             "multi-stage detector, single “product” class:  93.33",
             ha="left", va="bottom", fontsize=8.6, color=CLASSIFY,
             fontweight="bold")

    # the spread among represented classes is the starvation signal
    ax1.annotate("", xy=(-0.52, 91.97), xytext=(-0.52, 85.62),
                 arrowprops=dict(arrowstyle="<->", color=MUTED, linewidth=1.1))
    ax1.text(-0.66, 88.8, "6.35 pt\nspread", ha="right", va="center",
             fontsize=7.8, color=MUTED, style="italic")

    ax1.set_ylabel("mAP@50  (%)", fontsize=9)
    ax1.set_ylim(0, 104)
    ax1.set_xlim(-1.45, 5.6)
    ax1.set_title("Single-layer detector: a fixed image budget split six ways",
                  fontsize=10, fontweight="bold", color=ACCENT, pad=10)
    ax1.tick_params(axis="x", labelsize=8, rotation=18)
    ax1.grid(axis="y", linewidth=0.6, alpha=0.32)
    ax1.set_axisbelow(True)
    for s in ("top", "right"):
        ax1.spines[s].set_visible(False)

    # -- Panel 2: headline metrics, both detectors ---------------------------
    # mAP is threshold-free; precision/recall/F1 are at the study's fixed 0.70.
    metrics = ["mAP@50", "mAP@50-95", "mAP@75", "recall", "F1"]
    v1 = [88.62, 70.09, 80.43, 74.00, 81.60]
    v2 = [93.33, 76.49, 87.57, 80.70, 85.90]

    xs = range(len(metrics))
    w = 0.36
    b1 = ax2.bar([x - w / 2 for x in xs], v1, width=w, color=WARN, zorder=2,
                 label="v1  —  single detection layer")
    b2 = ax2.bar([x + w / 2 for x in xs], v2, width=w, color=DETECT, zorder=2,
                 label="v2  —  multi-stage, class-agnostic")

    for bars in (b1, b2):
        for bar in bars:
            ax2.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 1.2,
                     f"{bar.get_height():.2f}", ha="center", va="bottom",
                     fontsize=7.6, color=INK)

    for x, a, b in zip(xs, v1, v2):
        ax2.text(x, max(a, b) + 7.0, f"+{b - a:.2f}", ha="center", va="bottom",
                 fontsize=8.4, fontweight="bold", color=CLASSIFY)

    ax2.set_xticks(list(xs))
    ax2.set_xticklabels(metrics, fontsize=8.4)
    ax2.set_ylabel("%", fontsize=9)
    ax2.set_ylim(0, 112)
    ax2.set_title("Same photographs, same architecture, one 0.70 threshold",
                  fontsize=10, fontweight="bold", color=ACCENT, pad=10)
    ax2.legend(fontsize=7.8, frameon=False, loc="lower left")
    ax2.grid(axis="y", linewidth=0.6, alpha=0.32)
    ax2.set_axisbelow(True)
    for s in ("top", "right"):
        ax2.spines[s].set_visible(False)

    fig.tight_layout(pad=1.2)
    out = os.path.join(HERE, "fig_detection.png")
    fig.savefig(out, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print("wrote", out)


# --------------------------------------------------------------- figure 3

def complexity_figure():
    """Measured effect of gating the variant classifiers behind switch_case.

    Panel 2 is a real back-to-back wall-clock measurement on the same
    60-crop photograph through the identical call path. Panel 1 plots the
    growth shape, with the two points that are actually measured marked.
    """
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10.8, 4.2), dpi=200)

    # -- Panel 1: variant-classifier calls as the catalogue grows ------------
    # Scoped to the variant layer specifically -- the only layer the routing
    # change affects. Brand and packaging each run once per crop under both
    # designs and are O(N) either way.
    ks = list(range(1, 9))
    n = 60
    before = [n * k for k in ks]
    after = [n for _ in ks]

    ax1.plot(ks, before, marker="o", markersize=4.2, linewidth=1.9,
             color=WARN, label="unrouted  —  N×K  (every classifier, every crop)")
    ax1.plot(ks, after, marker="o", markersize=4.2, linewidth=1.9,
             color=DETECT, label="routed  —  ≤ N  (at most one per crop)")

    ax1.plot([1], [12], marker="*", markersize=14, color=DETECT, zorder=5,
             linestyle="none", label="measured, K = 1:  12 calls, not 60")
    ax1.plot([4], [40], marker="*", markersize=14, color=CLASSIFY, zorder=5,
             linestyle="none", label="today, K = 4:  40 calls, not 240")

    ax1.axvspan(3.86, 4.14, color="#f0f0f0", zorder=0)
    ax1.annotate("", xy=(4, 40), xytext=(4, 240),
                 arrowprops=dict(arrowstyle="<->", color=MUTED, linewidth=1.1))
    ax1.text(4.22, 140, "−83%", ha="left", va="center", fontsize=9,
             fontweight="bold", color=MUTED)

    ax1.set_xlabel("K  —  brands with their own variant classifier", fontsize=9)
    ax1.set_ylabel("variant-classifier calls per photograph  (N = 60)",
                   fontsize=9)
    ax1.set_title("The variant layer stops scaling with catalogue breadth",
                  fontsize=10, fontweight="bold", color=ACCENT, pad=9)
    ax1.legend(fontsize=7.3, frameon=False, loc="upper left")
    ax1.set_ylim(0, 560)
    ax1.grid(axis="y", linewidth=0.6, alpha=0.32)
    ax1.set_axisbelow(True)
    for s in ("top", "right"):
        ax1.spines[s].set_visible(False)

    # -- Panel 2: measured wall-clock ----------------------------------------
    labels = ["unrouted\n(every classifier)", "routed\n(switch_case)"]
    times = [40.32, 14.20]
    bars = ax2.bar(labels, times, width=0.5, color=[WARN, DETECT], zorder=2)
    for bar, t in zip(bars, times):
        ax2.text(bar.get_x() + bar.get_width() / 2, t + 0.9, f"{t:.2f}s",
                 ha="center", va="bottom", fontsize=10.5, fontweight="bold",
                 color=INK)

    ax2.annotate("", xy=(1.42, 14.20), xytext=(1.42, 40.32),
                 arrowprops=dict(arrowstyle="<->", color=MUTED, linewidth=1.2))
    ax2.text(1.50, 27.3, "−65%\n(26.1 s)", ha="left", va="center",
             fontsize=9, color=MUTED, fontweight="bold")

    ax2.text(0.5, 46.5, "identical labels on the measured photograph",
             ha="center", va="center", fontsize=8.4, color=CLASSIFY,
             style="italic")

    ax2.set_ylabel("wall-clock, same 60-crop photograph  (s)", fontsize=9)
    ax2.set_ylim(0, 50)
    ax2.set_xlim(-0.55, 1.95)
    ax2.set_title("Measured back-to-back through the same call path",
                  fontsize=10, fontweight="bold", color=ACCENT, pad=9)
    ax2.grid(axis="y", linewidth=0.6, alpha=0.32)
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
    signal_starvation_figure()
    complexity_figure()
