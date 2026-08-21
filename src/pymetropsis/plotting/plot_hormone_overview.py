import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.transforms import offset_copy
import numpy as np
import pandas as pd

from pymetropsis.plotting import plot_metropsis_group
from pymetropsis.plotting.plot_utils import save_figure

# Canonical output locations. See STRUCTURE.md for the results/ vs reports/ rule.
from pymetropsis.paths import DATA_DIR, FIG_DIR

# ---------- Constants ----------

plt.rcParams["font.family"] = "Arial"

# ---------- Functions ----------
def plot_zero_inflated_dist(
    fig: plt.Figure, ax: plt.Axes, data: pd.DataFrame, y_col: str = "melatonin_concentration"
):
    """
    Plot a histogram of the melatonin concentration levels, marking the median concentration.
    Each participant's median is marked with a vertical line, colored by participant_id.
    """
    data = data.copy()
    data = data.dropna(subset=[y_col])
    # Check if any negative values exist
    if (data[y_col] < 0).any():
        print("Warning: Negative melatonin concentration values found.")

    # Create histogram of melatonin levels marking median concentration, colored by participant_id
    ax.hist(
        x=data[y_col],
        bins=30,
        facecolor="#7BC8F650",
        edgecolor="black",
        linewidth=0.8,
    )

    for i_pid, pid in enumerate(sorted(data["participant_id"].unique())):
        subset = data[data["participant_id"] == pid]
        # plt.hist(
        #     subset[y_col],
        #     bins=30,
        #     alpha=0.5,
        #     label=f"P{pid}",
        #     # colored by participant_id
        #     color=plt.cm.tab20(i),  # Assuming participant_id starts at 1
        # )

        # One median line per participant
        ax.axvline(
            x=subset[y_col].median(),
            linestyle="-",
            linewidth=2.5,
            label=f"{pid}",#: {subset[y_col].median():.2f}",
            color=plt.cm.tab20(i_pid),
            alpha=0.5,
        )

    # Add overall median to legend
    ax.axvline(
        x=data[y_col].median(),
        color="k",
        linestyle=":",
        linewidth=2,
        label=f"Overall median:\n{data[y_col].median():.2f} pg/mL",
    )   

    ax.axes.grid(
        True, which="major", color="gray", linestyle="-", linewidth=0.5, alpha=0.3
    )
    # ax.xaxis.grid(
    #     True, which="minor", color="gray", linestyle="-", linewidth=0.3, alpha=0.1
    # )

    # Adjust ylim to make space for legend
    ax.set_ylim(-10, plt.ylim()[1] * 1.2)
    ax.set_xlim(-2, data[y_col].max() + 5)

    # Add labels and title
    ax.set_xlabel("Salivary melatonin concentration [pg/mL]")
    ax.set_ylabel("Frequency")

    # Add legend inside of plot
    legend = ax.legend(
        loc="upper right",
        title="Participants",
        ncol=2,
        frameon=True,
        facecolor="#FFEEB330",  # "white",
        edgecolor="#FFEEB330",  # "white",
        fontsize="small",
    )  
    legend.get_frame().set_alpha(0.3)

    # Title
    ax.set_title("Global distribution and median levels", pad=36, loc="left")

    # Create an offset transform (e.g. 10 points left)
    offset = offset_copy(ax.transAxes, fig=fig, x=-2, units="points")

    ax.text(
        -0.11,
        1.18,
        s="A",
        transform=offset,
        fontsize=12,
        fontweight="bold",
        va="center",
        ha="right",
    )

    # test --------
    fig.canvas.draw()
    return ax


