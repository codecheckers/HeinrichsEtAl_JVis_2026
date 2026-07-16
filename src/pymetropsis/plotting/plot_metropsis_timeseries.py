# --- Imports ---
import os
from typing import Tuple

import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np
import pandas as pd
from matplotlib.axis import Axis
import matplotlib.patches as mpatches

from pymetropsis.plotting import plot_utils

# Canonical output locations. See STRUCTURE.md for the results/ vs reports/ rule.
from pymetropsis.paths import DATA_DIR, FIG_DIR

# --- Constants ---
plt.rcParams["font.family"] = "Arial"

# --- Functions ---
def load_data(root_dir, filename):
    filepath = os.path.join(root_dir, filename)
    raw_data = pd.read_excel(filepath)
    raw_data.loc[:, "condition"] = os.path.basename(filepath).split("_")[2]
    return raw_data


def create_summary(raw_data):
    summary_df = raw_data.iloc[-3:, :3].transpose()
    summary_df.columns = summary_df.iloc[0]
    summary_df = summary_df.iloc[1:, :]
    summary_df["tf"] = pd.to_numeric(summary_df["tf"])
    summary_df["Mean(contrast)"] = pd.to_numeric(summary_df["Mean(contrast)"])
    summary_df["Std(contrast)"] = pd.to_numeric(summary_df["Std(contrast)"])
    return summary_df


def clean_data(data):
    data = data.dropna(subset=["contrast"], how="all").copy()
    data.loc[:, "direction_trial_index"] = data.groupby("tf").cumcount() + 1
    return data


def plot_data(ax, data, summary_df, tf, condition_info):
    """
    Plot contrast threshold data for a single temporal frequency and condition.

    Parameters:
    -----------
    ax : matplotlib.axes.Axes
        The axis to plot on
    data : pandas.DataFrame
        Data for a specific condition and temporal frequency
    summary_df : pandas.DataFrame
        Summary statistics for the condition
    tf : float
        Temporal frequency value
    condition_info : dict
        Dictionary containing styling information for different conditions
    """
    # Extract hit and miss data
    hit_data = data[data["Patient Response"] == "Hit"]
    miss_data = data[data["Patient Response"] == "Miss"]

    # Get condition styling from the condition info dictionary
    condition = data["condition"].iloc[0]
    condition_label = condition_info["labels"][condition]
    color = condition_info["colors"][condition]
    compl_color = condition_info["compl_colors"][condition]
    linestyle = condition_info["linestyles"][condition]
    marker = condition_info["markers"][condition]

    # Plot all data points with connecting line
    (line,) = ax.plot(
        data["direction_trial_index"],
        data["Threshold"],
        linestyle=linestyle,
        linewidth=1,
        color=color,
        label=f"{condition_label} (All)",
    )

    # Plot hit data points
    (hit_points,) = ax.plot(
        hit_data["direction_trial_index"],
        hit_data["Threshold"],
        markersize=3,
        marker=marker,
        linestyle="",
        color=color,
        label=f"{condition_label} (Hit)",
    )

    # Plot miss data points (unfilled)
    (miss_points,) = ax.plot(
        miss_data["direction_trial_index"],
        miss_data["Threshold"],
        markersize=3,
        marker=marker,
        fillstyle="none",
        linestyle="",
        color=color,
        label=f"{condition_label} (Miss)",
    )

    # Plot mean and standard deviation
    mean_contrast = summary_df.loc[summary_df["tf"] == tf, "Mean(contrast)"].values[0]
    std_contrast = summary_df.loc[summary_df["tf"] == tf, "Std(contrast)"].values[0]

    # Mean line
    mean_line = ax.axhline(mean_contrast, color=color, alpha=0.5, linestyle="--", linewidth=1)

    # Standard deviation band
    # Create a mask for the x-values within the desired range
    # Apply fill_between only for the masked x-range
    first_miss_idx = miss_data["direction_trial_index"].min()
    last_response_idx = data["direction_trial_index"].max()
    x_values = data["direction_trial_index"].values
    mask = (x_values >= first_miss_idx) & (x_values <= last_response_idx)
    std_band = ax.fill_between(
        x=x_values[mask],
        y1=(mean_contrast - std_contrast),
        y2=(mean_contrast + std_contrast),
        color=color,
        alpha=0.1,
    )

    # Add text with mean and standard deviation
    ax.text(
        x=31,
        y=(mean_contrast - 0.05),
        s=f"{mean_contrast:.2f} ± {std_contrast:.2f}",
        ha="left",
        verticalalignment="top",
    )

    # Create a single legend entry for "Misses" with a marker dot on top of a line
    # Create a single legend entry for "Hits" with a marker dot on top of a line
    # Add a common legend entry for the mean line and standard deviation band
    miss_entry = plt.Line2D(
            [0],
            [0],
            color=color,
            linestyle=linestyle,
            linewidth=1,
            marker=marker,
            markersize=4,
            fillstyle="none",
            label=f"{condition_label} - Miss",
        )
    hit_entry = plt.Line2D(
            [0],
            [0],
            color=color,
            linestyle=linestyle,
            linewidth=1,
            marker=marker,
            markersize=4,
            label=f"{condition_label} - Hit",
        )
    mean_std_legend = plt.Line2D(
        [0], [0],
        color=color,
        linestyle="--",
        linewidth=1,
        alpha=0.3,
        marker="s",
        markersize=8,
        markerfacecolor=color,
        markeredgewidth=0,
        label=f"{condition_label} mean est. ± std. dev."
    )
    return hit_entry, miss_entry, mean_std_legend
    # upper_limit = 100  # Set appropriate upper limit
    # y_lower = np.maximum(lower_limit, mean_contrast - std_contrast)
    # y_upper = np.minimum(upper_limit, mean_contrast + std_contrast)
    # ax.fill_between(
    #     #x=data["direction_trial_index"],
    #     x=x_values[mask],
    #     y1=(mean_contrast - std_contrast),
    #     y2=(mean_contrast + std_contrast),
    #     color=color,
    #     alpha=0.1,
    # )


