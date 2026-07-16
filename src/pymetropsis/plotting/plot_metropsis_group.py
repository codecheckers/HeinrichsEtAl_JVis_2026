# ---------- Imports ----------
import os
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np
import pandas as pd
from matplotlib import patches
from matplotlib.lines import Line2D

from pymetropsis.plotting import plot_utils

# Canonical output locations. See STRUCTURE.md for the results/ vs reports/ rule.
from pymetropsis.paths import DATA_DIR, FIG_DIR

# Get the default base font size
plt.rcParams["font.family"] = "Arial"
default_font_size = plt.rcParams["font.size"]

# Set the global font size (adjust this value as needed)
# Scale other font sizes proportionally
scaling_factor = 1  # Adjust as needed
plt.rcParams.update(
    {
        "font.size": default_font_size * scaling_factor,  # Default font size
        "axes.titlesize": default_font_size * scaling_factor * 1.2,  # Title font size
        "axes.labelsize": default_font_size * scaling_factor * 1.1,  # Axis labels
        "xtick.labelsize": default_font_size * scaling_factor,  # X ticks
        "ytick.labelsize": default_font_size * scaling_factor,  # Y ticks
        "legend.fontsize": default_font_size * scaling_factor,  # Legend
        "figure.titlesize": default_font_size * scaling_factor * 1.4,  # Figure title
    }
)


# ---------- Constants ----------
plt.rcParams["font.family"] = "Arial"

# ---------- Functions ----------
def load_clean_data(filepath):
    data = pd.read_csv(filepath)
    return data


def summarize_contrastsens_by(
    data: pd.DataFrame, group_vars: list = None, cs_col: str = "contrast_sensitivity"
) -> pd.DataFrame:
    """Caclulate block means for participant, modality and (chromatic) condition.

    Args:
        data (pd.DataFrame):
        group_vars (list, optional): Defaults to ["participant_id", "block", "condition", "freq"].
        cs_col (str, optional): Column name with contrast sensitivity. Defaults to "contrast_sensitivity".

    Returns:
        pd.DataFrame: _description_
    """
    if group_vars is None:
        group_vars = ["participant_id", "block", "condition", "freq"]
    block_mean = data.groupby(group_vars)[cs_col].mean().reset_index()
    block_mean.rename(columns={cs_col: "cs_mean"}, inplace=True)
    block_sem = data.groupby(group_vars)[cs_col].sem().reset_index()
    block_sem.rename(columns={cs_col: "cs_sem"}, inplace=True)
    block_data = pd.merge(left=block_mean, right=block_sem, on=group_vars)
    return block_data