def plot_polar_participant_phases(
    fig: plt.Figure, ax: plt.Axes, df: pd.DataFrame, amplitude_col: str = "amplitude", phase_col: str = "phase", pid_col: str = "participant_id" 
):
    """
    Create a polar plot of amplitude vs. acrophase for each participant.
    Each participant is represented by a unique color.
    """
    # Select only unique columns
    select_cols = [
        "participant_id",
        "tau",
        "mesor",
        "amplitude",
        "phase",
        "sine_component",
        "cosine_component",
        "amplitude_2",
        "phase_2",
        "sine_component_2",
        "cosine_component_2",
    ]
    df = df[select_cols].drop_duplicates().reset_index(drop=True).copy()
    df["phase_wrap"] = np.mod(df[phase_col], 2 * np.pi)

    # Wrap phase to [0, 2pi]
    # wrapped_phase = np.mod(df[phase_col], 2 * np.pi)
    # wrapped_phase = df[phase_col] + np.pi

    # Assign unique colors to each participant
    unique_participants = df[pid_col].unique()
    pid_colours = dict(
        zip(unique_participants, plt.cm.tab20.colors[: len(unique_participants)])
    )

    # Create polar plot
    # fig = plt.figure(figsize=(7, 10))
    # ax = fig.add_subplot(111, projection="polar")

    # Plot bars for each participant
    ymax = max(df["amplitude"]) + 1
    for i, pid in enumerate(df[pid_col]):
        ax.plot(
            [0, df["phase_wrap"][i]],
            [0, ymax],  # [0, df[amplitude_col][i]]# Radius from 0 to the amplitude
            color=pid_colours[pid],  # Color based on participant_id
            linewidth=2,  # Line width
            alpha=0.8,  # Transparency
        )
        ax.scatter(
            x=df["phase_wrap"][i],
            y=df[amplitude_col][i],  # Radius (amplitude)
            s=40,
            facecolor=(*pid_colours[pid], 0.5),  # Transparent fill color
            edgecolor=pid_colours[pid],  # Solid edge color
            linewidth=1.5,  # Edge line width
        )
        # ax.text(
        #    acrophases_rad[i],
        #    amplitudes[i] + 2,
        #    subject,
        #    ha='center',
        #    fontsize=8,
        #    color=subject_colors[subject]
        # )

    # Add a legend for participant IDs
    handles = [
        plt.Line2D(
            [0],
            [0],
            marker="o",
            color=(*color[:3], 0.5),  # Set fill alpha to 0.5
            markerfacecolor=(*color[:3], 0.5),  # Fill color with 0.5 alpha
            markeredgecolor=color,  # Edge color with full alpha
            markeredgewidth=1.5,  # Edge line width
            markersize=7,
            linestyle=" ",
            label=pid,
        )
        for pid, color in pid_colours.items()
    ]

    legend = ax.legend(
        handles=handles,
        title="Participants",
        loc="lower center",  # "lower right",
        ncol=3,
        frameon=True,
        facecolor="#FFEEB330",  # "white",
        edgecolor="#FFEEB330", #FFF2CC",  # "white",
        fontsize="small",
        bbox_to_anchor=(0.5, 0.12),  # bbox_to_anchor=(1.5, 0.122),
    )  ##,

    legend.get_frame().set_alpha(0.3)
    # legend.get_frame().set_facecolor((1, 1, 1, 0.7))
    # legend.get_frame().set_edgecolor((1, 1, 1, 0.7))

    # Customize radial axis to show hours (0–24; adjust radial limit to fit all amplitudes
    ax.set_ylim(0, ymax)

    # Adjust position of y label
    # Set radial ticks and labels for every 5 pg/mL
    ax.set_yticks(np.arange(0, max(df["amplitude"]) + 5, 5))  # Radial ticks
    ax.set_yticklabels(
        [f"{int(tick)}" for tick in np.arange(0, max(df["amplitude"]) + 5, 5)]
    )  # Label in pg/mL
    ax.set_ylabel("Amplitude [pg/mL]", labelpad=35)  # , loc="top")

    # Get current limits of the angular axis
    ax.set_xlim(0, 2*np.pi) # (-np.pi, np.pi) not possibl !!
    ax.xaxis.set_tick_params(pad=7)
    xticks = ax.get_xticks()  # np.linspace(0, 2 * np.pi, 9, endpoint=False)
    xtick_labels = []
    for tick in xticks:
        xtick_labels.append(
            f"{(tick):.2f}\n({(tick)/ (2 * np.pi) * 24:.0f}:00)"  
        )

    ax.set_xticklabels(xtick_labels)  # Label in hours

    # ax.set_theta_labels(90)  # Position theta labels
    ax.set_xlabel(
        "Estimated phase angle\n(Hours from peak to next wake-up)"  # , labelpad=20
    )

    # Add major and minor grid lines for x Axis
    ax.yaxis.grid(
        True, which="major", color="black", linestyle="-", linewidth=0.5, alpha=0.3
    )

    ax.xaxis.set_major_locator(
        plt.FixedLocator(np.linspace(0, 2 * np.pi, 8, endpoint=False))
    )
    ax.xaxis.set_minor_locator(
        plt.FixedLocator(
            np.linspace(0, 2*np.pi, 16, endpoint=False)
            )
        )
    ax.xaxis.grid(
        True, which="major", color="black", linestyle="-", linewidth=0.5, alpha=0.3
    )
    ax.xaxis.grid(
        True, which="minor", color="black", linestyle="-", linewidth=0.3, alpha=0.2
    )
    # ax.tick_params(axis="x", which="major", length=4, color="blue")

    # ax.set_theta_zero_location("N")  # Set 0 at the top
    # ax.set_theta_direction(-1)  # Clockwise direction
    ax.set_rlabel_position(22.5)  # Position radial labels

    # Add labels and title
    ax.set_title(
        "Amplitude and phase by participant", pad=10, loc="left"
    )
    offset = offset_copy(ax.transAxes, fig=fig, x=-2, units="points")
    ax.text(
        -0.15,
        1.19,
        s="B",
        fontsize=12,
        transform=offset,
        fontweight="bold",
        va="center",
        ha="right",
    )

    return ax


