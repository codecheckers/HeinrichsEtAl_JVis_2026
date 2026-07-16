# =============================================================================
# Descriptive Statistics for circadian marker and LaTeX Report Generator
#
# This script processes cleaned melatonin saliva concentration data
# to compute descriptive statistics and participant-specific summaries.
# It then generates a LaTeX-formatted report section with these statistics
# for use in scientific documents.
#
# Main functions:
# - roundsci(x): Formats numeric values, converting small values to scientific notation.
# - roundless(x): Rounds numbers and replaces values below 0.01 with "<0.01".
# - create_tex_descriptive_melatonin(data_path, tex_dir):
#     Reads melatonin data CSV, calculates descriptive statistics, and
#     generates a LaTeX report saved to the specified directory.
#
# Inputs:
# - data_path: Path to the CSV file containing melatonin data.
# - tex_dir: Directory where the LaTeX report will be saved.
#
# Outputs:
# - Saves a LaTeX (.tex) file with descriptive statistics and summaries.
#
# Requirements:
# - R packages: dplyr, readr, glue
#
# Usage example:
# create_tex_descriptive_melatonin(
#   data_path = file.path(RAW_DIR, "clean_saliva_data.csv"),
#   tex_dir = file.path(TEX_DIR, "log_tcs/multilevel")
# )
#
# =============================================================================

# Canonical paths (RAW_DIR, DERIVATIVES_DIR, TEX_DIR, ...). See ../STRUCTURE.md.
source("./r/paths.R")
source("./r/utils.R")
source("./r/report_tex_methods.R")
source("./r/report_tex_melatonin.R")
source("./r/report_tex_logtcs.R")



main_report_tex <- function() {
  # demographics
  tex_dir <- file.path(TEX_DIR, "log_tcs/multilevel")
  logtcs_dir <- file.path(DERIVATIVES_DIR, "log_tcs/multilevel")
  tex_methods_sample <- create_tex_methods_sample(
    labscreen_path = file.path(RAW_DIR, "Civibelabscreening_DATA_2025-08-11_1409.csv"),
    metropsis_path = file.path(RAW_DIR, "clean_metropsis_TCS-2e.csv"),
    tex_dir = tex_dir
  )

  # log TCS
  tex_descriptive_melatonin <-
    create_tex_descriptive_melatonin(data_path = file.path(RAW_DIR, "clean_saliva_data.csv"), tex_dir = tex_dir)
  tex_inference_melatonin <-
    create_tex_inference_melatonin(parameter_path = file.path(DERIVATIVES_DIR, "hormones/tau_harmonics/melatonin_circadian_parameters.csv"),
                                   raw_path = file.path(RAW_DIR, "clean_saliva_data.csv"),
                                   tex_dir = tex_dir)
  tex_descriptive_tcs <-
    create_tex_descriptive_tcs(data_path = file.path(logtcs_dir, "input_data.csv"), tex_dir = tex_dir)
  tex_inference_tcs <-
    create_tex_inference_tcs(data_dir = logtcs_dir, tex_dir = tex_dir)
}


#main_report_tex()

