"""Plot summarised Pupil Labs pupil diameter data.

Produces a grid of subplots:
  rows = stimulus conditions  (achromatic / blue-yellow / red-green)
  cols = participants

Each cell shows individual recordings as jittered scatter points with
``diameter_3d_mean ± diameter_3d_std`` error bars.  A dotted line
connects the per-block mean across recordings, matching the style of
the diurnal contrast-sensitivity plots.

Usage (CLI)
-----------
python -m pymetropsis.plotting.plot_pupil          # all participants
python -m pymetropsis.plotting.plot_pupil --pids 113 202
python -m pymetropsis.plotting.plot_pupil --show
"""

from __future__ import annotations

import argparse
from pathlib import Path

import matplotlib.lines as mlines
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.stats import gaussian_kde

from pymetropsis.plotting.plot_utils import save_figure

# Canonical output locations. See STRUCTURE.md for the results/ vs reports/ rule.
from pymetropsis.paths import DATA_DIR, FIG_DIR

# ── constants ─────────────────────────────────────────────────────────────────

plt.rcParams["font.family"] = "Arial"

COLOUR_MAP: dict[str, str] = {
    "achromatic": "#404040",
    "blue-yellow": "#6969F3",
    "red-green": "#F23E99",
}

CONDITION_LABEL: dict[str, str] = {
    "achromatic": "L+M+S (luminance)",
    "blue-yellow": "S (blue-yellow)",
    "red-green": "L-M (red-green)",
}

# Fixed condition order (top → bottom row)
_CONDITIONS = ["achromatic", "blue-yellow", "red-green"]

# Social-time tick mapping: block number → clock label
_BLOCK_TICKS = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
_TIME_LABELS = ["8:00", "", "10:30", "", "13:00", "", "15:30", "",  "18:00", ""]

_MARKER_SIZE = 4        # shared dot size for scatter points and legend
_MARKER_ALPHA = "66"    # hex alpha applied to scatter fill and legend marker
_MARKER_ALPHA_HOLLOW = "22"  # hex alpha for hollow markers


# ── core plot function ─────────────────────────────────────────────────────────

