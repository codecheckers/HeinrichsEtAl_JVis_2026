#!/usr/bin/env Rscript

# Description:
# This script processes an outcome variable passed from the command line.
# Usage:
#   Rscript analyse_metropsis.R <outcome>
# Arguments:
#   outcome: A character string specifying the outcome to process (e.g. "sleep_quality")
# 
# # Get command line arguments
# args <- commandArgs(trailingOnly = TRUE)
# 
# # Define a help message
# help_message <- "
# Description:
#   This script processes an outcome variable passed from the command line.
# 
# Usage:
#   Rscript my_script.R <outcome>
# 
# Arguments:
#   outcome    A character string specifying the outcome to process (e.g., 'sleep_quality')
# "
# 
# # Show help message if no args or if '--help' is requested
# if (length(args) < 1 || args[1] %in% c("--help", "-h")) {
#   cat(help_message)
#   quit(status = 0)
# }
# 
# # Assign the first argument to 'outcome'
# outcome <- args[1]
# 
# # Example: use the outcome variable
# cat("You provided the outcome:", outcome, "\n")
# 
# print_help("sf")


# Constants ---------------------------------------------------------------

# Canonical output locations (FIG_DIR, DERIVATIVES_DIR, ...). Also sets DATA_DIR.
# See ../STRUCTURE.md for the results/ vs reports/ rule.
source("./r/paths.R")

# You can now use 'outcome' in your script as needed
outcome_variable = "tcs" # "tcs" / "contrast_sensitivity"

# Hormone analysis --------------------------------------------------------

# Fit hormone data to fundamental only or model with harmonics
source("./r/fit_cosinor_hormones.R")

model_results <- fit_cosinor_hormones_main(
  data_path = file.path(DATA_DIR, "raw/clean_saliva_data.csv"),
  harmonics = c(1, 2),
  out_data = file.path(DERIVATIVES_DIR, "hormones/tau_harmonics"),
  out_figs = ensure_dir(file.path(FIG_DIR, "hormones/tau_harmonics"))
)

rm(model_results)


# tCS analysis ------------------------------------------------------------

source("./r/fit_cosinor_metropsis_wrapper.R")

in_progress <- FALSE

# Input directory and file
data_path <- file.path(DATA_DIR, "raw/clean_metropsis_TCS-2e.csv")
tau_path <- file.path(
  DATA_DIR,
  "derivatives/hormones/tau_harmonics/melatonin_circadian_parameters.csv")

# Output directory
results_dir = file.path(DATA_DIR, "derivatives", outcome_variable)
dir.create(results_dir, recursive = TRUE)

# Define model specs
full_def = paste(outcome_variable, "1 + sine_component + cosine_component + (1 + sine_component + cosine_component | participant_id)", sep = " ~ ")
null_def = paste(outcome_variable, "1 + (1 | participant_id)", sep = " ~ ")

# Run model
model_results <- pipeline_fit_cosinor_tcs_lmm_main(
  data_path = data_path,
  tau_path = tau_path,
  out_dir = results_dir,
  group_cols = c("condition", "freq"),
  full_def = full_def,
  null_def = null_def,
  eval_subset = FALSE
)

# Create visualisations ---------------------------------------------------

fig_dir = ensure_dir(file.path(FIG_DIR, outcome_variable))

# Plotting functions
main_visualisation(
  model_results = model_results,
  outcome_var = outcome_variable,
  out_dir = results_dir,
  fig_dir = fig_dir
)

rm(model_results)

# # Clear environment
# rm(list = ls())
# gc()


# Report tables -----------------------------------------------------------

source("./r/report_tables_tcs.R")

results_dir <- file.path(DERIVATIVES_DIR, outcome_variable)

# Output directories (generated tables + tex fragments -> results/)
tbl_dir <- ensure_dir(file.path(TABLE_DIR, outcome_variable))
tex_dir <- ensure_dir(file.path(TEX_DIR, outcome_variable))

cat("Processing results from:", results_dir)


# Generate hormone output
tau_path <- file.path(
  DATA_DIR,
  "derivatives/hormones/tau_harmonics/melatonin_circadian_parameters.csv"
)
out_tex <- report_tables_tcs_main(tau_path = tau_path, metropsis_result_dir = results_dir, 
  tbl_dir = tbl_dir,
  tex_dir = tex_dir
)

# Tex reports -------------------------------------------------------------

source("./r/report_tex.R")

# tex_dir reused from the Report tables section above (results/tex/<outcome>)

tex_descriptive_melatonin <-
  create_tex_descriptive_melatonin(
    data_path = file.path(DATA_DIR, "raw/clean_saliva_data.csv"),
    tex_dir = tex_dir
    )

tex_inference_melatonin <-
  create_tex_inference_melatonin(
    parameter_path = file.path(
      DATA_DIR,
      "derivatives/hormones/tau_harmonics/melatonin_circadian_parameters.csv"
    ),
    raw_path = file.path(DATA_DIR, "raw/clean_saliva_data.csv"),
    tex_dir = tex_dir
  )

tex_descriptive_tcs <-
  create_tex_descriptive_tcs(
    data_path = file.path(
      DERIVATIVES_DIR,
      outcome_variable,
      "input_data.csv"
    ),
    tex_dir = tex_dir
  )

tex_inference_tcs <-
  create_tex_inference_tcs(
    data_dir = file.path(DERIVATIVES_DIR, outcome_variable),
    tex_dir = tex_dir
  )

tex_methods_sample <-
  create_tex_methods_sample(
    labscreen_path = file.path(RAW_DIR, "Civibelabscreening_DATA_2025-08-11_1409.csv"),
    metropsis_path = file.path(RAW_DIR, "clean_metropsis_TCS-2e.csv"),
    tex_dir = tex_dir
  )