def plot_conditions(ax, data, x_col="block"):
    condition_dict = {
        "achromatic": "L+M+S (luminance)",
        "red-green": "L-M (red-green)",
        "blue-yellow": "S (blue-yellow)",
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
    linestyle_list = ["--", "-", ":"]
    marker_list = ["o", "o", "o"]# ["s", "o", "d"]

    for i_cond, (cond, df) in enumerate(data.groupby("condition")):
        ax.fill_between(
            x=df["block"],
            y1=df["cs_mean"] - df["cs_sem"],
            y2=df["cs_mean"] + df["cs_sem"],
            facecolor=compl_colour_dict["achromatic"],
            alpha=0.2,
            edgecolor="none",
        )
        ax.errorbar(
            x=df["block"],
            y=df["cs_mean"],
            yerr=df["cs_sem"],
            marker=marker_list[i_cond],
            markersize=4,
            linestyle=linestyle_list[i_cond],
            label=condition_dict[cond],
            c=colour_dict[cond],
        )
        ax.set_label(colour_dict[cond])


def _mark_sleep_metropsis(ax):
    # Mark habitual sleep time
    ax.axvspan(xmin=4.0, xmax=6.133333333, color="#E5EBFB", alpha=0.5, lw=0)
    ax.axvspan(xmin=10, xmax=10.266666666, color="#E5EBFB", alpha=0.5, lw=0)
    ax.axvspan(xmin=-0.66666, xmax=0, color="#E5EBFB", alpha=0.5, lw=0)

    # Arrow marking the sleep / wake period
    ax.arrow(
        x=0.2,
        y=7,
        dx=3.6,
        dy=0,
        head_width=0.5,
        head_length=0.2,
        color="k",
        length_includes_head=True,
    )
    ax.arrow(
        x=3.8,
        y=7,
        dx=-3.6,
        dy=0,
        head_width=0.5,
        head_length=0.2,
        color="k",
        length_includes_head=True,
    )

    # sleep period
    ax.arrow(
        x=4.2,
        y=7,
        dx=1.8,
        dy=0,
        head_width=0.5,
        head_length=0.2,
        color="k",
        length_includes_head=True,
    )
    ax.arrow(
        x=6,
        y=7,
        dx=-1.8,
        dy=0,
        head_width=0.5,
        head_length=0.2,
        color="k",
        length_includes_head=True,
    )
    ax.text(x=0.2, y=3.1, s="Habitual wake\nperiod")
    ax.text(x=4.2, y=3.1, s="Habitual\nsleep period"),

    # legend
    ax.legend(
        frameon=False,
        loc="upper right",
        bbox_to_anchor=(0.5, 0.5, 1.5, 1.5),
    )


def plot_melatonin(
    ax,
    df,
    x_col="hours_after_wakeup",
    y_col="melatonin_concentration",
    harmonics: bool = True,
):
    # Plot data points
    ax.scatter(
        x=df[x_col].values,
        y=df[y_col].values,
        label="Empirical data",
        s = 10,
        # color="#2C69B0",
        color="#6D94BC",
        edgecolor="#3C68AB",
        linewidth=0.5
    )
    # Zero crossing
    ax.axhline(0, linestyle="--", color="#990033", label="Zero line")
    # Sinus curve
    x = np.linspace(df[x_col].min(), df[x_col].max(), 400)
    tau = df["tau"].unique().item()
    est_amplitude = df["amplitude"].unique().item()
    est_phase = df["phase"].unique().item()
    est_mesor = df["mesor"].unique().item()
    if not harmonics:
        y = est_mesor + est_amplitude * np.sin((2 * np.pi * x / tau) + est_phase)
    else:
        y = (
            df["mesor"].unique().item()
            + (
                df["sine_component"].unique().item()
                * (np.sin(1 * (2 * np.pi * x) / tau))
            )
            + (
                df["cosine_component"].unique().item()
                * (np.cos(1 * (2 * np.pi * x) / tau))
            )
            + (
                df["sine_component_2"].unique().item()
                * (np.sin(2 * (2 * np.pi * x) / tau))
            )
            + (
                df["cosine_component_2"].unique().item()
                * (np.cos(2 * (2 * np.pi * x) / tau))
            )
        )
    ax.plot(x, y, color="#30476B", linestyle="solid", label="Sinusoid fit")
    # ax.grid(True)

def create_plot_blocks_individual_timecourses(data: pd.DataFrame, letter: str = None):
    """Create a figure with plot grid individual time courses over blocks for individuals (rows) and frequencies (columns)."""
    data = data.copy()
    n_pid = data["participant_id"].unique().size

    distance_left_edge = 0.1
    distance_right_edge = 0.06
    distance_top_edge = 0.1
    distance_bottom_edge = 0.1
    figsize = (7, 10)

    # Create a figure
    fig, axs = plt.subplots(
        nrows=n_pid,
        ncols=len(data["freq"].unique()),
        figsize=figsize,
        sharex=True,
        gridspec_kw={
            "wspace": 0,
            "hspace": 0,
            "left": distance_left_edge,
            "right": (1 - distance_right_edge),
            "top": (1 - distance_top_edge),
            "bottom": distance_bottom_edge,
        },
    )
    # Collect legend handles and labels from the first subplot
    handles, labels = None, None
    # Participant specific time courses over blocks
    data.sort_values(by=["participant_id", "block"], inplace=True)
    for i_pid, (pid, group_by_pid) in enumerate(data.groupby("participant_id")):
        for i_freq, (freq, group_by_freq_data) in enumerate(
            group_by_pid.groupby("freq")
        ):
            ax = axs[i_pid, i_freq]
            plot_conditions(ax, group_by_freq_data)

            # Capture handles and labels from the first subplot
            if handles is None:
                handles, labels = ax.get_legend_handles_labels()
                legend = ax.get_legend()
                if legend:
                    legend.remove()

            # Participant ID as text in plot
            ax.annotate(
                text=f"{int(freq)} Hz",
                xy=(0, 0),
                xytext=(0.85, 0.85),
                xycoords="axes fraction",
                textcoords="axes fraction",
            )
            ax.annotate(
                text=f"Participant {pid}",
                xy=(0, 0),
                xytext=(0.03, 0.85),
                xycoords="axes fraction",
                textcoords="axes fraction",
            )

            # Axes and labels
            ax.set_yscale("log")
            ax.tick_params(axis="y")
            ax.set_xlim(-0.5, 10.2666666)
            ax.set_ylim(0.03, 10)
            if i_freq == 0:
                ax.set_yticks([0.03, 0.1, 0.3, 1, 3], [0.03, 0.1, 0.3, 1, 3])
            else:
                ax.get_yaxis().set_visible(False)

            if i_pid == 0:
                # Secondary axis
                secax = ax.secondary_xaxis("top")
                secax.set_xticks([-0.266, 1.8666666, 4, 6.13333, 8.266666, 10.4])
                secax.set_xticklabels(
                    ["00:00", "08:00", "16:00", "24:00", "32:00", "40:00"]
                )
                secax.set_xlabel("Time since wake up [hh:mm]")
                ax.get_xaxis().set_visible(False)
            elif i_pid == len(data.participant_id.unique()) - 1:
                ax.set_xticks(sorted(data["block"].unique()))
                ax.set_xticklabels([str(round(x) + 1) for x in sorted(data["block"].unique())])
                ax.set_xlabel("Experimental block")
            else:
                # No other x axes
                ax.tick_params(axis="x", which="both", bottom=False)

    # Add a single legend for the entire figure
    fig.text(
        x=0.01,
        y=0.5,
        s="Contrast sensitivity",
        va="center",
        rotation="vertical",
    )
    fig.legend(
        handles,
        labels,
        ncol=3,  # Spread legend horizontally
        loc="lower center",  # Position at the bottom center
        # bbox_to_anchor=(0.5, 0.02),  # Adjust this to position below the subplots
        frameon=False,
        # title="Directions",
    )

    # Add a title to the entire figure
    if letter is not None:
        fig.text(
            x=distance_left_edge * 1 / 3,
            y=(1 - distance_top_edge) + (distance_top_edge * 2 / 3),
            s=letter,
            transform=fig.transFigure,
            fontsize=14,
            # fontfamily="Arial",
            fontweight="bold",
            ha="left",
        )
    fig.text(
        x=distance_left_edge,
        y=(1 - distance_top_edge) + (distance_top_edge * 2 / 3),
        s="Individual temporal contrast sensitivity over 40 hours",
        transform=fig.transFigure,
        fontsize=14,
        # fontfamily="Arial",
        # fontweight="bold",
        ha="left",
    )

    return fig, axs


def create_plot_blocks_group_timecourses(data):
    # Requires data that is already averaged per particpant
    # Plot Grand Average
    avgdata = summarize_contrastsens_by(
        data=data, group_vars=["block", "condition", "freq"], cs_col="cs_mean"
    )
    avgdata.sort_values(by=["condition", "freq", "block"])

    distance_left_edge = 0.125
    distance_right_edge = 0.05  # 0.9
    distance_top_edge = 0.2  # 0.88
    distance_bottom_edge = 0.2  # 0.05

    fig, axs = plt.subplots(
        ncols=2,
        nrows=1,
        figsize=(4, 12),
        sharex=True,
        gridspec_kw={
            "wspace": 0,
            "hspace": 0,
            "left": distance_left_edge,
            "right": (1 - distance_right_edge),
            "top": (1 - distance_top_edge),
            "bottom": distance_bottom_edge,
        },
    )

    # Collect legend handles and labels from the first subplot
    handles, labels = None, None

    for i_freq, (_, group_by_freq_data) in enumerate(avgdata.groupby("freq")):
        ax = axs[i_freq]
        plot_conditions(ax=ax, data=group_by_freq_data)
        _mark_sleep_metropsis(ax=ax)

        # Immediately capture handles and labels before removing any legend
        if handles is None:
            handles, labels = ax.get_legend_handles_labels()

        # Always remove the legend from this subplot
        legend = ax.get_legend()
        if legend:
            legend.remove()

        # Axes and labels
        ax.set_yscale("log")
        ax.set_ylim(0.03, 10)
        ax.set_yticks([0.03, 0.1, 0.3, 1, 3], [0.03, 0.1, 0.3, 1, 3])
        ax.set_xlim(-0.66666, 10.26666)
        ax.set_xlabel("Experimental block")
        ax.set_xticks(
            ticks=sorted(data["block"].unique()),
            labels=[str(round(x) + 1) for x in sorted(data["block"].unique())],
        )
        ax.set_ylabel("Contrast sensitivity") if i_freq == 0 else None
        # Set second axis on top
        secax = ax.secondary_xaxis("top")
        secax.set_xticks(
            [-0.266, 1.8666666, 4, 6.13333, 8.266666, 10.4],
            ["00:00", "08:00", "16:00", "24:00", "32:00", "40:00"],
        )
        secax.set_xlabel("Time since wake up [hh:mm]")

        if i_freq == 1:
            # y axis
            ax.get_yaxis().set_visible(False)

    # Add a single legend for the entire figure
    fig.legend(
        handles,
        labels,
        ncol=3,
        loc="lower center",
        # bbox_to_anchor=(0.5, 0.02),
        frameon=False,
    )
    # Add title with consistent styling
    fig.text(
        x=distance_left_edge * 1 / 3,
        y=(1 - distance_top_edge) + (distance_top_edge * 2 / 3),
        s="A",
        transform=fig.transFigure,
        fontsize=14,
        fontweight="bold",
        ha="left",
    )
    fig.text(
        x=distance_left_edge,
        y=(1 - distance_top_edge) + (distance_top_edge * 2 / 3),
        s="Group data on psychophysical contrast threshold over time",
        transform=fig.transFigure,
        fontsize=14,
        # fontweight="bold",
        ha="left",
    )

    return fig, axs


def create_plot_individual_timecourse_melatonin(data: pd.DataFrame, letter: str):
    # Select target data
    data = data.copy()
    n_pid = data["participant_id"].unique().size

    distance_left_edge = 0.15
    distance_right_edge = 0.06
    distance_top_edge = 0.1
    distance_bottom_edge = 0.1

    fig, axs_right = plt.subplots(
        nrows=n_pid,
        ncols=1,
        figsize=(4, 8),
        sharex=True,
        gridspec_kw={
            "wspace": 0,
            "hspace": 0,
            "left": distance_left_edge,
            "right": (1 - distance_right_edge),
            "top": (1 - distance_top_edge),
            "bottom": distance_bottom_edge,
        },
    )

    # Collect legend handles and labels from the first subplot
    handles, labels = None, None
    # Participant specific time courses
    data.sort_values(by="participant_id", inplace=True)
    for i_pid, (pid, group_by_pid) in enumerate(data.groupby("participant_id")):
        ax = axs_right[i_pid]
        plot_melatonin(ax=ax, df=group_by_pid)

        # Participant labels
        ax.annotate(
            text=f"Participant {pid}",
            xy=(0, 0),
            xytext=(0.03, 0.85),
            xycoords="axes fraction",
            textcoords="axes fraction",
        )

        # Axes and labels
        ax.set_ylim(-5, 45)
        ax.set_yticks([0, 10, 20, 30, 40], [0, 10, 20, 30, 40])
        fig.text(
            x=0.02,
            y=0.5,
            s="Salivary melatonin concentration [pg/ml]",
            va="center",
            rotation="vertical",
        )
        if i_pid == len(data["participant_id"].unique()) - 1:
            # Last bottom x axis
            ax.set_xlabel("Experimental block")
            ax.set_xticks(ticks=np.arange(1, 11 * 3.75, 3.75), labels=np.arange(1, 12, 1))
        else:
            # No other x axes
            ax.tick_params(axis="x", which="both", bottom=False)

        # Set second axis on top
        if i_pid == 0:
            secax = ax.secondary_xaxis("top")
            secax.set_xticks(
                [0, 8, 16, 24, 32, 40],
                ["00:00", "08:00", "16:00", "24:00", "32:00", "40:00"],
            )
            secax.set_xlabel("Time since wake up [hh:mm]")

    # Set the same x-ticks for the new axis as the original plot
    # bottom_ax = fig.add_axes([0.15, 0.1, (0.95 - 0.15), 0])  # [left, bottom, width, height]
    # bottom_ax.set_xticks(
    #     np.arange(1, 11 * 3.75, 3.75), np.arange(0, 11, 1)
    # )  # Match x-axis ticks
    # bottom_ax.set_xlim(ax.get_xlim())  # Match x-axis range
    # bottom_ax.set_xlabel("Experimental block")  # Label for the new axis
    # bottom_ax.set_yticks([])
    # bottom_ax.spines["top"].set_visible(False)

    handles, labels = axs_right[0].get_legend_handles_labels()
    fig.legend(
        handles,
        labels,
        ncols=3,
        loc="lower center",
        frameon=False,
    )
    fig.text(
        x=distance_left_edge * 1 / 3,
        y=(1 - distance_top_edge) + (distance_top_edge * 2 / 3),
        s=letter,
        transform=fig.transFigure,
        fontsize=14,
        fontweight="bold",
        ha="left",
    )
    fig.text(
        x=distance_left_edge,
        y=(1 - distance_top_edge) + (distance_top_edge * 2 / 3),
        s="Individual salivary melatonin data",
        transform=fig.transFigure,
        fontsize=14,
        # fontweight="bold",
        ha="left",
    )
    return fig, axs_right


def _mark_sleep_melatonin(ax: plt.Axes):
    """Mark sleep periods in melatonin group plots."""
    ax.axvspan(xmin=-0.5, xmax=0, color="#E5EBFB", alpha=0.5, lw=0)
    ax.axvspan(
        xmin=4.0 * 3.75 + 1,
        xmax=6.133333333 * 3.75 + 1,
        color="#E5EBFB",
        alpha=0.5,
        lw=0,
    )
    ax.axvspan(
        xmin=40,
        xmax=41.5,
        color="#E5EBFB",
        alpha=0.5,
        lw=0,
    )


def create_plot_group_melatonin(df, x_col="hours_after_wakeup"):
    distance_left_edge = 0.175
    distance_right_edge = 0.05
    distance_top_edge = 0.2
    distance_bottom_edge = 0.2
    fig, ax = plt.subplots(
        nrows=1,
        ncols=1,
        figsize=(4, 4),
        gridspec_kw={
            "wspace": 0,
            "hspace": 0,
            "left": distance_left_edge,
            "right": (1 - distance_right_edge),
            "top": (1 - distance_top_edge),
            "bottom": distance_bottom_edge,
        },
    )

    # Sleep shading
    _mark_sleep_melatonin(ax)

    # Horizontal line
    hline = ax.axhline(0, linestyle="--", color="#990033", label="Zero line")

    # Dots
    scatter = ax.scatter(
        x=df[x_col].values,
        y=df["mean"].values,
        color="#6D94BC",
        edgecolor="#3C68AB",
        label="Group average",
    )

    # Connecting line
    (line,) = ax.plot(df[x_col], df["mean"], color="#30476B", linewidth=1)

    # Error bars
    errorbar = ax.errorbar(
        x=df[x_col],
        y=df["mean"],
        yerr=df["sem"],
        fmt=" ",
        ecolor="#30476B",
        elinewidth=1,
    )

    # Axes and labels
    ax.set_ylim(-5, 45)
    ax.set_yticks([0, 10, 20, 30, 40], [0, 10, 20, 30, 40])
    ax.set_ylabel("Salivary melatonin\nconcentration [pg/ml]")
    ax.set_xlabel("Experimental block")
    ax.set_xticks(ticks=np.arange(1, 11 * 3.75, 3.75), labels=np.arange(1, 12, 1))
    secax = ax.secondary_xaxis("top")
    secax.set_xticks(
        [0, 8, 16, 24, 32, 40],
        ["00:00", "08:00", "16:00", "24:00", "32:00", "40:00"],
    )
    secax.set_xlabel("Time since wake up [hh:mm]")
    ax.set_xlim(-0.5, 41.5)

    # Title and legends
    fig.text(
        x=distance_left_edge * 1 / 3,
        y=(1 - distance_top_edge) + (distance_top_edge * 2 / 3),
        s="B",
        transform=fig.transFigure,
        fontsize=14,
        fontweight="bold",
        ha="left",
    )
    fig.text(
        x=distance_left_edge,
        y=(1 - distance_top_edge) + (distance_top_edge * 2 / 3),
        s="Group salivary melatonin data",
        transform=fig.transFigure,
        fontsize=14,
        # fontweight="bold",
        ha="left",
    )

    # Custom legend handles
    legend_handles = [
        Line2D(
            [0],
            [0],
            color="#30476B",
            marker="o",
            markersize=6,
            markerfacecolor="#6D94BC",
            markeredgecolor="#3C68AB",
            linestyle="-",
            linewidth=1,
            label="Empirical data",
        ),
        hline,
    ]

    # Add legend
    ax.legend(
        handles=legend_handles,
        ncol=2,
        frameon=False,
        bbox_to_anchor=[0.5, -0.35],
        loc="lower center",
    )

    fig.set_figheight(4)
    fig.set_figwidth(4)
    return fig, ax


def plot_cs_confidence_ellipse(ax, x, y, n_std=1.0, **kwargs):
    """
    Create a plot of the covariance confidence ellipse of `x` and `y`.

    Parameters:
        ax (matplotlib.axes.Axes): The axes object to draw the ellipse on.
        x (array-like): Data points for the x-axis.
        y (array-like): Data points for the y-axis.
        n_std (float): The number of standard deviations to determine the ellipse's radii.
        **kwargs: Additional keyword arguments for `matplotlib.patches.Ellipse`.
    """
    # Calculate the covariance matrix and its eigenvalues/eigenvectors
    cov = np.cov(x, y)

    # Compute the mean of the data
    center_x = np.mean(x)
    center_y = np.mean(y)

    # Version 1
    # Based on Eigenvalues / Eigenvectors
    eigenvals, eigenvecs = np.linalg.eigh(cov)
    angle = np.degrees(np.arctan2(eigenvecs[1, 0], eigenvecs[0, 0]))
    # The width and height of the ellipse are scaled by (sqrt of eigenvalues * n_std)
    ellipse_radius_x, ellipse_radius_y = n_std * np.sqrt(eigenvals)

    # # Version 2
    # pearson = cov[0, 1] / np.sqrt(cov[0, 0] * cov[1, 1])
    # # Calculate ellipse radii
    # ellipse_radius_x = np.sqrt(1 + pearson) * n_std
    # ellipse_radius_y = np.sqrt(1 - pearson) * n_std
    # # Angle of ellipse
    # angle = np.degrees(np.arctan2(ellipse_radius_y, ellipse_radius_x))

    # # Create and plot the ellipse
    # ellipse = patches.Ellipse(
    #     xy=(center_x, center_y),
    #     width=ellipse_radius_x * 2,
    #     height=ellipse_radius_y * 2,
    #     angle=angle,
    #     **kwargs,
    # )
    # Create the ellipse patch and add it to the axes
    ellipse = patches.Ellipse(
        xy=(center_x, center_y),
        width=ellipse_radius_x * 2,
        height=ellipse_radius_y * 2,
        angle=angle,
        # labels=None,
        **kwargs,
    )

    ax.add_patch(ellipse)
    return ax


def plot_cs_comparison(ax, df, cond1, cond2):
    """
    Creates a scatter plot comparing cs_mean of two conditions for each participant and block.

    Parameters:
        df (pd.DataFrame): DataFrame with columns ['block', 'condition', 'participant_id', 'cs_mean']
        cond1 (str): The first condition to compare
        cond2 (str): The second condition to compare

    Returns:
        fig, ax: The matplotlib figure and axes objects
    """
    condition_dict = {
        "achromatic": "L+M+S (luminance)",
        "red-green": "L-M (red-green)",
        "blue-yellow": "S (blue-yellow)",
    }
    custom_colors = [
        "#ED6D66",
        "#D5842F",
        "#A49930",
        "#5BA930",
        "#52B455",
        "#54B89D",
        "#50B0D7",
        "#459AF8",
        "#AA7AF7",
        "#EB5DE6",
        "#EC5AAD",
    ]

    # Pivot the DataFrame to have conditions as columns
    pivot_df = df.pivot_table(
        index=["participant_id", "block"], columns="condition", values="cs_mean"
    ).reset_index()

    # Create a colour palette for participants
    unique_participants = pivot_df["participant_id"].unique()
    num_participants = len(unique_participants)
    cmap = plt.colormaps["tab20"]  # Get the colormap

    # Plot each participant's data with block transparency
    for i, pid in enumerate(unique_participants):
        pid_data = pivot_df[pivot_df["participant_id"] == pid]
        x = pid_data[cond1]
        y = pid_data[cond2]

        # Transparency scales with block number
        # alpha_values = pid_data["block"] / pid_data["block"].max()

        ax.scatter(
            x=pid_data[cond1],
            y=pid_data[cond2],
            color=custom_colors[i],  # cmap(i / num_participants),  # Normalize index
            edgecolors="black",
            linewidth=0.7,
            alpha=0.7,  # + 0.6 * alpha_values,  # Minimum 0.4 transparency
            label=f"{pid}",
            s=15,
        )
        plot_cs_confidence_ellipse(
            ax=ax,
            x=x,
            y=y,
            edgecolor=custom_colors[i],
            facecolor="none",  # label=f"{pid}"
        )

    # Plot 1:1 line for reference
    max_val = max(pivot_df[cond1].max(), pivot_df[cond2].max())
    min_val = min(pivot_df[cond1].min(), pivot_df[cond2].min())
    ax.plot([min_val, max_val], [min_val, max_val], "k--", linewidth=0.8, alpha=0.7)

    # Scale
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_ylim(min_val + 0.001, max_val + 0.1)  # max(df["cs_mean"]))
    ax.set_xlim(min_val + 0.001, max_val + 0.1)  # max(df["cs_mean"]))
    ax.xaxis.set_major_formatter(ticker.FuncFormatter(lambda x, p: format(int(x), ",")))
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, p: format(int(x), ",")))

    # Labels and title
    ax.set_xlabel(f"{condition_dict[cond1]}")
    ax.set_ylabel(f"{condition_dict[cond2]}")
    # fig.tight_layout()
    # fig.show()

    return ax