def plot_melatonin_colour(
    ax: plt.Axes,
    data: pd.DataFrame,
    x_col: str = "hours_after_wakeup",
    y_col: str = "melatonin_concentration",
    harmonics: bool = True,
    fill_colour: str = "#6D94BC",
    edge_colour: str = "#3C68AB",
    line_colour: str = "#30476B",
):
    """
    Plot the melatonin concentration profile (empirical with fit) for a participant over 41 hours.

    Parameters:
    ax : plt.Axes
        The axes on which to plot.
    df : pd.DataFrame
        DataFrame containing the melatonin data.
    x_col : str
        Column name for the x-axis data.
    y_col : str
        Column name for the y-axis data.
    harmonics : bool
        Whether to include harmonics in the fit.
    fill_colour : str
        Color for the scatter points.
    edge_colour : str
        Edge color for the scatter points.
    line_colour : str
        Color for the fitted line.
    """
    pid = data["participant_id"].unique().item()
    # Plot data points
    ax.scatter(
        x=data[x_col].values,
        y=data[y_col].values,
        label=f"Empirical data, participant {pid}",
        s=20,
        # color="#2C69B0",
        color=fill_colour,
        edgecolor=edge_colour,
        linewidth=0.8,
    )
    # Cosine estimates
    x = np.linspace(data[x_col].min(), data[x_col].max(), 400)
    est_amplitude = data["amplitude"].unique().item()
    est_phase = np.mod(data["phase"].unique().item(), 2 * np.pi)
    est_mesor = data["mesor"].unique().item()
    circular_tau = (2 * np.pi) / data["tau"].unique().item()
    if harmonics:
        est_amplitude_2 = data["amplitude_2"].unique().item()
        est_phase_2 = data["phase_2"].unique().item()
        # fundamental + 2nd harmonic
        y = (
            est_mesor
            + est_amplitude * np.cos(circular_tau * x + est_phase)
            + est_amplitude_2 * np.cos((2 * circular_tau * x) + est_phase_2)
        )
        ax.plot(x, y, color=line_colour, linestyle="solid", label="Cosinor fit (fundamental + 2nd harmonic)")
    # fundamental only
    y_fundament = est_mesor + est_amplitude * np.cos(circular_tau * x + est_phase)
    ax.plot(x, y_fundament, color=edge_colour, linestyle="--", linewidth=0.8, label="Cosinor fit (fundamental only)")

    return ax


def transform_phase(
    old_phase,
    old_zero=(-1 * np.pi),
    old_range=(2 * np.pi),
    new_zero=0,
    new_range=(2 * np.pi),
):
    # Shift phase by pi to match the 0-2pi range
    new_phase = new_zero + ((old_phase - old_zero) / old_range) * new_range 
    return new_phase


def rescale_phase(x, old_min=-np.pi, old_max=np.pi, new_min=0, new_max=2 * np.pi):
    """
    Rescale a phase estimate x from [old_min, old_max] to [new_min, new_max].

    Args:
        x (float or array-like): Value(s) in the old range.
        old_min (float): Old interval lower bound.
        old_max (float): Old interval upper bound.
        new_min (float): New interval lower bound.
        new_max (float): New interval upper bound.

    Returns:
        float or array-like: Rescaled value(s).
    """
    return new_min + ((x - old_min) / (old_max - old_min)) * (new_max - new_min)


