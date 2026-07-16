<img src="https://github.com/tscnlab/Templates/blob/main/logo/logo_with_text-01.png" width="400"/>

# Supplementary Material for Heinrichs & Spitschan, *Circadian timing does not modulate human temporal contrast sensitivity* (bioRxiv [10.1101/2025.11.10.687546](https://doi.org/10.1101/2025.11.10.687546))

## Description

This repository contains data, analysis code, and reporting scripts for Heinrichs & Spitschan (2025). The study used a 40-hour forced desynchrony protocol to test whether cone-mediated temporal contrast sensitivity is modulated by the circadian rhythm. Twelve participants completed psychophysical staircase tasks targeting L+M+S (luminance), L-M (red-green), and S-cone-directed (blue-yellow) stimulus directions at 2 Hz and 8 Hz. Circadian phase was indexed by salivary melatonin; Bayesian hierarchical cosinor models were used for inference.

## Full reference

If you use this code or data, please cite our article:

> Heinrichs, H.S., & Spitschan, M. (2025). Circadian timing does not modulate human temporal contrast sensitivity. *bioRxiv*. [https://doi.org/10.1101/2025.11.10.687546](https://doi.org/10.1101/2025.11.10.687546)

## Contact

For any questions or comments, get in touch via email to Manuel Spitschan ([manuel.spitschan@tum.de](mailto:manuel.spitschan@tum.de)).

## License

**Supplementary Material for Heinrichs & Spitschan, *Circadian timing does not modulate human temporal contrast sensitivity*** is released under the MIT License.

© 2026 Hannah Heinrichs and co-authors. See https://opensource.org/licenses/MIT for the full license text.

---

## Usage

> ## ▶ Reproducibility entry point
> **Start at [Step 2 — Statistical analysis (R)](#2-statistical-analysis-r).** The published results reproduce from the two cleaned CSVs already committed in this repository (`data/raw/clean_saliva_data.csv` and `data/raw/clean_metropsis_TCS-2e.csv`) — no network drive or raw data required:
>
> ```bash
> cd rscripts && Rscript r/main.R
> ```
>
> Step 1 (preprocessing) is included for transparency only. It regenerates those CSVs from raw saliva/Metropsis files on an internal network drive and is **not** part of the reproducible path — skip it. Steps 3–4 (diurnal control, visualisation) build on the outputs of Step 2.

The analysis pipeline runs in four steps: preprocessing (Python), statistical modelling (R), the diurnal control experiment (Python, post-hoc), and visualisation (Python + R). Generated files follow one rule: machine intermediates go to `data/derivatives/`, final outputs (figures, tables, `.tex` fragments) go to `results/`. See the folder structure below.

### Prerequisites

**1. Clone the repository and enter it:**

```bash
git clone <repository-url>
cd HeinrichsEtAl_JVis_2025
```

**2. Python** — Python >= 3.10. **Run this from the repository root** (the directory containing `environment.yaml` and `pyproject.toml`). Creating the environment installs the `pymetropsis` package via the `pip: -e .` entry in the file, and that `-e .` is a *relative* path — so `conda env create` will fail to find the package if run from any other directory. This creates an environment named `civibetcs` (the name is set inside the file) with `pymetropsis` installed in editable mode, so its modules are importable from the notebooks and scripts:

```bash
cd /path/to/civibe_psychophysics    # the repository root — required for the `-e .` install to resolve
conda env create -f environment.yaml   # creates the `civibetcs` environment
conda activate civibetcs
```

> To rebuild the environment from scratch, remove it first with `conda env remove -n civibetcs`.

**3. R** — R 4.4.3. The pipeline uses `brms` (with a working Stan/C++ toolchain via `rstan`), `bridgesampling` (for the Bayes factors), `lme4`, `dplyr`, `ggplot2`, `readr`, and `lubridate`, plus `rprojroot` for path resolution. Exact versions of every R package used for the published analysis are pinned in [`renv.lock`](renv.lock). To recreate that library:

```r
install.packages("renv")   # if not already installed
renv::restore(lockfile = "renv.lock")
```

`renv.lock` is a manifest only — restoring it installs the recorded package versions into your R library but does **not** alter how R resolves packages in this project (there is no `.Rprofile`/`renv/` autoloader). If you prefer, you can instead install the packages named above manually; `renv.lock` documents the versions to target.

### Computational environment

The published results were produced with the software below. Both the Python and R dependency sets are version-controlled (`environment.yaml`, `renv.lock`), so a matching environment can be recreated from this repository alone.

| Component | Version |
|---|---|
| OS (analysis machine) | macOS 26.5.2 (Apple Silicon, arm64) |
| Python | 3.10 |
| numpy / pandas / scipy | 1.24 / 2.2 / 1.14 |
| matplotlib | 3.7 |
| R | 4.4.3 |
| brms | 2.22.0 |
| rstan / StanHeaders | 2.32.7 / 2.32.10 |
| bridgesampling | 1.1-2 |
| lme4 | 1.1-37 |

Python dependencies are pinned to minor releases in `environment.yaml`; R dependencies are pinned exactly in `renv.lock` (126 packages, R 4.4.3).

**Reproducibility of the Bayesian models.** The `brms`/Stan fits are fully seeded and reproduce deterministically on a given toolchain. In `rscripts/r/fit_cosinor_metropsis_utils.R` each fit sets `set.seed(123)` and passes `seed = 123` to `brms::brm()`, run with **4 chains, 40 000 iterations (1 000 warmup), 4 cores**, and `save_pars(all = TRUE)` so the marginal likelihood can be estimated. Model comparison uses `bridgesampling` (via `brms::bayes_factor`). Because bridge sampling and MCMC are numerically sensitive to the exact Stan/C++ toolchain, Bayes factors may differ negligibly across platforms even with identical seeds; posterior summaries and all reported conclusions are stable.

> **Note — network drive.** Access to the internal network drive (`/Volumes/tscn-projects/civibe/`) is **only** needed to re-run the Step 1 preprocessing code from raw saliva/Metropsis files, which is not the formal starting point of the reproducibility pipeline (see note below) and is only accessible upon data publication. It is **not** required for Steps 2-4, which start from the cleaned CSVs already included in this repository.

### 1. Preprocessing (Python) — *not part of the reproducible path; skip unless regenerating from raw data*

Preprocessing reads raw saliva assay files and raw Metropsis psychophysics exports, cleans them, and writes two flat CSV files used by all downstream steps.

Activate the conda environment and run:

```bash
conda activate civibetcs
cd src/pymetropsis/preprocess
python main.py
```

This produces:
- `data/raw/clean_saliva_data.csv` -- t timestamped melatonin concentrations per participant
- `data/raw/clean_metropsis_TCS-2e.csv` - contrast threshold estimates per trial

> **Note:** `main.py` loads and merges the raw data with formatting differences. It is included for transparency but is **not** the formal starting point of the reproducibility pipeline: its raw inputs live on the internal network drive (`/Volumes/tscn-projects/civibe/`). These locations are marked with `# MANUAL ACTION REQUIRED` comments in `main.py`, `load_hormones.py`, and `clean_metropsis.py`.
>
> The formal starting point for reproducibility is the two already-generated flat files included in this repository: `data/raw/clean_saliva_data.csv` and `data/raw/clean_metropsis_TCS-2e.csv`. Start from Step 2 using these files.

### 2. Statistical analysis (R) — ▶ reproducibility entry point

All modelling is driven by a single entry-point script. From the `rscripts/` directory, run:

```bash
Rscript r/main.R
```

`main.R` runs three sequential stages:

**Stage 1 – Melatonin cosinor fitting**
Fits a bi-harmonic cosinor model (fundamental + 2nd harmonic) to each participant's salivary melatonin data via a grid search over τ ∈ [20, 28] h, selecting the best τ by AIC. Writes participant-specific circadian parameters to `data/derivatives/hormones/tau_harmonics/`.

**Stage 2 – Temporal contrast sensitivity (TCS) modelling**
Uses each participant's optimal τ to fit Bayesian hierarchical cosinor (full) and intercept-only (null) models to log-transformed TCS data, separately for each of the six condition × frequency combinations. Compares models with the Bayes Factor. Results are written to `data/derivatives/log_tcs/`.

Key model formulas (configured at the top of `main.R`):
```r
full_def = "log_tcs ~ 1 + cosine_component + sine_component + (1 + cosine_component + sine_component | participant_id)"
null_def = "log_tcs ~ 1 + (1 | participant_id)"
```

**Stage 3 – Tables and TeX reports**
Generates CSV summary tables and `.tex` fragments (result paragraphs, descriptive statistics, model summary tables) ready for inclusion in the manuscript. Output goes to `results/tables/log_tcs/` and `results/tex/log_tcs/`.

### 3. Diurnal control experiment (post-hoc)

A supplementary diurnal control was conducted with two participants (IDs 113 and 202). Raw pupil recordings from Pupil Core are processed with:

```bash
conda activate civibetcs
python src/pymetropsis/postcontrol/load_pupil.py
```

Summary tables and figures for the supplement are produced by `notebooks/diurnal_control.ipynb`.

### 4. Visualisations

Figures for the manuscript are generated partly in R (via `main.R` above, which calls `main_visualisation()`) and partly in Python notebooks. The Python notebooks call plotting functions defined in `src/pymetropsis/plotting/`.

From the repository root, open and run the relevant notebooks:

| Notebook | Content | Figures produced |
|---|---|---|
| `notebooks/descriptives.ipynb` | Descriptive plots of TCS time courses and group averages | `fig_psychophysics_test_timeseries_212-2.pdf`, `img_metropsis_blocks_group.pdf` |
| `notebooks/diurnal_control.ipynb` | Diurnal control experiment: TCS and pupil diameter | `fig_diurnal_control_cs_{pid}.pdf` |

The **melatonin overview figure** is produced by running its plotting script directly:

```bash
conda activate civibetcs
python src/pymetropsis/plotting/plot_hormone_overview.py
```

This writes `img_melatonin_overview_figure.pdf` to `results/figures/hormones/descriptives/`.

In addition, run the group-plotting script directly to produce the **individual per-participant timecourse panels**:

```bash
conda activate civibetcs
python src/pymetropsis/plotting/plot_metropsis_group.py
```

This writes four panel files that are later combined by hand (see below):

| Panel file | Location | Content |
|---|---|---|
| `img_metropsis_blocks_individual_a.svg` | `results/figures/tcs/` | Individual TCS timecourses, participant subgroup A |
| `img_metropsis_blocks_individual_b.svg` | `results/figures/tcs/` | Individual TCS timecourses, participant subgroup B |
| `img_melatonin_individual_c.svg` | `results/figures/hormones/` | Individual melatonin timecourses, subgroup C |
| `img_melatonin_individual_d.svg` | `results/figures/hormones/` | Individual melatonin timecourses, subgroup D |

The TCS and melatonin panels are then placed **side by side manually** to assemble the final figures `fig_individual_tcs_a_melatonin_c.pdf` (A + C) and `fig_individual_tcs_b_melatonin_d.pdf` (B + D). The script generates the individual panels; the side-by-side composition is a manual step.

The same script also produces the two **group-average panels**, which are likewise combined side by side by hand into a single figure:

| Panel file | Location | Content |
|---|---|---|
| `img_metropsis_blocks_group.svg` | `results/figures/tcs/` | Group-average TCS timecourse |
| `img_melatonin_average.svg` | `results/figures/hormones/` | Group-average melatonin timecourse |

Generated figures are written to `results/figures/` (grouped by analysis, e.g. `results/figures/tcs/`, `results/figures/hormones/`, `results/figures/eyetracking/`).

> **Note:** Several figures are not produced end-to-end by any current script or notebook. They fall into two categories:
> - **Composed from code-generated panels** (the panels come from `plot_metropsis_group.py`; only the side-by-side layout is manual): `fig_individual_tcs_melatonin.pdf` is assembled from the four individual-timecourse panels, and the combined group-average figure `fig_average_tcs_melatonin.pdf` is assembled from the melatonin and TCS group-average panels (see the panel tables above).
> - **Created entirely by hand** (no code panels): `fig_methods_summary.pdf` is drawn in BioRender.
>
> These hand-created and hand-composed figures are kept under version control in `reports/fig/graphics/`.

> **Note:** `notebooks/debug_phase_calculation.ipynb` is a check on the phase-calculation logic, not a source of published output. It renders individual melatonin timecourse plots inline (via `create_plot_individual_timecourse_melatonin`) against both empirical and simulated data, but does not save figures. It is not part of figure generation. 

---

## Folder structure

The project separates immutable inputs, machine intermediates, and final
outputs (e.g. figures, tables). Re-running the pipeline recreates output under `results/`.

Every script resolves these locations through `rscripts/r/paths.R` (R) and
`src/pymetropsis/paths.py` (Python). The Python module locates the project root
from its own file path, so Python scripts and notebooks can be run from any
working directory. The R entry point uses relative `source()` calls and resolves
the root relative to the working directory, so **R scripts must be run from the
`rscripts/` directory** (i.e. `cd rscripts && Rscript r/main.R`).
```
.
├── README.md
├── environment.yaml                  # Conda environment `civibetcs` (Python deps, pinned to minor versions)
├── renv.lock                         # Exact R package versions (restore with renv::restore())
├── pyproject.toml                    # `pymetropsis` package metadata (pip install -e .)
│
├── data/                             # Inputs and machine intermediates
│   ├── raw/                          # Immutable inputs; cleaned CSVs from preprocessing
│   │   ├── clean_saliva_data.csv     #   melatonin concentrations per participant
│   │   └── clean_metropsis_TCS-2e.csv#   contrast threshold estimates per trial
│   ├── derivatives/                  # Regenerable artifacts that feed *other* scripts
│   │   ├── hormones/tau_harmonics/   #   melatonin fits, participant-specific τ
│   │   ├── log_tcs/                  #   TCS model fits (Bayes factors, parameters)
│   │   └── eyetracking/              #   pupil summaries (diurnal control)
│   └── simulation/                   # Simulated input datasets
│
├── results/                          # FINAL outputs (regenerable) — see paths.R/paths.py
│   ├── figures/                      # All plots (.pdf/.svg/.png), grouped by analysis
│   │                                 #   figures/tcs/  figures/hormones/  figures/eyetracking/
│   ├── tables/                       # Final result tables (.csv)
│   ├── tex/                          # LaTeX fragments (tab_*.tex, vars_*.tex)
│   └── metadata/                     # Run settings / manifests
│
├── reports/                          # Git-ignored, except:
│   └── fig/graphics/                 #   hand-created / hand-composed figures (version-controlled)
│
├── notebooks/                        # Jupyter notebooks for visualisation (see Step 4)
│
├── rscripts/
│   └── r/                            # All R source files
│       ├── main.R                    # Entry point — runs the full R pipeline (Steps 2–3)
│       ├── paths.R                   # Canonical output locations (sourced by every R script)
│       ├── fit_cosinor_hormones.R    # Stage 1: melatonin τ estimation
│       ├── fit_cosinor_metropsis_wrapper.R  # Stage 2: TCS Bayesian models
│       ├── fit_cosinor_metropsis_utils.R    # Helper functions for TCS modelling
│       ├── report_tables_tcs.R       # Stage 3: table generation
│       ├── report_tex*.R             # Stage 3: TeX fragment generation
│       └── utils.R                   # Shared utilities (lists R package dependencies)
│
├── scripts/                          # Bash helper scripts (eyetracking extraction)
│
└── src/
    └── pymetropsis/
        ├── paths.py                  # Canonical output locations (imported by every module)
        ├── preprocess/               # Step 1: data cleaning (hormones + Metropsis)
        ├── plotting/                 # Python plotting functions (Step 4)
        ├── postcontrol/              # Diurnal control: pupil and TCS processing (Step 3)
        └── simulate/                 # Simulation utilities
```

---

## Known limitations

- `rscripts/r/fit_cosinor_tcs.R` and `rscripts/r/metropsis_analysis.R` are not called by `main.R` or any notebook. They are needed for the supplementary/appendix evaluation of the *unlogged* TCS, but reproducibility of that path has not yet been established against the current data.
- `rscripts/r/run_simulation_metropsis.R` is a standalone script predating the main analysis pipeline, kept to independently check/comprehend the modelling decisions. It is not run via `main.R` and still references an internal network path.