def create_plot_cs_comparison_grid(df):
    # Configurations for the subplot grid
    conditions = ["achromatic", "blue-yellow", "red-green"]
    freq = 2

    # Figure dimensions
    nrows = 3
    ncols = 2

    # Create a 3x2 grid of subplots
    distance_left_edge = 0.1
    distance_right_edge = 0.06
    distance_top_edge = 0.1
    distance_bottom_edge = 0.1
    fig, axs = plt.subplots(
        nrows=nrows,
        ncols=ncols,
        # figsize=figsize,
        gridspec_kw={
            "wspace": 0.2,
            "hspace": 0.3,
            "left": distance_left_edge,
            "right": (1 - 1 * distance_right_edge),
            "top": (1 - distance_top_edge),
            "bottom": distance_bottom_edge,
        },
    )

    # Collect legend handles and labels from the first subplot
    handles, labels = None, None

    # Utilize the plot_cs_comparison function for scatter plots
    for row, combo in enumerate(
        [
            ["achromatic", "red-green"],
            ["achromatic", "blue-yellow"],
            ["red-green", "blue-yellow"],
        ]
    ):
        for col, (cfreq, group_by_freq_data) in enumerate(df.groupby("freq")):
            ax = axs[row][col]  # Select the subplot location (ensure axs is treated as a 2D array)
            plot_cs_comparison(
                ax=ax, df=group_by_freq_data, cond1=combo[0], cond2=combo[1]
            )

            # Capture handles and labels from first subplot and remove its legend
            if handles is None:  # Only need to capture from first plot with a legend
                handles, labels = ax.get_legend_handles_labels()
            # Always remove the legend from this subplot
            legend = ax.get_legend()
            if legend:
                legend.remove()

            # Title
            plot_title = f"{cfreq} Hz" if col == 0 else f"{cfreq} Hz"
            ax.set_title(plot_title if row == 0 else None)

    # Add a single legend for the entire figure
    legend = fig.legend(
        handles,
        labels,
        ncol=1,
        loc="center",
        bbox_to_anchor=(1.05, 0.5),  # (0.5, 0.02),
        frameon=False,
        title="Participants",
        prop={"size": 10},
    )
    # Legend change the font size
    # legend.get_title().set_fontsize("default")  # Or specify a size like 12
    # for text in legend.get_texts():
    #     text.set_fontsize("default")  # Or specify a size like 12

    fig.text(
        x=distance_left_edge,
        y=(1 - distance_top_edge) + (distance_top_edge * 2 / 3),
        s="Comparison of contrast sensitivities of different post-receptoral mechanisms",
        transform=fig.transFigure,
        fontsize=14,
        # fontfamily="Arial",
        # fontweight="bold",
        ha="left",
    )

    return fig, axs


