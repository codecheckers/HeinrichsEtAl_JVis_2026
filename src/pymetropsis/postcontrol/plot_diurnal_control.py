# ---------- Imports ----------

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from pymetropsis.plotting import plot_metropsis_group
from pymetropsis.postcontrol import plot_diurnal_control
from pymetropsis.plotting import plot_utils

# Canonical output locations. See STRUCTURE.md for the results/ vs reports/ rule.
from pymetropsis.paths import FIG_DIR, PROJECT_ROOT


# ---------- Constants ----------

plt.rcParams["font.family"] = "Arial"

_MARKER_SIZE = 4        # shared dot size
_MARKER_ALPHA = "99"    # hex alpha for filled scatter (free viewing)
_MARKER_ALPHA_HOLLOW = "22"  # hollow (white fill) for constrained condition


# ---------- Functions ----------

def plot_sessioncontext(ax, data, x_col, line_colour: str = "#404040"):
    """
    """
    # Data must have columns: block, condition, cs_mean, cs_sem

    condition_dict = {
            "achromatic": "L+M+S (luminance)",
            "red-green": "L-M (red-green)",
            "blue-yellow": "S (blue-yellow)",
        }
    session_dict = {
        "fd_c": "FD, constrained pupil",
        "dc_c": "DC, constrained pupil",
        "dc_f": "DC, free viewing",
    }
    colour_dict = {
        "achromatic": "#404040",
        "blue-yellow": "#6969F3",
        "red-green": "#F23E99",
    }  # {"achromatic": "grey", "blue-yellow": "blue", "red-green": "deeppink"}
    compl_colour_dict = {
        "achromatic": "#B0B0B0",
        "blue-yellow": "#DFFF51",
        "red-green": "#3AF1CA",
    }
    linestyle_list = [":", "-"]
    marker_list = ["o", "o"]

    # Plot all conditions in on plot
    for i_group, (group_name, df) in enumerate(data.groupby("session_context")):
        colour = colour_dict.get(df["condition"].iloc[0])
        # free viewing: filled; constrained: hollow (white face, coloured edge)
        face = colour + _MARKER_ALPHA if i_group == 0 else colour + _MARKER_ALPHA_HOLLOW
        ax.scatter(
            df[x_col],
            df["contrast_sensitivity"],
            marker=marker_list[i_group],
            s=_MARKER_SIZE ** 2.2,
            facecolor=face,
            edgecolors=colour,
            linewidths=1,
            label=f"{condition_dict[df['condition'].iloc[0]]}, {session_dict[group_name]}",
            zorder=3,
        )

        # ax.fill_between(
        #     x=df[x_col],
        #     y1=df["cs_mean"] - df["cs_sem"],
        #     y2=df["cs_mean"] + df["cs_sem"],
        #     facecolor=compl_colour_dict["achromatic"],
        #     alpha=0.2,
        #     edgecolor="none",
        # )

        mean_df = plot_metropsis_group.summarize_contrastsens_by(
            data=df,
            group_vars=[
                "participant_id",
                "session_context",
                "datetime_block",
                "hours_since_start_block",
                "block",
                "condition",
                "freq",
            ],
            cs_col="contrast_sensitivity",
        )
        mean_df = mean_df.sort_values(by="hours_since_start_block")
        # session_colour = (
        #     colour_dict.get(df["condition"].iloc[0]) + "99"
        #     if i_group == 0
        #     else colour_dict.get(df["condition"].iloc[0])
        #     + "50"
        # )
        ax.errorbar(
            x=mean_df["hours_since_start_block"],
            y=mean_df["cs_mean"],
            yerr=mean_df["cs_sem"],
            linestyle=linestyle_list[i_group],
            c=colour if i_group == 0 else colour + "80",
        )

        # ax.set_label(session_dict[group_name])


# context order and display names used by the boxplot column
_CONTEXT_ORDER = ["dc_c", "dc_f"]
_CONTEXT_LABEL = {"dc_f": "Free", "dc_c": "Constr."}
_FREQ_POSITIONS = {2: (0.0, 0.75), 8: (2.0, 2.75)}  # (free_x, constr_x) per frequency


