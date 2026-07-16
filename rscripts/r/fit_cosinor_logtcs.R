# =============================================================================
# DEPRECATED — not part of the reproducible pipeline.
#
# This standalone script predates the current log-TCS workflow, which now lives
# inline in r/main.R (sourced/driven from there). It is not sourced or called by
# main.R or any notebook, and its hard-coded paths (e.g. "./fig/...",
# "./reports/.../tex") predate the paths.R scheme (figures -> results/figures,
# generated tex -> results/tex). Running it will NOT reproduce manuscript output
# and may write to stale locations.
#
# Kept only as a reference for the earlier standalone fit. To reproduce results,
# run r/main.R. See ../STRUCTURE.md and README.md ("Known limitations").
# =============================================================================

# Load hormones and clean with python


# Hormone analysis --------------------------------------------------------

# Fit hormone data to fundamental only or model with harmonics
source("./r/fit_cosinor_hormones.R")

model_results <- fit_cosinor_hormones_main(
  data_path = "./data/raw/clean_saliva_data.csv",
  harmonics = c(1, 2),
  out_data = "./data/derivatives/hormones/tau_harmonics",
  out_figs = "./fig/hormones/tau_harmonics"
)

# Clear environment
rm(list = ls())
gc()


# tCS analysis ------------------------------------------------------------

source("./r/fit_cosinor_metropsis_wrapper.R")
in_progress <- FALSE

# Input directory and file
data_path <- "./data/raw/clean_metropsis_TCS-2e.csv"
tau_path <-
  "./data/derivatives/hormones/tau_harmonics/melatonin_circadian_parameters.csv"

# Output directory
outcome_variable = "log_tcs" # "tcs" / "contrast_sensitivity"
results_dir = "./data/derivatives/log_tcs/multilevel"
dir.create(results_dir, recursive = TRUE)

# Define model specs
full_def = "log_tcs ~ 1 + sine_component + cosine_component + (1 + sine_component + cosine_component | participant_id)"
null_def = "log_tcs ~ 1 + (1 | participant_id)"

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


# Visualisations ----------------------------------------------------------

fig_dir = "./fig/log_tcs/multilevel"
dir.create(fig_dir, recursive = TRUE)

# Plotting functions
main_visualisation(
  model_results = model_results,
  outcome_var = "log_tcs",
  out_dir = results_dir,
  fig_dir = fig_dir
)

# Clear environment
rm(list = ls())
gc()



# Tables ------------------------------------------------------------------

source("./analysis/src/r/report_tables_tcs.R")
reports_dir <- "./reports/log_tcs/multilevel"
results_dir = "./data/derivatives/log_tcs/multilevel"

# Output directors
tbl_dir <- file.path(reports_dir, "tables")
dir.create(tbl_dir, recursive = TRUE)
tex_dir <- file.path(reports_dir, "tex")
dir.create(tex_dir, recursive = TRUE)

cat("Processing results from:", results_dir)

# Generate hormone output
tau_path <-
  "./data/derivatives/hormones/tau_harmonics/melatonin_circadian_parameters.csv"
out_tex <- report_tables_tcs_main(tau_path=tau_path, metropsis_result_dir=results_dir, tbl_dir=tbl_dir, tex_dir=tex_dir)

# Tex reports -------------------------------------------------------------

data_path <-
  file.path(results_dir, "fitted_fixed_parameters.csv")
fitdf <- readr::read_csv(data_path)

# Sentences
res_smry1 <- sprintf(
  "In summary, the obtained Bayes factors for all models were very small, ranging from \\ac{logbf} values of $%s$ to $%s$.",
  (round(min(fitdf$log_bf), 2)),
  (round(max(fitdf$log_bf), 2))
) %>% cat()


source("./analysis/src/r/report_tex.R")
# log TCS
tex_descriptive_melatonin <-
  create_tex_descriptive_melatonin(data_path = "./data/raw/clean_saliva_data.csv",
                                   tex_dir = "./reports/log_tcs/multilevel/tex")
tex_inference_melatonin <-
  create_tex_inference_melatonin(parameter_path = "./data/derivatives/hormones/tau_harmonics/melatonin_circadian_parameters.csv",
                                 input_path = "./data/raw/clean_saliva_data.csv",
                                 tex_dir = "./reports/log_tcs/multilevel/tex")
tex_descriptive_tcs <-
  create_tex_descriptive_tcs(data_path = "./data/derivatives/log_tcs/multilevel/input_data.csv",
                             tex_dir = "./reports/log_tcs/multilevel/tex")
tex_inference_tcs <-
  create_tex_inference_tcs(data_dir = "./data/derivatives/log_tcs/multilevel",
                           tex_dir = "./data/reports/log_tcs/multilevel/tex")