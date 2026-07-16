# --- Imports ---
import os

import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np
import pandas as pd

from pymetropsis.plotting.plot_utils import save_figure

# Canonical output locations. See STRUCTURE.md for the results/ vs reports/ rule.
from pymetropsis.paths import FIG_DIR, RAW_DIR

# --- Constants ---
plt.rcParams["font.family"] = "Arial"

# --- Scripts ---

def plot_participant_data(ax, fd_data, y_col: str, cmap=None):
    """Plot individual participant data with unique colors."""
    if cmap is None:
        # Use a color palette for participants
        cmap = plt.colormaps.get_cmap("tab10")

    for idx, (participant_id, group) in enumerate(fd_data.groupby("participant_id")):
        color = cmap(idx / len(fd_data["participant_id"].unique()))
        ax.plot(
            group["hours_after_wakeup"],
            group[y_col],
            color=color,
            alpha=0.5,
            linestyle="-",
            linewidth=1.2,
            #marker="o",
            #markersize=2,
            label=f"{participant_id}",
        )
    return ax


def average_hormones_over_time(
    data: pd.DataFrame, agg_over: str = "timestamp_number"
) -> pd.DataFrame:
    """Averages in pandas dataframe; requires time variable (from lookup).

    Args:
        data (pd.Dataframe): data from merged / cleaned Novolytix dataframe.
        agg_over (str, optional): column name. Defaults to "timestamp_number".

    Returns:
        pd.DataFrame: aggregated / summary data
    """
    agg_data = (
        data.groupby(agg_over)
        .agg(
            # Keep informative time columns
            hours_after_wakeup=pd.NamedAgg(
                column="hours_after_wakeup", aggfunc="first"
            ),
            # Calculate summary statistics
            mean_melatonin=pd.NamedAgg("melatonin_concentration", "mean"),
            mean_cortisol=pd.NamedAgg("cortisol_concentration", "mean"),
            se_melatonin=pd.NamedAgg(
                "melatonin_concentration",
                lambda x: x.std() / np.sqrt(len(x)),
            ),
            std_melatonin=pd.NamedAgg(
                "melatonin_concentration",
                lambda x: x.std(),
            ),
            se_cortisol=pd.NamedAgg(
                "cortisol_concentration", lambda x: x.std() / np.sqrt(len(x))
            ),
            std_cortisol=pd.NamedAgg(
                "cortisol_concentration",
                lambda x: x.std(),
            ),
        )
        .reset_index()
    )

    return agg_data


def plot_average_data(ax, agg_data, mean_col = "mean_melatonin", var_col = "se_melatonin", colour = "black"):
    """Plot average hormone data with standard deviation as error bars."""
    ax.fill_between(
        agg_data["hours_after_wakeup"],
        agg_data[mean_col] - agg_data[var_col],
        agg_data[mean_col] + agg_data[var_col],
        alpha=0.2,
        color=colour,
        # label="± 1 SD",
        edgecolor=None,
    )
    ax.errorbar(
        agg_data["hours_after_wakeup"],
        agg_data[mean_col],
        yerr=agg_data[var_col],
        color=colour,
        linewidth=0.8,
    )
    ax.plot(
        agg_data["hours_after_wakeup"],
        agg_data[mean_col],
        color=colour,
        marker="o",
        markersize=3,
        linewidth=0.8,
        # alpha=0.9,
        label="Average",
    )


def create_hormone_plots(hormone_data):
    """Create plots for melatonin and cortisol profiles."""

    # Melatonin plot
    fig, ax1 = plt.subplots(figsize=(8, 4))
    # Plot average data with standard deviatioN

    agg_data = average_hormones_over_time(hormone_data, agg_over="timestamp_number")
    plot_average_data(
        ax1,
        agg_data,
        mean_col="mean_melatonin",
        var_col="se_melatonin",
        colour=plt.colormaps.get_cmap("viridis")(50),
    )

    ax1.set_xlabel("Hours after wake up")
    ax1.set_ylabel("Melatonin concentration (pg/mL)")
    ax1.set_title(
        "Profiles of salivary hormone concentration",
        loc="left",
        fontweight="bold",
    )
    ax1.tick_params(axis="both", which="major")

    # Cortisol plot
    ax2 = ax1.twinx()

    # Plot average data with standard deviation
    plot_average_data(
        ax1,
        agg_data,
        mean_col="mean_cortisol",
        var_col="se_cortisol",
        colour=plt.colormaps.get_cmap("plasma")(50),
    )
    ax2.set_ylabel("Cortisol concentration (ng/mL)")
    ax2.tick_params(axis="both", which="major", labelsize=10)

    fig.legend(["Melatonin", "Cortisol"], loc="upper right")
    fig.tight_layout()

    return fig


