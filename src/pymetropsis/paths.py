"""Canonical output locations for the civibe_psychophysics pipeline.

Import these constants instead of hard-coding directory strings so that every
script agrees on where things go. The rule (see STRUCTURE.md):

    data/raw/          immutable inputs, never written by analysis
    data/derivatives/  machine artifacts that feed *other* scripts
                       (model fits, .nc, parameter CSVs, resampled data)
    results/           everything a script generates as a *final* output
                       (figures, result tables, .tex fragments, metadata)
    reports/           ONLY hand-curated deliverables (manuscript snapshots,
                       applications, talks). Never written by the pipeline.

If deleting a folder and re-running the pipeline recreates it, it belongs in
results/ (or data/derivatives/), never in reports/.

Usage
-----
    from pymetropsis.paths import FIG_DIR, TABLE_DIR, TEX_DIR, ensure_dir

    out_dir = ensure_dir(FIG_DIR / "hormones" / "descriptives")
    fig.savefig(out_dir / "fig_overview.png")
"""

from pathlib import Path

# Repo root: this file is src/pymetropsis/paths.py -> parents[2] is the repo.
PROJECT_ROOT = Path(__file__).resolve().parents[2]

# --- inputs & intermediate artifacts -------------------------------------
DATA_DIR = PROJECT_ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
DERIVATIVES_DIR = DATA_DIR / "derivatives"  # model fits, param CSVs, .nc, ...

# --- final analysis outputs (regenerable) --------------------------------
RESULTS_DIR = PROJECT_ROOT / "results"
FIG_DIR = RESULTS_DIR / "figures"    # all .png / .svg / .pdf plots
TABLE_DIR = RESULTS_DIR / "tables"   # final result tables (.csv)
TEX_DIR = RESULTS_DIR / "tex"        # generated .tex fragments (tab_*, vars_*)
METADATA_DIR = RESULTS_DIR / "metadata"  # settings.json, run manifests

# --- hand-curated deliverables (never written by the pipeline) -----------
REPORTS_DIR = PROJECT_ROOT / "reports"


def ensure_dir(path: Path | str) -> Path:
    """Create ``path`` (and parents) if needed and return it as a Path."""
    path = Path(path)
    path.mkdir(parents=True, exist_ok=True)
    return path
