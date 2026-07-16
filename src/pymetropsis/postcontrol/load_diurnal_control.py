# ---------- Imports ----------

from pathlib import Path

import pandas as pd
import numpy as np

# Canonical output locations. See STRUCTURE.md for the results/ vs reports/ rule.
from pymetropsis.paths import (
    DERIVATIVES_DIR,
    PROJECT_ROOT,
    RAW_DIR,
    TABLE_DIR,
    TEX_DIR,
)


# ---------- Constants ----------

CONDITION_RENAME: dict[str, str] = {
    "achromatic": "L+M+S (luminance)",
    "red-green": "L-M (red-green)",
    "blue-yellow": "S (blue-yellow)",
}
CONTEXT_RENAME: dict[str, str] = {
    "dc_c": "Constrained pupil",
    "dc_f": "Free viewing",
}
CONDITION_ORDER: list[str] = [CONDITION_RENAME[c] for c in ["achromatic", "red-green", "blue-yellow"]]
CONTEXT_ORDER: list[str] = [CONTEXT_RENAME["dc_c"], CONTEXT_RENAME["dc_f"]]

_FMT = "{:.3f} ({:.3f})"   # "mean (std)" cell format


# ---------- Data loading ----------

def load_tcs_data(csv_path: Path) -> pd.DataFrame:
    """Load and annotate the raw diurnal-control TCS CSV."""
    data = pd.read_csv(csv_path)
    data = data.loc[data["participant_id"].notna()].copy()
    data["session"] = "DC"
    data["context"] = "F"
    data.loc[data["block"] % 2 == 1, "context"] = "C"
    data["session_context"] = (data["session"] + "_" + data["context"]).str.lower()
    return data


# ---------- TCS summary ----------

def compute_tcs_grp(data: pd.DataFrame) -> pd.DataFrame:
    """Compute mean, std and formatted string per participant × freq × condition × context."""
    grp = (
        data.groupby(["participant_id", "freq", "condition", "session_context"])[
            "contrast_sensitivity"
        ]
        .agg(["mean", "std"])
        .reset_index()
    )
    grp["cs_str"] = grp.apply(
        lambda r: _FMT.format(r["mean"], np.nan_to_num(r["std"], nan=0.0)), axis=1
    )
    return grp


def build_tcs_wide_pivot(grp: pd.DataFrame) -> pd.DataFrame:
    """Pivot grp: rows = participant × condition × context; columns = frequency."""
    grp_renamed = grp.copy()
    grp_renamed["condition"] = grp_renamed["condition"].map(CONDITION_RENAME)
    grp_renamed["session_context"] = grp_renamed["session_context"].map(CONTEXT_RENAME)
    grp_renamed["condition"] = pd.Categorical(
        grp_renamed["condition"], categories=CONDITION_ORDER, ordered=True
    )
    grp_renamed["session_context"] = pd.Categorical(
        grp_renamed["session_context"], categories=CONTEXT_ORDER, ordered=True
    )

    pt = grp_renamed.pivot(
        index=["participant_id", "condition", "session_context"],
        columns="freq",
        values="cs_str",
    )
    pt.columns.name = None
    return (
        pt.sort_values(["participant_id", "condition", "session_context"])
        .reset_index()
    )


def build_tcs_tidy_pivot(grp: pd.DataFrame) -> pd.DataFrame:
    """Pivot grp into tidy form: (participant × condition × freq) × context."""
    grp_renamed = grp.copy()
    grp_renamed["condition"] = grp_renamed["condition"].map(CONDITION_RENAME)
    grp_renamed["session_context"] = grp_renamed["session_context"].map(CONTEXT_RENAME)
    grp_renamed["condition"] = pd.Categorical(
        grp_renamed["condition"], categories=CONDITION_ORDER, ordered=True
    )

    pivot = grp_renamed.pivot(
        index=["participant_id", "condition", "freq"],
        columns="session_context",
        values="cs_str",
    ).reset_index()
    return pivot.sort_values(["participant_id", "condition", "freq"]).reset_index(drop=True)


# ---------- Pupil summary ----------