def plot_pupil_diameters(
    df: pd.DataFrame,
    jitter: float = 0.25,
    with_range: bool = False,
) -> tuple[plt.Figure, np.ndarray]:
    """Plot pupil diameter mean ± std per block for a participant for
    different conditions.

    Within a subplot of the first column, every individual recording is
    shown as a scatter point at ``diameter_3d_mean`` with ± ``diameter_3d_std``
    error bars, ordered by ``datetime`` (earliest = leftmost) and spaced
    linearly within ±``jitter`` blocks.
    A dotted trend line connects the per-block mean.

    A second narrow column to the right of the participant's time-series
    shows a violin of all ``diameter_3d_mean`` values for that condition,
    with individual data points overlaid as a strip.

    Parameters
    ----------
    df:
        Summarised participant specific pupil data as produced by
        ``pymetropsis.postcontrol.load_pupil.summarise_pupil``.
        Required columns: ``participant_id``, ``block``, ``condition``,
        ``diameter_3d_mean``, ``diameter_3d_std``.
    jitter:
        Half-width of the evenly-spaced x-offsets applied within each block
        so that multiple recordings do not overlap.  Default 0.25.
    with_range: 
        Whether to show the full range of pupil diameter values per recording
        as wider, more transparent error bars behind the ± std bars.  Default False.

    Returns
    -------
    fig : matplotlib.figure.Figure
    axs : numpy.ndarray of matplotlib.axes.Axes, shape (n_conditions, n_pids)
    """
    conditions = [c for c in _CONDITIONS if c in df["condition"].unique()]
    n_rows = len(conditions)
    n_cols = 2
    pid_vals = df["participant_id"].unique()
    pid = pid_vals[0] if len(pid_vals) == 1 else None

    dist_left = 0.125
    dist_right = 0.05
    dist_top = 0.15
    dist_bottom = 0.15

    # Time-series column (wide) + violin column (narrow)
    figwidth = 5.5
    figheight = 1.8 * n_rows + 0.4

    fig, axs = plt.subplots(
        nrows=n_rows,
        ncols=n_cols,
        figsize=(figwidth, figheight),
        sharey=True, #"row",           # same y-range per row; x-axes differ between columns
        squeeze=False,          # always returns 2-D array
        gridspec_kw={
            "width_ratios": [4, 1],
            "wspace": 0.05,
            "hspace": 0.08,
            "left": dist_left,
            "right": 1 - dist_right,
            "top": 1 - dist_top,
            "bottom": dist_bottom,
        },
    )

    # ── secondary x-axis (social time) on the top row, time-series column only
    secax = axs[0, 0].secondary_xaxis("top")
    secax.set_xticks(_BLOCK_TICKS, _TIME_LABELS)
    secax.set_xlabel("Local time [hh:mm]")

    for i_row, cond in enumerate(conditions):
        ax_ts = axs[i_row, 0]   # time-series
        ax_vl = axs[i_row, 1]   # violin
        cond_df = df[df["condition"] == cond].copy()
        colour = COLOUR_MAP[cond]
        values = cond_df["diameter_3d_mean"].dropna().values

        # Convert datetime to decimal hours for linear spacing on the x-axis
        _parsed_dt = pd.to_datetime(cond_df["datetime"], format="%H:%M", errors="coerce")
        cond_df["datetime_decimal"] = _parsed_dt.dt.hour + _parsed_dt.dt.minute / 60.0
        cond_df = cond_df.sort_values("datetime_decimal")
        # Map datetime to a decimal ("partial") block number for jittering and plotting on the x-axis
        cond_df["block_decimal"] = (cond_df["datetime_decimal"] - 8) * (10 /12.5)

        # ── TIME-SERIES COLUMN ───────────────────────────────────────────────
        # dotted trend line through per-block means with SEM ribbon
        block_means = (
            cond_df.groupby("block")["diameter_3d_mean"]
            .agg(
                mean="mean",
                sem=lambda x: x.std(ddof=1) / np.sqrt(x.count()) if x.count() > 1 else 0.0,
            )
            .reset_index()
            .sort_values("block")
        )
        ax_ts.fill_between(
            block_means["block"],
            block_means["mean"] - block_means["sem"],
            block_means["mean"] + block_means["sem"],
            color=colour + _MARKER_ALPHA_HOLLOW,
            linewidth=0,
            zorder=1,
        )
        ax_ts.plot(
            block_means["block"],
            block_means["mean"],
            color=colour + _MARKER_ALPHA,
            linewidth=1.0,
            linestyle="-",
            zorder=2,
        )

        # datetime-ordered scatter with error bars
        for block, block_df in cond_df.groupby("block"):
            n = len(block_df)
            # offsets = np.linspace(-jitter, jitter, n) if n > 1 else np.array([0.0])
            ax_ts.errorbar(
                # x=float(block) + offsets,
                x=block_df["block_decimal"].values,
                y=block_df["diameter_3d_mean"].values,
                yerr=block_df["diameter_3d_std"].values,
                fmt="o",
                markerfacecolor=colour + _MARKER_ALPHA_HOLLOW,
                markeredgecolor=colour,
                markeredgewidth=1,
                ecolor=colour,
                capsize=2,
                markersize=_MARKER_SIZE,
                linewidth=1,
                linestyle="none",
                zorder=2,
            )
            # min/max range as wider, transparent error bars behind
            if with_range:
                yerr_min = block_df["diameter_3d_mean"].values - block_df["diameter_3d_min"].values
                yerr_max = block_df["diameter_3d_max"].values - block_df["diameter_3d_mean"].values
                ax_ts.errorbar(
                    # x=float(block) + offsets,
                    x=block_df["block_decimal"].values,
                    y=block_df["diameter_3d_mean"].values,
                    yerr=[yerr_min, yerr_max],
                    fmt="none",
                    ecolor=colour + _MARKER_ALPHA_HOLLOW,
                    capsize=3,
                    linewidth=1,
                    zorder=1,
                )

        ax_ts.set_xlim(-0.5, 9.5)
        ax_ts.set_xticks(_BLOCK_TICKS)
        ax_ts.set_xticklabels([block+1 for block in _BLOCK_TICKS])
        ax_ts.set_ylim(2.1, 6.5)
        ax_ts.set_ylabel("Pupil diameter (mm)")
        ax_ts.yaxis.set_major_locator(plt.MultipleLocator(2))
        ax_ts.yaxis.set_minor_locator(plt.MultipleLocator(1))
        ax_ts.yaxis.grid(True, which="major", linestyle="-", linewidth=0.5, color="grey", alpha=0.3, zorder=0)
        ax_ts.yaxis.grid(True, which="minor", linestyle="-", linewidth=0.3, color="grey", alpha=0.3, zorder=0)
        ax_ts.set_axisbelow(True)
        if i_row < n_rows - 1:
            ax_ts.tick_params(labelbottom=False)
        else:
            ax_ts.set_xlabel("Experimental block")

        # ── RAINCLOUD COLUMN ─────────────────────────────────────────────────
        # Right side (x >= 0): half-violin from KDE
        # Left side  (x <_ 0): jittered strip of diameter_3d_mean points

        _MAX_WIDTH = 0.38   # maximum KDE half-width in data coordinates

        if len(values) >= 2:
            kde = gaussian_kde(values)
            y_lo, y_hi = values.min(), values.max()
            y_grid = np.linspace(y_lo, y_hi, 300)
            kde_vals = kde(y_grid)
            kde_vals = kde_vals / kde_vals.max() * _MAX_WIDTH
            ax_vl.fill_betweenx(
                y_grid,
                0,
                kde_vals,
                color=colour + _MARKER_ALPHA_HOLLOW,
                edgecolor=colour,
                linewidth=1.0,
                zorder=2,
            )
            # median tick on the half-violin
            median = float(np.median(values))
            med_width = float(kde(median)) / kde(y_grid).max() * _MAX_WIDTH
            ax_vl.hlines(
                median, 0, med_width,
                color=colour, linewidth=1.5, zorder=4,
            )

        # jittered strip on the left
        rng = np.random.default_rng(seed=42)
        ax_vl.scatter(
            x=rng.uniform(-_MAX_WIDTH, -0.05, size=len(values)),
            y=values,
            color=colour + _MARKER_ALPHA_HOLLOW,
            edgecolors=colour,
            linewidths=1,
            s=_MARKER_SIZE**2,
            marker="o",
            zorder=3,
        )

        # thin centre separator
        ax_vl.axvline(0, color="0.75", linewidth=0.5, zorder=1)

        ax_vl.set_xlim(-0.5, 0.5)
        ax_vl.set_xticks([])
        ax_vl.tick_params(left=False, labelleft=False, labelbottom=False)
        ax_vl.yaxis.set_major_locator(plt.MultipleLocator(2))
        ax_vl.yaxis.set_minor_locator(plt.MultipleLocator(1))
        ax_vl.yaxis.grid(True, which="major", linestyle="-", linewidth=0.5, color="grey", alpha=0.3, zorder=0)
        ax_vl.yaxis.grid(True, which="minor", linestyle="-", linewidth=0.3, color="grey", alpha=0.3, zorder=0)
        ax_vl.set_axisbelow(True)
        for spine in ax_vl.spines.values():
            spine.set_visible(True)

    # ── figure-level legend ──────────────────────────────────────────────────
    legend_handles = [
        mlines.Line2D(
            [],
            [],
            color=COLOUR_MAP[cond],  # + _MARKER_ALPHA_HOLLOW,
            marker="o",
            markersize=_MARKER_SIZE,
            markerfacecolor=colour + _MARKER_ALPHA_HOLLOW,
            markeredgecolor=COLOUR_MAP[cond] + _MARKER_ALPHA,
            markeredgewidth=1,
            linewidth=1.0,
            linestyle="-",
            label=CONDITION_LABEL[cond],
        )
        for cond in conditions
    ]
    fig.legend(
        handles=legend_handles,
        ncol=len(conditions),
        loc="lower center",
        frameon=False,
    )

    # ── figure-level panel label and title ────────────────────────────────────
    title = (
        f"Pupil diameter over time of participant {pid}"
    )
    fig.text(
        x=dist_left * 1 / 3,
        y=(1 - dist_top) + dist_top * 2 / 3,
        s="A" if pid == 113 else "B",
        transform=fig.transFigure,
        fontsize=14,
        fontweight="bold",
        ha="left",
    )
    fig.text(
        x=dist_left,
        y=(1 - dist_top) + dist_top * 2 / 3,
        s=title,
        transform=fig.transFigure,
        fontsize=14,
        ha="left",
    )

    return fig, axs