def _plot_annotated_profiles(
    ax,
    data,
    pid,
    harmonics,
    fill_colour,
    edge_colour,
    line_colour,
):
    pid_data = data[data["participant_id"] == pid]
    # Melatonin data
    ax = plot_melatonin_colour(
        ax=ax,
        data=pid_data,
        x_col="hours_after_wakeup",
        y_col="melatonin_concentration",
        harmonics=harmonics,
        fill_colour=fill_colour,
        edge_colour=edge_colour,
        line_colour=line_colour,
    )

    # Recalculate phase number of experimental block
    phase_est = pid_data["phase"].unique().item()
    # phase_wrap = np.mod(phase_est, 2 * np.pi)
    tau_est = pid_data["tau"].unique().item()
    # Transform phase to hours (tau specific)
    phase_hours = (phase_est / (2 * np.pi)) * tau_est  # = φ/ω
    phase_hours_mark = tau_est - phase_hours  # = τ − φ/ω
    # Add text annotation to lin
    ax.axvline(
        x=phase_hours_mark,
        color=fill_colour,
        linestyle="--",
        linewidth=0.8,
    )

    # get second highest y value to position text box
    max_yval = pid_data["melatonin_concentration"].sort_values(ascending=False).iloc[3]
    ax.text(
        x=phase_hours_mark,
        y=max_yval + 3,
        s=f"$\\phi$ = {phase_est:.2f} rad ({phase_hours:.2f} h) phase angle corresponds to an esti-\nmated time to peak of {phase_hours_mark:.2f} h at a period of $\\tau$ = {tau_est:.2f} h.",
        color=edge_colour,
        bbox=dict(facecolor="#FFEFB355", edgecolor="#FFEEB355", pad=3),
    )

    return ax


def plot_two_melatonin_profiles(fig: plt.Figure, ax: plt.Axes, data: pd.DataFrame, pid1:int, pid2, harmonics=True):
    """
    Plot salivary melatonin profiles for two participants.

    Args:
        data (pd.DataFrame): DataFrame with columns:
            - "participant_id": Participant ID.
            - "hours_after_wakeup": Time since wake-up (hours).
            - "melatonin_concentration": Melatonin concentration (pg/ml).
        pid1 (int, optional): First participant ID. Defaults to 207.
        pid2 (int, optional): Second participant ID. Defaults to 210.
        harmonics (bool, optional): Include harmonic components. Defaults to True.

    Notes:
        - Uses `plot_melatonin_colour` for plotting.
        - Adds a zero-crossing line, axis labels, and a secondary time axis.
        - Legend includes profile labels and visual elements.

    Example:
        >>> plot_two_melatonin_profiles(data, pid1=101, pid2=102, harmonics=False)
    """
    # Collect legend handles and labels from the first subplot
    handles, labels = None, None

    # Plot line at y=0
    ax.axhline(y=0, color="black", linestyle=(0, (5, 10)), linewidth=0.8, alpha=0.7, label="Zero line")

    for current_pid in [pid1, pid2]:
        if current_pid not in data["participant_id"].unique():
            raise ValueError(f"Participant ID {current_pid} not found in data.")

    ax = _plot_annotated_profiles(
        ax=ax,
        data=data,
        # First participant
        pid=pid1,
        harmonics=harmonics,
        fill_colour="#6D94BC",
        edge_colour="#3C68AB",
        line_colour="#30476B",
    )  # First participant
    ax.text(
        x=(11.05 * 3.75),
        y=35,
        s=f"{pid1}",
        color="#30476B",
        fontsize=11,
    )

    ax = _plot_annotated_profiles(
        ax=ax, 
        data=data, 
        # Second participant
        pid = pid2,
        harmonics=harmonics,
        fill_colour="#D78DAD",
        edge_colour="#C94E98",
        line_colour="#990033",
        )   
    ax.text(
        x=(11.05 * 3.75),
        y=5.5,
        s=f"{pid2}",
        color="#990033",
        fontsize=11,
    )

    # Curved arrow

    arrow_patch = patches.FancyArrowPatch(
        (3.4 * 3.75, 38),  # Start point (top left)
        (4.05 * 3.75, 32),  # End point (lower right)
        connectionstyle="arc3,rad=0.4",  # Curved arrow with specified radius
        arrowstyle="->",  # Arrow style
        mutation_scale=10,  # Scale of the arrow
        fc="#30476B",  # Fill color
        ec="#30476B",  # Edge color
        lw=1,  # Line width
    )
    ax.add_patch(arrow_patch)
    ax.text(
        x=(3 * 3.75),
        y=38.5,
        s="$f + 2f$ fit",
        color="#30476B",
        fontsize=11,
    )

    # Curved arrow
    arrow_patch = patches.FancyArrowPatch(
        (2.2 * 3.75, 15),  # Start point (top left)
        (2.8 * 3.75, 10),  # End point (lower right)
        connectionstyle="arc3,rad=0.3",  # Curved arrow with specified radius
        arrowstyle="->",  # Arrow style
        mutation_scale=10,  # Scale of the arrow
        fc="#30476B",  # Fill color
        ec="#30476B",  # Edge color
        lw=1,  # Line width
        #linestyle=":",  # Dotted line style
    )
    ax.add_patch(arrow_patch)
    ax.text(
        x=(2 * 3.75),
        y=15.5,
        s="$f$ fit",
        color="#30476B",
        fontsize=11,
    )

    # Axes and labels
    if data["melatonin_concentration"].min() > -5:
        ax.set_ylim(-5, 45)
    else:
        ax.set_ylim(data["melatonin_concentration"].min() - 5, 45)
    ax.set_yticks([0, 10, 20, 30, 40], [0, 10, 20, 30, 40])
    ax.set_ylabel("Salivary melatonin concentration [pg/ml]", labelpad=10)

    # Change labels from hours to block index starting with 1 for first (1-12)
    ax.set_xlabel("Experimental block") 
    ax.set_xticks(np.arange(1, 11 * 3.75, 3.75), np.arange(1, 12, 1))
    # ax.tick_params(axis="x", which="both", bottom=False)

    ax.xaxis.grid(
        True, which="major", color="gray", linestyle="-", linewidth=0.5, alpha=0.3
    )
    ax.xaxis.grid(
        True, which="minor", color="gray", linestyle="-", linewidth=0.3, alpha=0.1
    )

    # Set second axis on top
    secax = ax.secondary_xaxis("top")
    secax.set_xticks(
        [0, 8, 16, 24, 32, 40],
        ["00:00", "08:00", "16:00", "24:00", "32:00", "40:00"],
    )
    secax.set_xlabel("Hours from peak to next wake-up [hh:mm]")

    # Legend
    handles, labels = ax.get_legend_handles_labels()
    # ax.legend(
    #     handles,
    #     labels,
    #     ncols=1,
    #     loc="upper left",
    #     frameon=False,

    # )
    # Subplot title
    ax.set_title(
        "Example concentrations profiles of two participants across 41 hours",
        pad=12,
        loc="left",
    )

    # Create an offset transform (e.g. 10 points left)
    offset = offset_copy(ax.transAxes, fig=fig, x=-2, units="points")

    ax.text(
        -0.048,
        1.18,
        s="C",
        transform=offset,
        fontsize=12,
        fontweight="bold",
        va="center",
        ha="right",
    )

    return ax