def compute_pupil_grp(pupil_csv: Path) -> pd.DataFrame:
    """Summarise per-recording pupil means to participant × condition statistics."""
    pupil = pd.read_csv(pupil_csv)
    grp = (
        pupil.groupby(["participant_id", "condition"])["diameter_3d_mean"]
        .agg(mean="mean", std="std")
        .reset_index()
    )
    grp["diam_str"] = grp.apply(
        lambda r: _FMT.format(r["mean"], np.nan_to_num(r["std"], nan=0.0)), axis=1
    )
    grp["condition"] = grp["condition"].map(CONDITION_RENAME)
    grp["condition"] = pd.Categorical(
        grp["condition"], categories=CONDITION_ORDER, ordered=True
    )
    return grp.sort_values(["participant_id", "condition"]).reset_index(drop=True)


# ---------- LaTeX builders ----------

def _latex_tcs_wide(pt: pd.DataFrame) -> str:
    """Build LaTeX for the wide pivot table (condition × context rows, freq cols)."""
    freq_cols = [c for c in pt.columns if isinstance(c, (int, float))]
    freq_headers = " & ".join(rf"{int(f)}\,Hz" for f in freq_cols)

    lines = [
        r"\begin{table}[htbp]",
        r"\centering",
        r"\caption{Summary statistics of contrast sensitivity per participant, condition, "
        r"context, and temporal frequency (mean with std.\ dev.\ in parentheses). "
        r"Values reflect all trials pooled across experimental blocks.}",
        r"\label{tab:tcs_diurnal_control}",
        r"%\small",
        r"%\setlength{\tabcolsep}{5pt}",
        r"\begin{tabular}{lllcc}",
        r"\toprule",
        f"Participant ID & Condition & Context & {freq_headers} \\\\",
        r"\midrule",
    ]

    prev_pid, prev_cond = None, None
    for _, row in pt.iterrows():
        pid  = int(row["participant_id"])
        cond = str(row["condition"])
        ctx  = str(row["session_context"])

        if prev_pid is not None and pid != prev_pid:
            lines.append(r"\midrule")
        elif prev_cond is not None and cond != prev_cond and pid == prev_pid:
            lines.append(r"\cmidrule(l){2-5}")

        pid_cell  = str(pid) if pid  != prev_pid  else ""
        cond_cell = cond     if (cond != prev_cond or pid != prev_pid) else ""
        data_cells = " & ".join(str(row[f]) for f in freq_cols)
        lines.append(f"{pid_cell} & {cond_cell} & {ctx} & {data_cells} \\\\")
        prev_pid, prev_cond = pid, cond

    lines += [r"\bottomrule", r"\end{tabular}", r"\end{table}"]
    return "\n".join(lines)


def _latex_tcs_tidy(pivot: pd.DataFrame) -> str:
    """Build LaTeX for the tidy TCS table (participant × condition × freq rows, context cols)."""
    lines = [
        r"\begin{table}[htbp]",
        r"\centering",
        r"\caption{Summary statistics of contrast sensitivity per participant, condition, "
        r"temporal frequency, and context (mean with std.\ dev.\ in parentheses). "
        r"Values reflect all trials pooled across experimental blocks.}",
        r"\label{tab:tcs_diurnal_control_tidy}",
        r"%\small",
        r"%\setlength{\tabcolsep}{5pt}",
        r"\begin{tabular}{lllcc}",
        r"\toprule",
        r"Participant ID & Condition & \makecell{Temporal\\frequency (Hz)} "
        r"& Constrained pupil & Free viewing \\",
        r"\midrule",
    ]

    prev_pid, prev_cond = None, None
    for _, row in pivot.iterrows():
        pid, cond, freq = int(row["participant_id"]), str(row["condition"]), int(row["freq"])

        if prev_pid is not None and pid != prev_pid:
            lines.append(r"\midrule")
        elif prev_cond is not None and cond != prev_cond and pid == prev_pid:
            lines.append(r"\cmidrule(l){2-5}")

        pid_cell  = str(pid)  if pid  != prev_pid  else ""
        cond_cell = cond      if (cond != prev_cond or pid != prev_pid) else ""
        lines.append(
            f"{pid_cell} & {cond_cell} & {freq} "
            f"& {row[CONTEXT_ORDER[0]]} & {row[CONTEXT_ORDER[1]]} \\\\"
        )
        prev_pid, prev_cond = pid, cond

    lines += [r"\bottomrule", r"\end{tabular}", r"\end{table}"]
    return "\n".join(lines)