# ── CLI entry point ────────────────────────────────────────────────────────────

def main() -> None:
    """Parse arguments, produce one figure per participant, and save to disk."""
    parser = argparse.ArgumentParser(
        description="Plot summarised pupil diameter data."
    )
    parser.add_argument(
        "--pids",
        nargs="+",
        type=int,
        metavar="PID",
        default=None,
        help="Participant IDs to plot (default: all in summary file).",
    )
    parser.add_argument(
        "--in",
        dest="input",
        type=Path,
        default=DATA_DIR / "derivatives/eyetracking/pupil_summary.csv",
        help="Path to pupil_summary.csv (default: %(default)s).",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=FIG_DIR / "eyetracking",
        help="Directory to save figures (default: %(default)s).",
    )
    parser.add_argument(
        "--show",
        action="store_true",
        help="Display figures interactively after saving.",
    )
    args = parser.parse_args()

    df = pd.read_csv(args.input)

    pids = args.pids or sorted(df["participant_id"].unique().tolist())

    for pid in pids:
        pid_df = df[df["participant_id"] == pid]
        fig, _ = plot_pupil_diameters(pid_df)
        fname = f"pupil_diameter_pid{int(pid)}.pdf"
        if args.show:
            plt.show()       # show before save_figure closes the figure
        save_figure(args.out, fname, fig)


if __name__ == "__main__":
    main()
