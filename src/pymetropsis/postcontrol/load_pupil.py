"""Load and summarise Pupil Labs eyetracking data.

Workflow
--------
1. `load_blocks_table`  – read the XLS that maps participant / block /
                          condition to eyetracking folders.
2. `load_all_pupil_positions` – iterate over every row of that table,
                                locate the matching pupil_positions.csv,
                                and return one tidy DataFrame.
3. `summarise_pupil`    – aggregate per participant x block x condition
                          into a set of scalar quality/variability
                          parameters ready for plotting.

Suggested parameters (computed in `summarise_pupil`)
-----------------------------------------------------
diameter_3d_mean   Mean pupil diameter (mm). Central tendency.
diameter_3d_std    Standard deviation. Overall variability.
diameter_3d_cv     Coefficient of variation (std / mean x 100, %).
                   Scale-free variability; comparable across participants.
diameter_3d_range  Max − min within the recording. Constriction amplitude.
conf_mean          Mean detection confidence (0–1). Data quality.
frac_high_conf     Fraction of samples with confidence ≥ threshold.
                   Proportion of usable data.
n_samples          Number of valid (pye3d, high-confidence) samples.
"""

from __future__ import annotations

import json
from pathlib import Path

import pandas as pd

# Canonical output locations. See STRUCTURE.md for the results/ vs reports/ rule.
from pymetropsis.paths import DATA_DIR, DERIVATIVES_DIR, TEX_DIR, ensure_dir

# ── constants ─────────────────────────────────────────────────────────────────
_DEFAULT_CONF_THRESHOLD = 0.8

TSC_EYETRACK_PATH = (
    DATA_DIR
    / "raw/group/metropsis/dc_civibe/dc_civibe_TCS-2e_blocks.xls"
    #  "raw/group/metropsis/dc_civibe/dc_civibe_TCS-2e_blocks.xls"
)

CONDITION_DICT = {
    "achromatic": "L+M+S (luminance)",
    "red-green": "L-M (red-green)",
    "blue-yellow": "S (blue-yellow)",
}


# ── helpers ───────────────────────────────────────────────────────────────────

def _extract_pid(patient_name: str) -> int:
    """Return the numeric participant ID from a 'Patient Name' string.

    Examples: '113 civibe' -> 113, '202 civibe' -> 202.
    """
    return int(str(patient_name).split()[0])


def _find_pupil_csv(eyetrack_folder: Path) -> Path | None:
    """Return the first pupil_positions.csv found under an exports/ sub-folder."""
    matches = list(eyetrack_folder.glob(f"exports/000/pupil_positions.csv"))
    if not matches:
        return None
    return matches[0]


def _load_info_player(pupil_csv: Path) -> dict:
    """Load info.player.json for the recording that contains pupil_csv.

    info.player.json sits in the recording folder, which is three levels
    above pupil_positions.csv:  <rec>/exports/000/pupil_positions.csv
                                 ^^^  recording dir
    """
    info_path = pupil_csv.parents[2] / "info.player.json"
    if not info_path.exists():
        raise FileNotFoundError(
            f"info.player.json not found at {info_path}. "
            "Run extract_eyetracking_metadata.sh first."
        )
    with open(info_path) as f:
        return json.load(f)


# ── API ────────────────────────────────────────────────────────────────

def load_tcs_eyetracking_matching(tcs_eyetrack_match_path: Path | str = TSC_EYETRACK_PATH) -> pd.DataFrame:
    """Load the block and process to eyetracking-folder matching table.

    Returns only rows that have an Eyetracking Folder entry and a valid
    Patient Name, with a numeric `participant_id` column added.

    Parameters
    ----------
    tcs_eyetrack_match_path:
        Path to the XLS file (dc_civibe_TCS-2e_blocks.xls).

    Returns
    -------
    pd.DataFrame with columns:
        participant_id, block, condition, eyetracking_folder
    """
    print(f"Loading TCS-eyetracking matching table from {tcs_eyetrack_match_path} …")
    df = pd.read_excel(tcs_eyetrack_match_path)

    # Keep only rows with an actual eyetracking folder and a patient name
    df = df.loc[
        df["Eyetracking Folder"].notna() & df["Patient Name"].notna()
    ].copy()

    df["participant_id"] = df["Patient Name"].apply(_extract_pid)
    df["Eyetracking Folder"].str.replace("eye", "113/04_expsession/eye")
    df = df.rename(columns={
        "Block": "block",
        "Condition": "condition",
        "Eyetracking Folder": "eyetracking_folder",
        "Date": "datetime",
    })

    return df[["participant_id", "block", "condition", "eyetracking_folder", "datetime"]]


