# Canonical output locations for the civibe_psychophysics pipeline.
#
# Source this file and use the constants instead of hard-coding "../reports/..."
# so every script agrees on where things go. The rule (see STRUCTURE.md):
#
#   data/raw/          immutable inputs, never written by analysis
#   data/derivatives/  machine artifacts that feed *other* scripts
#                      (model fits, .nc, parameter CSVs, resampled data)
#   results/           everything a script generates as a *final* output
#                      (figures, result tables, .tex fragments, metadata)
#   reports/           ONLY hand-curated deliverables (manuscript snapshots,
#                      applications, talks). Never written by the pipeline.
#
# If deleting a folder and re-running the pipeline recreates it, it belongs in
# results/ (or data/derivatives/), never in reports/.
#
# Usage:
#   source("./r/paths.R")               # from rscripts/
#   out_dir <- ensure_dir(file.path(FIG_DIR, "log_tcs"))
#   ggsave(file.path(out_dir, "fig.png"), ...)

# Project root, resolved independently of the working directory.
#
# The RStudio project (rscripts/rmetropsis.Rproj) sets the working directory to
# rscripts/. Root is found by walking up to the .gitignore marker, so scripts resolve the same paths whether run from RStudio, `Rscript r/main.R` in rscripts/, or the repo root. The dir.exists() checks are only a fast path for when rprojroot is not installed.
.civibe_project_root <- function() {
  # 1) Preferred: walk up from the working directory to the repo marker.
  if (requireNamespace("rprojroot", quietly = TRUE)) {
    return(rprojroot::find_root(rprojroot::has_file(".gitignore")))
  }
  # 2) Fallback: run from rscripts/ (the usual case) -> root is the parent.
  if (dir.exists("../data") && dir.exists("../results")) {
    return(normalizePath("..", mustWork = FALSE))
  }
  # 3) Fallback: already at the repo root.
  if (dir.exists("data") && dir.exists("results")) {
    return(normalizePath(".", mustWork = FALSE))
  }
  stop("Could not locate project root; install rprojroot, or run from ",
       "rscripts/ or the repo root.")
}

PROJECT_ROOT <- .civibe_project_root()

# --- inputs & intermediate artifacts -------------------------------------
DATA_DIR        <- file.path(PROJECT_ROOT, "data")
RAW_DIR         <- file.path(DATA_DIR, "raw")
DERIVATIVES_DIR <- file.path(DATA_DIR, "derivatives")  # fits, params, .nc, ...

# --- final analysis outputs (regenerable) --------------------------------
RESULTS_DIR  <- file.path(PROJECT_ROOT, "results")
FIG_DIR      <- file.path(RESULTS_DIR, "figures")   # all plots
TABLE_DIR    <- file.path(RESULTS_DIR, "tables")    # final result tables (.csv)
TEX_DIR      <- file.path(RESULTS_DIR, "tex")       # generated tab_*/vars_* .tex
METADATA_DIR <- file.path(RESULTS_DIR, "metadata")  # settings.json, manifests

# --- hand-curated deliverables (never written by the pipeline) -----------
REPORTS_DIR <- file.path(PROJECT_ROOT, "reports")

#' Create a directory (recursively) if needed and return its path.
ensure_dir <- function(path) {
  if (!dir.exists(path)) dir.create(path, recursive = TRUE, showWarnings = FALSE)
  path
}

# Proactively create the output tree when this file is sourced, so
# scripts can write to these locations without each calling ensure_dir() first.
# Input dirs (RAW_DIR) and REPORTS_DIR are excluded: raw inputs must already exist, and reports/ is hand-curated and never written here.
for (.d in c(DERIVATIVES_DIR, RESULTS_DIR, FIG_DIR, TABLE_DIR, TEX_DIR,
             METADATA_DIR)) {
  ensure_dir(.d)
}
rm(.d)