def main(
    data_path=DATA_DIR / "raw/clean_metropsis_TCS-2e.csv",
    meldata_path=DATA_DIR / "raw/clean_saliva_data.csv",
    melstat_path=DATA_DIR
    / "derivatives/hormones/tau_harmonics/melatonin_circadian_parameters.csv",
    out_dir=FIG_DIR,  # "/Users/hheinrichs/Downloads"
):
    """Plotting group statistics pipeline

    Args:
        out_dir (str, optional): Creates a fig directory internally. Defaults to ".".
    """
    # Create output directories
    out_dir = Path(out_dir)

    # Load data
    data = pd.read_csv(data_path)

    # Get and merge melatonin data and melatonin circadian statistiics
    melraw = pd.read_csv(meldata_path)
    melstat = pd.read_csv(melstat_path)
    meldata = melraw.merge(melstat, on="participant_id")

    # Summarize data across participants
    pid_df = summarize_contrastsens_by(
        data=data, group_vars=["participant_id", "block", "condition", "freq"]
    )
    pid_df.sort_values(by=["participant_id", "condition", "freq", "block"])
    median_participant = pid_df["participant_id"].median()  # 206

    # Create average plots
    fig, _ = create_plot_blocks_group_timecourses(data=pid_df)
    fig.set_figheight(4)
    fig.set_figwidth(7)
    plot_utils.save_figure(fig_dir=out_dir / "tcs", fig_name="img_metropsis_blocks_group.svg", fig=fig)

    # Create plots of individual time courses - first participant subgroup
    pid_df_a = pid_df.loc[
        (pid_df["participant_id"] != 200) & (pid_df["participant_id"] <= median_participant)
    ]
    fig, _ = create_plot_blocks_individual_timecourses(data=pid_df_a, letter="A")
    fig.set_figheight(10)
    fig.set_figwidth(7)
    plot_utils.save_figure(
        fig_dir=out_dir / "tcs",
        fig_name="img_metropsis_blocks_individual_a.svg",
        fig=fig,
    )

    # Create plots of individual time courses - second participant subgroup
    pid_df_b = pid_df.loc[(pid_df["participant_id"] > median_participant)]
    # tmp = pid_df.loc[(pid_df["participant_id"] == 213)]
    # tmp.loc[:, "participant_id"] = 214
    # pid_df_b = pd.concat([pid_df_b, tmp])
    fig, _ = create_plot_blocks_individual_timecourses(data=pid_df_b, letter="B")
    fig.set_figheight(10)
    fig.set_figwidth(7)
    plot_utils.save_figure(
        fig_dir=out_dir / "tcs",
        fig_name="img_metropsis_blocks_individual_b.svg",
        fig=fig,
    )

    # Create individual melatonin plots - first participant subgroup
    meldata_c = meldata.loc[
        (meldata["participant_id"] != 200)
        & (meldata["participant_id"] <= median_participant)
    ].copy()
    fig, _ = create_plot_individual_timecourse_melatonin(data=meldata_c, letter="C")
    fig.set_figheight(10)
    fig.set_figwidth(4)
    plot_utils.save_figure(
        fig_dir=out_dir / "hormones",
        fig_name="img_melatonin_individual_c.svg",
        fig=fig,
    )

    # Create individual melatonin plots - second participant subgroup
    meldata_d = meldata.loc[((meldata["participant_id"] > median_participant)), :].copy()
    meldata_d.sort_values(by="participant_id", inplace=True)
    fig, _ = create_plot_individual_timecourse_melatonin(data=meldata_d, letter="D")
    fig.set_figheight(10)
    fig.set_figwidth(4)
    plot_utils.save_figure(
        fig_dir=out_dir / "hormones",
        fig_name="img_melatonin_individual_d.svg",
        fig=fig,
    )

    # Create group melatonin plots
    meldf = meldata.loc[
        (meldata.session_id != "LE")
        & (meldata.session_id != "DL")
        & (meldata.participant_id != 200),
        [
            "timestamp_number",
            "hours_after_wakeup",
            "standard_datetime",
            "melatonin_concentration",
        ],
    ].copy()  
    meldf = (
        meldf.groupby(["standard_datetime", "hours_after_wakeup"])[
            "melatonin_concentration"
        ]
        .agg(mean="mean", std="std", sem="sem")
        .reset_index()
    )

    fig, _ = create_plot_group_melatonin(df=meldf, x_col="hours_after_wakeup")
    fig.set_figheight(4)
    plot_utils.save_figure(
        fig_dir=out_dir / "hormones",
        fig_name="img_melatonin_average.svg",
        fig=fig,
    )

    # Create average plots
    cs_col = "contrast_sensitivity"
    avgdata = summarize_contrastsens_by(
        data=data, group_vars=["block", "condition", "freq", "participant_id"], cs_col=cs_col
    )
    avgdata.sort_values(by=["condition", "freq", "block"])

    # fig, _ = create_plot_cs_comparison_grid(df=avgdata)
    # fig.set_figheight(10)
    # fig.set_figwidth(7)
    # plot_utils.save_figure(
    #     fig_dir=out_dir / "tcs",
    #     fig_name="img_metropsis_comparison_condition.svg",
    #     fig=fig,
    # )


if __name__ == "__main__":
    main(
        data_path=DATA_DIR / "raw/clean_metropsis_TCS-2e.csv",
        meldata_path=DATA_DIR / "raw/clean_saliva_data.csv",
        melstat_path=DATA_DIR
        / "derivatives/hormones/tau_harmonics/melatonin_circadian_parameters.csv",
        out_dir=FIG_DIR,
    )