def load_pupil_positions(
    pupil_csv: Path | str,
    participant_id: int,
    block: int | float,
    condition: str,
    datetime: pd.Timestamp | None = None,
    confidence_threshold: float = _DEFAULT_CONF_THRESHOLD,
) -> pd.DataFrame:
    """Load one pupil_positions.csv and attach participant metadata.

    Keeps only rows from the `pye3d 0.3.0 real-time` method, which are the
    only rows that carry a valid `diameter_3d` value. Rows estimated by the
    `2d c++` method are dropped.

    A `local_timestamp` column is added by loading the sibling
    `info.player.json`.

    A boolean `high_confidence` column is added, marking rows where the
    Pupil Labs `confidence` score meets or exceeds `confidence_threshold` (default 0.8).
    All rows are kept; column is used downstream by `summarise_pupil` to
    limit diameter metrics to reliable estimates.

    Parameters
    ----------
    pupil_csv : path to the pupil_positions.csv file.
    participant_id : numeric participant ID, attached as a metadata column.
    block : block number from the TCS matching table, attached as a column.
    condition : condition label (e.g. 'achromatic'), attached as a column.
    confidence_threshold : minimum Pupil Labs confidence score (0–1) for a
        sample to be flagged `high_confidence`. Default is 0.8.

    Returns
    -------
    pd.DataFrame with one row per pye3d sample and columns including:
        pupil_timestamp    Pupil's internal synced clock (s).
        local_timestamp    Absolute local datetime (Europe/Berlin, tz-aware).
        diameter_3d        3-D model pupil diameter (mm).
        confidence         Pupil Labs detection confidence (0–1).
        high_confidence    True if confidence >= confidence_threshold.
        participant_id, block, condition  — metadata columns.
    """
    df = pd.read_csv(pupil_csv)

    # Keep only pye3d rows – they contain diameter_3d
    df = df.loc[df["method"] == "pye3d 0.3.0 real-time"].copy()

    # ── local_timestamp ───────────────────────────────────────────────────────
    # Converting Pupil's internal synced clock to absolute local time (Europe/Berlin, CET/CEST)
    #
    # pupil_timestamp is in Pupil's internal synced clock (seconds).
    # info.player.json provides the offset to convert to Unix time:
    #   unix_time = pupil_timestamp + (start_time_system_s - start_time_synced_s)
    info = _load_info_player(Path(pupil_csv))
    offset_s = info["start_time_system_s"] - info["start_time_synced_s"]
    df["local_timestamp"] = pd.to_datetime(
        df["pupil_timestamp"] + offset_s, unit="s", utc=True
    ).dt.tz_convert("Europe/Berlin")  # CET/CEST

    # Flag high-confidence samples based on the confidence_threshold parameter
    df["high_confidence"] = df["confidence"] >= confidence_threshold

    # Physiological range filter: set implausible diameters to NaN
    # _diameter_lim = (0.5, 10.0)  # mm
    # out_of_range = (df["diameter_3d"] < _diameter_lim[0]) | (df["diameter_3d"] > _diameter_lim[1])
    # df.loc[out_of_range, "diameter_3d"] = float("nan")

    # Attach metadata
    df["participant_id"] = participant_id
    df["block"] = block
    df["condition"] = condition
    df["datetime"] = datetime

    return df.reset_index(drop=True)