def _latex_pupil_tidy(pupil_grp: pd.DataFrame) -> str:
    """Build LaTeX for the pupil diameter table (participant × condition rows)."""
    lines = [
        r"\begin{table}[htbp]",
        r"\centering",
        r"\caption{Summary statistics of pupil diameter per participant and condition "
        r"(mean with std.\ dev.\ in parentheses, in mm). "
        r"Values are computed from free-viewing blocks only, "
        r"pooled across all within-block recordings.}",
        r"\label{tab:pupil_diurnal_control_tidy}",
        r"\small",
        r"\setlength{\tabcolsep}{5pt}",
        r"\begin{tabular}{llc}",
        r"\toprule",
        r"Participant ID & Condition & Pupil diameter (mm) \\",
        r"\midrule",
    ]

    prev_pid, prev_cond = None, None
    for _, row in pupil_grp.iterrows():
        pid, cond = int(row["participant_id"]), str(row["condition"])

        if prev_pid is not None and pid != prev_pid:
            lines.append(r"\midrule")
        elif prev_cond is not None and cond != prev_cond and pid == prev_pid:
            lines.append(r"\cmidrule(l){2-3}")

        pid_cell  = str(pid) if pid  != prev_pid  else ""
        cond_cell = cond     if (cond != prev_cond or pid != prev_pid) else ""
        lines.append(f"{pid_cell} & {cond_cell} & {row['diam_str']} \\\\")
        prev_pid, prev_cond = pid, cond

    lines += [r"\bottomrule", r"\end{tabular}", r"\end{table}"]
    return "\n".join(lines)


# ---------- Save helpers ----------

def _save_csv(df: pd.DataFrame, path: Path, **to_csv_kwargs) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    df.to_csv(path, **to_csv_kwargs)
    print(f"Saved CSV: {path.relative_to(PROJECT_ROOT)}")


def _save_tex(content: str, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    print(f"Saved LaTeX: {path.relative_to(PROJECT_ROOT)}")


# ---------- Main ----------

def main() -> None:
    csv_dir = TABLE_DIR / "eyetracking"
    tex_dir = TEX_DIR / "eyetracking"

    # ── TCS data ──────────────────────────────────────────────────────────────
    data = load_tcs_data(RAW_DIR / "clean_metropsis_dc.csv")
    grp  = compute_tcs_grp(data)

    # Wide pivot (participant × freq rows, condition × context cols)
    pt = build_tcs_wide_pivot(grp)
    _save_csv(pt, csv_dir / "diurnal_control_tcs.csv", index=False)
    _save_tex(_latex_tcs_wide(pt), tex_dir / "diurnal_control_tcs.tex")

    # Tidy pivot (participant × condition × freq rows, context cols)
    tidy = build_tcs_tidy_pivot(grp)
    grp_renamed = grp.copy()
    grp_renamed["condition"] = grp_renamed["condition"].map(CONDITION_RENAME)
    grp_renamed["session_context"] = grp_renamed["session_context"].map(CONTEXT_RENAME)
    _save_csv(
        grp_renamed[["participant_id", "freq", "condition", "session_context", "mean", "std"]],
        csv_dir / "diurnal_control_tcs_tidy.csv",
        index=False,
    )
    _save_tex(_latex_tcs_tidy(tidy), tex_dir / "diurnal_control_tcs_tidy.tex")

    # ── Pupil data ────────────────────────────────────────────────────────────
    pupil_grp = compute_pupil_grp(
        DERIVATIVES_DIR / "eyetracking" / "pupil_summary.csv"
    )
    _save_csv(
        pupil_grp[["participant_id", "condition", "mean", "std"]],
        csv_dir / "diurnal_control_pupil_tidy.csv",
        index=False,
    )
    _save_tex(_latex_pupil_tidy(pupil_grp), tex_dir / "diurnal_control_pupil_tidy.tex")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Load and summarise metropsis data from post-hoc diurnal control experiment."
    )
    parser.parse_args()
    main()