def create_melatonin_grid_figure(meldata: pd.DataFrame):
    """
    Create a figure with three panels: a histogram, a polar plot, and a scatter plot.
    The scatter plot spans the entire width of the figure below the other two plots.
    """
    # Create the figure and subplots with a grid layout
    fig = plt.figure(figsize=(8.5, 9), constrained_layout=True)

    gs = fig.add_gridspec(
        2,
        2,
        height_ratios=[1, 1.1],
        width_ratios=[1, 1],
        hspace=0.05,
        wspace=0.05,  # Adjust height and width ratios, and set space between rows
    )

    ax1 = fig.add_subplot(gs[0, 0])  # (2, 2, 1)  # Corrected subplot number
    ax1 = plot_zero_inflated_dist(
        fig=fig, ax=ax1, data=meldata, y_col="melatonin_concentration"
    )

    # Create a figure first row, second column and then add an ax with a polar plot
    ax2 = fig.add_subplot(gs[0, 1], projection="polar")  # (2,2,2)
    ax2 = plot_polar_participant_phases(
        fig=fig,
        ax=ax2,
        df=meldata,
        amplitude_col="amplitude",
        phase_col="phase",
        pid_col="participant_id",
    )

    # Add ax at bottom both columns
    ax3 = fig.add_subplot(gs[1, :])  # (2, 1, 2)
    ax3 = plot_two_melatonin_profiles(
        fig=fig, ax=ax3, data=meldata, pid1=207, pid2=210, harmonics=True
    )
    return fig, (ax1, ax2, ax3)


# ---------- Script ----------

if __name__ == "__main__":
    # Load data
    out_dir = FIG_DIR / "hormones/descriptives"
    raw_path = DATA_DIR / "raw/clean_saliva_data.csv"
    param_path = (
        DATA_DIR / "derivatives/hormones/tau_harmonics/melatonin_circadian_parameters.csv"
    )

    raw_data = pd.read_csv(raw_path)
    param_df = pd.read_csv(param_path)

    meldata = param_df.merge(raw_data, on="participant_id")
    meldata = meldata[
        (meldata["participant_id"] < 214) & (meldata["session_id"] == "FD")
    ].copy()

    # Figure formatting
    # fig.suptitle(f"Overview of melatonin parameters" fontsize=14, y=1)
    fig, axes = create_melatonin_grid_figure(meldata=meldata)
    plt.show()
    save_figure(fig_name="img_melatonin_overview_figure.pdf", fig_dir=out_dir, fig=fig)