def _plot_cs_rainclouds(ax, data, colour: str) -> None:
    """Plot 4 rainclouds for one condition row:
    [2 Hz Free | 2 Hz Constr.] gap [8 Hz Free | 8 Hz Constr.]

    Each raincloud: jittered strip on the left, half-violin on the right,
    median tick on the violin — mirroring the plot_pupil design.

    Parameters
    ----------
    ax : Axes for the raincloud column.
    data : full raw data for this condition (all blocks, both frequencies).
    colour : hex colour string for this condition.
    """
    import numpy as np
    from scipy.stats import gaussian_kde

    _MAX_W = 0.28   # maximum KDE half-width per cloud
    rng = np.random.default_rng(seed=42)
    all_positions: list[float] = []
    all_labels: list[str] = []

    for freq, (free_x, constr_x) in _FREQ_POSITIONS.items():
        freq_df = data[data["freq"] == freq]
        for context, centre in zip(_CONTEXT_ORDER, [free_x, constr_x]):
            vals = freq_df.loc[
                freq_df["session_context"] == context, "contrast_sensitivity"
            ].dropna().values
            all_positions.append(centre)
            all_labels.append(_CONTEXT_LABEL[context])
            if len(vals) < 2:
                continue

            colour_sessioncontext = (
                colour + _MARKER_ALPHA if context == "dc_f" else colour + _MARKER_ALPHA_HOLLOW
            )

            # half-violin (right of centre) ────────────────────────────
            kde = gaussian_kde(vals)
            y_lo, y_hi = vals.min(), vals.max()
            y_grid = np.linspace(y_lo, y_hi, 200)
            kde_vals = kde(y_grid) / kde(y_grid).max() * _MAX_W
            ax.fill_betweenx(
                y_grid,
                centre,
                centre + kde_vals,
                color=colour_sessioncontext,#colour + "33",
                edgecolor=colour,
                linewidth=0.6,
                zorder=2,
            )
            # median tick
            median = float(np.median(vals))
            med_w = float(kde(median)) / kde(y_grid).max() * _MAX_W
            ax.hlines(median, centre, centre + med_w,
                      color=colour, linewidth=1.5, zorder=4)

            # jittered strip (left of centre) ─────────────────────────
            ax.scatter(
                x=rng.uniform(centre - _MAX_W - 0.04, centre - 0.04, size=len(vals)),
                y=vals,
                facecolor=colour_sessioncontext,
                edgecolors=colour,
                linewidths=1.0,
                s=_MARKER_SIZE ** 2.2,
                marker="o",
                zorder=3,
            )

    # x-axis: tick at each centre, freq group label underneath
    ax.set_xticks(all_positions)
    ax.set_xticklabels(all_labels)

    # for freq, (free_x, constr_x) in _FREQ_POSITIONS.items():
    #     mid = (free_x + constr_x) / 2
    #     ax.text(
    #         mid, -0.04, f"{int(freq)} Hz",
    #         ha="center", va="top",
    #         fontsize=7,
    #         transform=ax.get_xaxis_transform(),
    #     )

    ax.tick_params(left=False, labelleft=False)
    #for spine in ["top", "right"]:
    #    ax.spines[spine].set_visible(False)