def format_axis(ax):
    """Helper function to format axis with common settings"""
    ax.set_xlabel("Trial index")
    ax.set_ylabel("Stimulus contrast [%]")

    ax.set_yscale("log")
    ax.yaxis.set_major_formatter(
        ticker.FuncFormatter(lambda x, p: format(int(x), ","))
    )
    ax.set_xticks(np.arange(0, 50, 10))
    ax.set_xticks(np.arange(0, 50, 5), minor=True)


def get_condition_info():
    """Create a dictionary with styling information for all conditions"""
    return {
        "labels": {
            "achromatic": "L+M+S",
            "red-green": "L-M",
            "blue-yellow": "S",
        },
        "colors": {
            "achromatic": "#404040",
            "blue-yellow": "#6969F3",
            "red-green": "#F23E99",
        },
        "compl_colors": {
            "achromatic": "#B0B0B0",
            "blue-yellow": "#DFFF51",
            "red-green": "#3AF1CA",
        },
        "linestyles": {"achromatic": "--", "blue-yellow": "-", "red-green": ":"},
        "markers": {"achromatic": "o", "blue-yellow": "o", "red-green": "o"},
    }


def create_split_timeseries_plot(data_dict, summary_dict):
    """Create the original 1x2 layout with all conditions in each plot"""
    # distance_left_edge = 0.125
    # distance_right_edge = 0.05
    # distance_top_edge = 0.2
    # distance_bottom_edge = 0.2
    distance_left_edge = 0.1
    distance_right_edge = 0.05
    distance_top_edge = 0.15
    distance_bottom_edge = 0.275 # 0.15

    fig, axs = plt.subplots(
        ncols=2,
        nrows=1,
        figsize=(7.5, 4.5),
        sharex=True,
        gridspec_kw={
            "wspace": 0.2,
            "hspace": 0.1,
            "left": distance_left_edge,
            "right": (1 - distance_right_edge),
            "top": (1 - distance_top_edge),
            "bottom": distance_bottom_edge,
        },
    )

    # fig, axs = plt.subplots(1, 2, figsize=(8, 4))
    condition_info = get_condition_info()

    # Keep track of legend handles
    legend_handles = []
    legend_labels = []

    # Plot all conditions
    for condition, data in data_dict.items():
        for tf_idx, (tf, group_data) in enumerate(data.groupby("tf")):
            ax = axs[tf_idx]
            hit_entry, miss_entry, mean_std_legend = plot_data(
                ax=ax,
                data=group_data,
                summary_df=summary_dict[condition],
                tf=tf,
                condition_info=condition_info,
            )

            if condition == "achromatic":
                ax.annotate(
                    text=f"{int(tf)} Hz",
                    fontsize=12,
                    xy=(0, 0),
                    xytext=(0.85, 0.9),
                    xycoords="axes fraction",
                    textcoords="axes fraction",
                )

            # Only add to legend for the first subplot to avoid duplication
            if tf_idx == 0:
                legend_handles.extend([hit_entry, miss_entry, mean_std_legend])
                legend_labels.extend(
                    [
                        f"{condition_info['labels'][condition]}, hit",
                        f"{condition_info['labels'][condition]}, miss",
                        f"{condition_info['labels'][condition]}, est. ± std. dev.",
                    ]
                )

    # Format axes
    for i, ax in enumerate(axs):
        #ax.set_title(f"{2 if i==0 else 8} Hz", loc="center")
        format_axis(ax)

    # Set the same y limits for both plots
    y_min = min(ax.get_ylim()[0] for ax in axs)
    y_max = max(ax.get_ylim()[1] for ax in axs)
    for ax in axs:
        ax.set_ylim(y_min, y_max)

    # Add a single legend outside the plots
    fig.legend(
        handles=legend_handles,
        labels=legend_labels,
        loc="lower center",
        bbox_to_anchor=(0.5, 0),
        ncol=3,
        frameon=False,  # Disable the frame around the legend
    )

    fig.text(
        x=0,
        y=1 + (distance_top_edge),
        s="Psychophysical performance for tests of different colour directions",
        transform=axs[0].transAxes,
        fontsize=14,
        # fontweight="bold",
        ha="left",
    )

    return fig, ax