def load_all_pupil_positions(
    data_dir: Path | str = DATA_DIR / "raw",
    tcs_eyetrack_match_path: Path | str = TSC_EYETRACK_PATH,
    confidence_threshold: float = _DEFAULT_CONF_THRESHOLD,
    participant_ids: list[int] | None = None,
) -> pd.DataFrame:
    """Load and summarise pupil data for every row in the blocks table.

    Each recording is summarised immediately after loading so that raw
    pupil traces are never held in memory all at once.

    Parameters
    ----------
    data_dir : root of the local raw data (…/data/raw).
    tcs_eyetrack_match_path : path to the XLS blocks table.
    confidence_threshold : passed through to `load_pupil_positions`.
    participant_ids : optional list of PIDs to restrict loading.

    Returns
    -------
    pd.DataFrame with one row per participant x block x condition
    (output of `summarise_pupil` concatenated across all recordings).
    """
    data_dir = Path(data_dir)
    match_df = load_tcs_eyetracking_matching(tcs_eyetrack_match_path)
    group_vars = ["participant_id", "block", "condition", "datetime"]

    if participant_ids is not None:
        match_df = match_df.loc[match_df["participant_id"].isin(participant_ids)]

    pupil_metrics_rows: list[pd.DataFrame] = []
    for _, row in match_df.iterrows():
        pid = int(row["participant_id"])

        # eyetracking_folder is relative to the participant's 04_expsession dir
        # e.g. './eyetracking/113_0_ac_1/001'
        rel_folder = str(row["eyetracking_folder"]).lstrip("./")
        eyetrack_folder = data_dir / str(pid) / "04_expsession" / rel_folder

        pupil_csv = _find_pupil_csv(eyetrack_folder)
        if pupil_csv is None:
            print(f"  MISSING  pupil_positions.csv  pid={pid}  "
                  f"block={row['block']}  cond={row['condition']}"
                  f"\n    looked in: {eyetrack_folder}")
            continue

        # Load, summarise, then immediately discard the raw trace
        pupilcore_data = load_pupil_positions(
            pupil_csv=pupil_csv,
            participant_id=pid,
            block=row["block"],
            condition=row["condition"],
            datetime=row["datetime"],
            confidence_threshold=confidence_threshold,
        )

        # Drop date, keep time only (HH:MM:SS) for the summary table
        pupilcore_data["datetime"] = pd.to_datetime(
            pupilcore_data["datetime"]
        ).dt.strftime("%H:%M")

        # Summarise the raw data into one row of parameters for this recording
        pupil_metrics_rows.append(
            summarise_pupil(
                pupilcore_data,
                group_vars=group_vars,
            )
        )


        del pupilcore_data

    if not pupil_metrics_rows:
        raise RuntimeError("No pupil_positions.csv files were found.")

    return pd.concat(pupil_metrics_rows, ignore_index=True)


def summarise_pupil(
    df: pd.DataFrame,
    group_vars: list[str] | None = None
) -> pd.DataFrame:
    """Aggregate pupil data into per-group scalar parameters.

    Diameter metrics (mean, std, cv, range) are computed on high-confidence
    samples only (rows where `high_confidence` is True, as flagged by
    `load_pupil_positions`). Confidence metrics (conf_mean, frac_high_conf)
    are computed on all samples.

    Parameters
    ----------
    df : output of `load_pupil_positions`, containing columns
        `diameter_3d`, `confidence`, `high_confidence`, and the
        group columns.
    group_vars : columns to group by; defaults to
        ["participant_id", "block", "condition"].

    Returns
    -------
    pd.DataFrame with one row per group and columns:

    diameter_3d_mean   Mean pupil diameter (mm), high-confidence samples.
    diameter_3d_max    Maximum pupil diameter (mm), high-confidence samples.
    diameter_3d_min    Minimum pupil diameter (mm), high-confidence samples.
    diameter_3d_std    Standard deviation of pupil diameter.
    diameter_3d_cv     Coefficient of variation (std / mean × 100, %).
    diameter_3d_range  Max − min pupil diameter (constriction amplitude).
    conf_mean          Mean confidence score across all samples.
    frac_high_conf     Fraction of all samples flagged as high-confidence.
    n_samples          Number of high-confidence samples used for diameter metrics.
    """
    if group_vars is None:
        group_vars = ["participant_id", "block", "condition"]

    # ── preprocessing ───────────────────────────────────────────────────────
    # Work on high-confidence rows only for the diameter metrics
    hc_data = df.loc[df["high_confidence"]].copy()

    # Remove implausible diameter values (e.g. due to blinks) before computing metrics
    hc_data = hc_data.loc[
        hc_data["diameter_3d"].between(0.5, 10.0)
    ]   

    agg = (
        hc_data.groupby(group_vars)["diameter_3d"]
        .agg(
            diameter_3d_mean="mean",
            diameter_3d_std="std",
            diameter_3d_max="max",
            diameter_3d_min="min",
            diameter_3d_range=lambda x: x.max() - x.min(),
            n_samples="count",
        )
        .reset_index()
    )
    agg["diameter_3d_cv"] = (
        agg["diameter_3d_std"] / agg["diameter_3d_mean"] * 100
    )

    # Confidence metrics from the full (unfiltered) data
    conf_agg = (
        df.groupby(group_vars)
        .agg(
            conf_mean=("confidence", "mean"),
            frac_high_conf=(
                "high_confidence",
                lambda x: x.sum() / len(x),
            ),
        )
        .reset_index()
    )

    return agg.merge(conf_agg, on=group_vars)