def sessionwise_timecourses_in_condition_frequency_plot(data, x_col="hours_since_start"):
    """Create a figure with plot grid individual time courses over blocks for individuals (rows) and frequencies (columns)."""
    # Requires data that is already averaged per particpant
    # Plot Grand Average
    n_cond = data["condition"].unique().size

    distance_left_edge = 0.125
    distance_right_edge = 0.05  
    distance_top_edge = 0.15 
    distance_bottom_edge = 0.2
    figsize = (9, 6)

    # Create a figure: 2 time-series cols + 1 rainplot col per condition row
    fig, axs = plt.subplots(
        nrows=n_cond,
        ncols=3,
        figsize=figsize,
        sharex=False,
        sharey="row",
        gridspec_kw={
            "width_ratios": [4, 4, 3],
            "wspace": 0.05,
            "hspace": 0.08,
            "left": distance_left_edge,
            "right": (1 - distance_right_edge),
            "top": (1 - distance_top_edge),
            "bottom": distance_bottom_edge,
        },
    )

    # Collect legend handles and labels from the first subplotx
    handles, labels = None, None

    data.sort_values(by=["participant_id", "hours_since_start"], inplace=True)
    # One row per condition
    for i_cond, (cond, group_by_cond) in enumerate(data.groupby("condition")):
        print("Evaluating mechanism:", cond)
        # One column per frequency
        for i_freq, (freq, group_by_freq) in enumerate(  # corrected variable name
            group_by_cond.groupby("freq")
        ):
            ax = axs[i_cond, i_freq]
            # Plot different session_context
            plot_sessioncontext(ax=ax, data=group_by_freq, x_col=x_col)

            # Capture handles and labels from each subplot
            subplot_handles, subplot_labels = ax.get_legend_handles_labels()
            if handles is None:  # Initialize handles and labels if not already done
                handles, labels = subplot_handles, subplot_labels
            else:  # Append unique handles and labels
                for h, l in zip(subplot_handles, subplot_labels):
                    if l not in labels:
                        handles.append(h)
                        labels.append(l)

            # Always remove the legend from the subplot
            legend = ax.get_legend()
            if legend:
                legend.remove()

            ax.yaxis.grid(True, which="major", linestyle="-", linewidth=0.5, color="grey", alpha=0.3, zorder=0)

            # Axes and labels
            ax.set_yscale("log")
            ax.set_xlim(-0.5, 12.5)
            # Set x ticks and labels
            ax.set_xticks(
                [0, 1.25, 2.5, 3.75, 5, 6.25, 7.5, 8.75, 10, 11.25], minor=False
            )
            ax.set_xticklabels(
                ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"], minor=False
            )
            # ax.set_xticks([0, 2.5, 5, 7.5, 10, 12], minor=False)
            # ax.set_xticklabels(["0", "2", "4", "6", "8", "10"], minor=False)
            # ax.set_xticks([1.25, 3.75, 6.25, 8.75, 10.75], minor=True)
            # ax.set_xticklabels([], minor=True)
            if i_cond < n_cond - 1:
                ax.tick_params(labelbottom=False)
            else:
                ax.set_xlabel("Experimental block")
            ax.set_ylabel("Contrast sensitivity") if i_freq == 0 else None
            # Set second axis on top
            if i_cond == 0:
                secax = ax.secondary_xaxis("top")
                secax.set_xticks(
                    [0, 2, 4, 6, 8, 10],
                    ["8:00", "10:00", "12:00", "14:00", "16:00", "18:00"],
                )   
                secax.set_xlabel("Local time [hh:mm]")

            if i_freq == 0:
                ax.set_yticks(ticks=[0.03, 0.1, 0.3, 1, 3], labels=[0.03, 0.1, 0.3, 1, 3])
            if i_freq == 1:
                # hide ticks/labels but keep gridlines
                ax.tick_params(left=False, labelleft=False)

            # frequency label in top-right corner
            ax.text(
                0.95, 0.90,
                f"{int(freq)} Hz",
                transform=ax.transAxes,
                ha="right", va="top",
                fontsize=10,
            )

        # Rainplot/ boxplot column (col 2) for this condition row 
        ax_bp = axs[i_cond, 2]
        cond_data = data[data["condition"] == cond]
        colour = {"achromatic": "#404040", "blue-yellow": "#6969F3", "red-green": "#F23E99"}[cond]
        _plot_cs_rainclouds(ax_bp, cond_data, colour)
        ax_bp.set_yscale("log")
        ax_bp.set_ylim(0.05, 10)
        ax_bp.grid(False)  # clear all first (sharey can inherit grid state)
        ax_bp.yaxis.grid(True, which="major", linestyle="-", linewidth=0.5, color="grey", alpha=0.5, zorder=0)
        ax_bp.set_axisbelow(True)
        ax_bp.set_yscale("log")
        ax_bp.set_xlabel("2 Hz                        8 Hz")
        if i_cond < n_cond - 1:
            ax_bp.tick_params(labelbottom=False)

    # Add a single legend for the entire figure
    # Reorder so that legend fills row by row
    ncol = 2
    new_order = []
    for r in range(len(handles) // ncol + int(len(handles) % ncol > 0)):
        for c in range(ncol):
            idx = r * ncol + c
            if idx < len(handles):
                new_order.append(idx)

    handles = [handles[i] for i in new_order]
    labels = [labels[i] for i in new_order]

    fig.legend(
        handles=handles,
        labels=labels,
        ncol=ncol,
        loc="lower center",
        # bbox_to_anchor=(0.5, 0.02),
        frameon=False,
    )

    # Add title with consistent styling
    fig.text(
        x=distance_left_edge * 1 / 3,
        y=(1 - distance_top_edge) + (distance_top_edge * 2 / 3),
        s="A" if data['participant_id'].unique()[0] == 113 else "B",
        transform=fig.transFigure,
        fontsize=14,
        fontweight="bold",
        ha="left",
    )
    fig.text(
        x=distance_left_edge,
        y=(1 - distance_top_edge) + (distance_top_edge * 2 / 3),
        s=f"Diurnal variation of chromatic thresholds (participant {data['participant_id'].unique()[0]})",
        transform=fig.transFigure,
        fontsize=14,
        # fontweight="bold",
        ha="left",
    )

    return fig, axs


def main():
    data = pd.read_csv(PROJECT_ROOT / "data" / "raw" / "clean_metropsis_dc.csv")
    data = data.loc[(data["participant_id"].notna())]

    # Create new column for context, C for constraint pupil, F for free viewing
    data["session"] = "dc"
    data["context"] = "f"
    # Set context to c for odd block numbers
    data.loc[data["block"] % 2 == 1, "context"] = "c"
    data["session_context"] = (data["session"] + "_" + data["context"]).str.lower()

    # select participants that participant_id is not None
    pid_df = data.loc[(data["participant_id"].notna())]  # corrected notnan() to notna()
    mean_df = plot_metropsis_group.summarize_contrastsens_by(
        data=data,
        group_vars=[
            "participant_id",
            "session_context",
            "datetime_block",
            "hours_since_start_block",
            "block",
            "condition",
            "freq",
        ],
        cs_col="contrast_sensitivity",
    )

    # participant specific plots with 3 by 2 layout for each mechanism-frequency-combination
    for i_pid, (pid, pid_df) in enumerate(data.groupby("participant_id")):
        fig, _ = sessionwise_timecourses_in_condition_frequency_plot(
            data=pid_df
        )
        fig.show()

        plot_utils.save_figure(
            fig=fig,
            fig_name=f"diurnal_timecourses_pid{pid}.pdf",
            fig_dir=FIG_DIR / "eyetracking",
        )


if __name__ == "__main__":
    main()