def creae_timeseries_plot_grid(data_dict, summary_dict, out_filepath):
    """Create an alternative 3x2 layout with each condition in its own row"""
    fig, axs = plt.subplots(3, 2, figsize=(8, 10))
    condition_info = get_condition_info()

    # Plot each condition in its own row
    for row_idx, (condition, data) in enumerate(data_dict.items()):
        for tf_idx, (tf, group_data) in enumerate(data.groupby("tf")):
            ax = axs[row_idx, tf_idx]
            plot_data(
                ax=ax,
                data=group_data,
                summary_df=summary_dict[condition],
                tf=tf,
                condition_info=condition_info,
            )

            # Format axis with specific condition label
            format_axis(ax, f"{condition_info['labels'][condition]} - {int(tf)} Hz")

            # Add legend for this subplot
            ax.legend(loc="upper right", framealpha=0)

    # Set the same y limits for all plots
    y_min = min(ax.get_ylim()[0] for ax in axs.flat)
    y_max = max(ax.get_ylim()[1] for ax in axs.flat)
    for ax in axs.flat:
        ax.set_ylim(y_min, y_max)

    return fig, axs


def main(in_dir = (DATA_DIR / "raw"), out_dir = FIG_DIR / "tcs", out_figname="fig_psychophysics_test_timeseries_212-2.svg"):
    # Set up paths
    # root_dir = "/Volumes/tscn-projects/civibe/data/raw/group/metropsis/fd_civibe/TCS-2e"
    os.makedirs(out_dir, exist_ok=True)

    # Define filenames
    filenames = {
        "achromatic": "212 civibe/212 civibe_Left_achromatic_2024-09-28 16:46:18.xls",
        "blue-yellow": "212 civibe/212 civibe_Left_blue-yellow_2024-09-28 16:05:15.xls",
        "red-green": "212 civibe/212 civibe_Left_red-green_2024-09-28 17:25:26.xls",
    }
    # check if filenames exist
    for filename in filenames.values():
        filepath = os.path.join(in_dir, filename)
        if not os.path.exists(filepath):
            raise FileNotFoundError(f"File not found: {filepath}")

    file_dict = {
        condition: load_data(in_dir, filename)
        for condition, filename in filenames.items()
    }
    summary_dict = {
        condition: create_summary(data) for condition, data in file_dict.items()
    }

    data_dict = {condition: clean_data(data) for condition, data in file_dict.items()}

    # Create the original 1x2 layout
    fig, _ = create_split_timeseries_plot(data_dict, summary_dict)
    plot_utils.save_figure(fig_dir=out_dir, fig_name=out_figname, fig=fig)
    return fig

    # Create the new 3x2 grid layout
    # fig, _ = plot_grid_layout(data_dict, summary_dict, out_filepath)
    # # plt.tight_layout(rect=[0, 0, 1, 0.95])
    # out_filepath_grid = out_filepath.replace(".svg", "_grid.svg")
    # plt.savefig(out_filepath_grid)
    # plt.show()
    # print("Grid figure saved in: ", out_filepath_grid)


if __name__ == "__main__":
    main()

# print(y_min, y_max)
# for ax in axs:
#     ax.set_ylim(y_min, y_max)
#     ax.set_xlim(0, 40)

# Add legend for color directions
# for i, (condition, data) in enumerate(data_dict.items()):
#     for j, (tf, group_data) in enumerate(data.groupby("tf")):
#         if j % 2 == 0:
#             axs[j % 2].legend(loc="upper right")