def create_hormone_plot_participants(hormone_data, hormone: str="melatonin"):
    """Create plots for melatonin and cortisol profiles."""
    # Create Figure
    fig, (ax1, ax3) = plt.subplots(2, 1, figsize=(12, 6), gridspec_kw={'height_ratios': [4, 0]})

    # Use a color palette for participants
    cmap = (
        plt.colormaps["plasma"] if hormone == "melatonin" else plt.colormaps["viridis"]
    )

    # Plot individual participant data
    plot_participant_data(
        ax1,
        hormone_data,
        f"{hormone}_concentration",
        cmap,
    )

    agg_data = average_hormones_over_time(
            hormone_data, agg_over="timestamp_number"
        )
    plot_average_data(
        ax1, agg_data, mean_col=f"mean_{hormone}", var_col=f"se_{hormone}"
    )

    # Primary axis settings: set x-axis ticks for every time point, set
    ax1.set_xticks(hormone_data["hours_after_wakeup"])
    ax1.xaxis.set_major_locator(ticker.MultipleLocator(5))
    ax1.xaxis.set_major_formatter(ticker.FuncFormatter(lambda x, p: f"{int(x)}"))  # Format tick labels as integers
    ax1.set_xlim(-0.5,41.5)
    ax1.xaxis.set_minor_locator(ticker.MultipleLocator(1))  # Set minor tick spacing to 1 hour
    ax1.set_xlabel("Hours after wake up")
    ax1.set_ylabel(f"{hormone.lower().capitalize()} concentration (pg/mL)")
    ax1.legend(loc="upper left", frameon=False)

    # Add secondary x-axis for clock time
    # ax2 = ax1.twiny()
    # ax2.tick_params(axis="x", direction="inout", length=6)
    # ax2.set_xlim(ax1.get_xlim())
    # ax2.set_xticks(hormone_data["hours_after_wakeup"])
    # formatted_times = pd.to_datetime(hormone_data["standard_clocktime"], format="%H:%M").dt.strftime("%H:%M")
    # ax2.set_xticklabels(formatted_times, ha="left", rotation=45)
    # ax2.set_xlabel("Clock Time [hh:mm]")

    # Add third axis underneath
    # ax3 = fig.add_axes((0.1, 0.1, 0.8, 0.0))  # (0.1, 0.1, 0.8, 0.0)
    ax3.tick_params(axis="x", direction="inout", length=6)
    ax3.set_xlim(ax1.get_xlim())
    ax3.set_xticks(hormone_data["hours_after_wakeup"])
    formatted_times = pd.to_datetime(
        hormone_data["standard_clocktime"], format="%H:%M"
    ).dt.strftime("%H:%M")
    ax3.set_xticklabels(formatted_times, ha="right", rotation=45)
    ax3.set_xlabel("Clock time [hh:mm]")
    ax3.set_xlim(ax1.get_xlim())
    ax3.yaxis.set_visible(False) # hide the yaxis
    ax3.grid(True)  # Add a grid to the axis
    ax3.set_facecolor('lightgray')  # Set the background color of the axis

    # Figure settings
    # fig.tight_layout(pad=0.2)
    fig.subplots_adjust(top=0.90, bottom=0.1, left = 0.05)#, right = 0.95)
    ax1.set_title(
        f"Salivary {hormone.lower()} profiles over 41 hours",
        pad=20,
        loc="left",
        fontweight="bold",
    )

    if hormone == "cortisol":
        ax1.legend(loc="upper right", frameon=False)

    return fig


def main(saliva_filepath = (RAW_DIR / "clean_saliva_data.csv")):
    # Load files
    out_dir = FIG_DIR / "hormones" / "descriptives"
    os.makedirs(out_dir, exist_ok=True)
    data = pd.read_csv(saliva_filepath)

    fd_data = data[(~data["hours_after_wakeup"].isna()) & (data["session_id"] == "FD")]
    fd_data = fd_data.sort_values(["participant_id", "timestamp_number"])
    fd_data = fd_data[fd_data["participant_id"] != "200"]

    # Group average hormone profiles
    fig = create_hormone_plots(hormone_data=fd_data)
    save_figure(out_dir, "fig_hormone_profiles.pdf", fig)

    # Individual participants melatonin profiles in comparison
    fig = create_hormone_plot_participants(
        hormone_data=fd_data,
        hormone="melatonin",
    )
    save_figure(out_dir, "fig_melatonin_participant_plot.pdf", fig)

    # Individual participants hormone profiles in comparison
    fig = create_hormone_plot_participants(
        hormone_data=fd_data,
        hormone="cortisol",
    )
    save_figure(out_dir, "fig_cortisol_participant_plot.pdf", fig)


if __name__ == "__main__":
    main(saliva_filepath="./data/raw/clean_saliva_data.csv")

# --- EOF ---