def meta_summary_pupil(summary: pd.DataFrame) -> pd.DataFrame:
    """Aggregate the per-recording summary to one row per participant × block.

    For every numeric metric the mean and standard deviation across all
    conditions and repetitions within a block are computed.

    Parameters
    ----------
    summary : output of `load_all_pupil_positions` (one row per
        participant × block × condition × datetime).

    Returns
    -------
    pd.DataFrame with columns:
        participant_id, block,
        <metric>_mean, <metric>_std  for each numeric metric column.
    """
    group_vars = ["condition", "participant_id", "block"]

    meta = (
        summary.groupby(group_vars)
        .agg(
            diameter_3d_mean_mean=("diameter_3d_mean", "mean"),
            diameter_3d_mean_std=("diameter_3d_mean", "std"),
            diameter_3d_min=("diameter_3d_min", "min"),
            diameter_3d_max=("diameter_3d_max", "max"),
        )
        .reset_index()
    )
    return meta


# ── main ──────────────────────────────────────────────────────────────────────

def main(
    participant_ids: list[int] | None = None,
    out_path: Path | str | None = DERIVATIVES_DIR / "eyetracking/pupil_summary.csv",
    out_tex: Path | str | None = TEX_DIR / "eyetracking/pupil_summary.tex",
) -> pd.DataFrame:
    """Load all pupil data, summarise, and optionally save to CSV and LaTeX.

    Parameters
    ----------
    participant_ids : list of PIDs to process; None means all participants.
    out_path : where to save the summary CSV; pass None to skip saving.
    out_tex : path to save the LaTeX tables (.tex); pass None to skip saving.

    Returns
    -------
    summary : pd.DataFrame with one row per participant x block x condition.
    """

    print("Loading and summarising pupil position data …")
    summary = load_all_pupil_positions(participant_ids=participant_ids)
    summary = summary.sort_values(["participant_id", "condition", "block"])
    print(f"  {len(summary)} rows in summary (participant x block x condition).")

    meta = meta_summary_pupil(summary)
    print(f"  {len(meta)} rows in meta-summary (participant x block).")

    if out_path is not None:
        out_path = Path(out_path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        summary.to_csv(out_path, index=False)
        print(f"Saved CSV: {out_path}")

        # ── meta-summary CSV ───────────────────────────────────────────────
        meta_csv_path = out_path.with_stem(out_path.stem + "_meta")
        meta.to_csv(meta_csv_path, index=False)
        print(f"Saved meta-summary CSV: {meta_csv_path}")

        if out_tex:
            out_tex = Path(out_tex)
            ensure_dir(out_tex.parent)

            float_cols = summary.select_dtypes(include="float").columns
            tex_df = summary.copy()
            tex_df["block"] = tex_df["block"].astype(int)  # block is an integer
            tex_df[float_cols] = tex_df[float_cols].round(3)

            # ── reorder columns into logical groups ────────────────────────
            # metadata | diameter (incl. CV) | quality (n, conf)
            tex_df = tex_df[[
                "participant_id", "block", "condition", "datetime",
                "diameter_3d_mean", "diameter_3d_std",
                "diameter_3d_max", "diameter_3d_min", "diameter_3d_range",
                "diameter_3d_cv",
                "n_samples", "conf_mean", "frac_high_conf",
            ]]

            # ── rename columns to publication-ready labels ─────────────────
            tex_df = tex_df.rename(
                columns={
                    "participant_id": "Participant ID",
                    "block": "Block",
                    "condition": "Condition",
                    "datetime": "Time",
                    "diameter_3d_mean": r"\textit{Mean}$",
                    "diameter_3d_std": r"\textit{Std. dev.}$",
                    "diameter_3d_max": r"\textit{Max}$",
                    "diameter_3d_min": r"\textit{Min}$",
                    "diameter_3d_range": r"\textit{Range}$",
                    "diameter_3d_cv": r"CV (\%)",
                    "n_samples": r"$n$",
                    "conf_mean": r"$\bar{c}$",
                    "frac_high_conf": r"$f_c$",
                }
            )

            tex_str = tex_df.to_latex(
                index=False,
                float_format="%.3f",
                escape=False,
                caption=r"Pupil summary (one row per participant \times block \times condition).",
                label="tab:pupil_summary",
            )

            out_tex.write_text(tex_str, encoding="utf-8")
            print(f"Saved LaTeX table: {out_tex}")

            # ── meta-summary LaTeX ─────────────────────────────────────────
            meta_tex_path = out_tex.with_stem(out_tex.stem + "_meta")
            meta_float_cols = meta.select_dtypes(include="float").columns
            meta_tex_df = meta.copy()
            meta_tex_df["block"] = meta_tex_df["block"].astype(int)
            meta_tex_df[meta_float_cols] = meta_tex_df[meta_float_cols].round(3)

            # ── inject \multicolumn group header above the column labels ───
            toprule = r"\toprule"
            group_header = (
                r"\multicolumn{4}{l}{} & "
                r"\multicolumn{6}{c}{\textit{Pupil diameter (mm)}} & "
                r"\multicolumn{3}{c}{Quality} \\"
                "\n"
                r"\cmidrule(lr){5-10}\cmidrule(lr){11-13}"
            )
            new_header = toprule + "\n" + group_header
            tex_str = tex_str.replace(toprule, new_header)
            tex_str = tex_str.replace(
                "\\begin{table}\n", "\\begin{table}\n\\centering\n"
            )

            meta_tex_df.set_index(["condition", "participant_id", "block"], inplace=True)
            meta_tex_df.index.set_names(["Condition", "Participant ID", "Block"], inplace=True)
            meta_tex_df.rename(columns={
                "diameter_3d_mean_mean": r"\textit{Mean}",
                "diameter_3d_mean_std":  r"\textit{Std. dev.}",
                "diameter_3d_min":       r"\textit{Min}",
                "diameter_3d_max":       r"\textit{Max}",
            }, inplace=True)
            meta_tex_df.rename(index=CONDITION_DICT, level="Condition", inplace=True)

            meta_tex_str = meta_tex_df.to_latex(
                multirow=False,
                sparsify=True,
                index=True,
                float_format="%.3f",
                escape=False,
                caption=r"Pupil meta-summary (mean \& SD of mean pupil diameter across conditions, one row per participant $\times$ block).",
                label="tab:pupil_meta_summary",
            )
            meta_tex_str = meta_tex_str.replace("\\begin{table}\n", "\\begin{table}\n\\centering\n")
            meta_tex_str = meta_tex_str.replace(
                "\\toprule",
                r"\toprule" + "\n" +
                r"\multicolumn{3}{l}{} & "
                r"\multicolumn{4}{c}{\textit{Mean pupil diameter [mm]}} \\"
                "\n"                r"\cmidrule(lr){4-7}"
            )
            meta_tex_str = meta_tex_str.replace(
                "\\end{table}",
                r"\addlinespace[0.5em]" + "\n" + r"\end{table}"
            )
            meta_tex_path.write_text(meta_tex_str, encoding="utf-8")
            print(f"Saved meta-summary LaTeX table: {meta_tex_path}")

    return summary


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Load and summarise pupil data.")
    parser.add_argument(
        "--pids", nargs="*", type=int, default=None,
        metavar="Participant ID",
        help="Participant IDs to process (default: all).",
    )
    parser.add_argument(
        "--out", type=Path,
        default=DERIVATIVES_DIR / "eyetracking/pupil_summary.csv",
        metavar="PATH",
        help="Output CSV path.",
    )
    parser.add_argument(
        "--tex",
        type=Path,
        default=TEX_DIR / "eyetracking/pupil_summary.tex",
        metavar="PATH",
        help="Output path for LaTeX (.tex) tables.",
    )

    args = parser.parse_args()
    main(participant_ids=args.pids, out_path=args.out, out_tex=args.tex)
