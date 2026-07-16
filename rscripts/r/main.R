# Load hormones and clean with python

# Canonical output locations (FIG_DIR, TABLE_DIR, TEX_DIR, DERIVATIVES_DIR, ...).
# See ../STRUCTURE.md for the results/ vs reports/ rule.
source("./r/paths.R")

# Hormone analysis --------------------------------------------------------

# Fit hormone data to fundamental only or model with harmonics
source("./r/fit_cosinor_hormones.R")

model_results <- fit_cosinor_hormones_main(
  data_path = file.path(RAW_DIR, "clean_saliva_data.csv"),
  harmonics = c(1, 2),
  out_data = file.path(DERIVATIVES_DIR, "hormones/tau_harmonics"),
  out_figs = ensure_dir(file.path(FIG_DIR, "hormones/tau_harmonics"))
)

# Clear environment
rm(list = ls())
gc()



# tCS analysis ------------------------------------------------------------

source("./r/fit_cosinor_metropsis_wrapper.R")
in_progress <- FALSE

# Input directory and file (paths resolved via paths.R, sourced above)
data_path <- file.path(RAW_DIR, "clean_metropsis_TCS-2e.csv")
tau_path <- file.path(DERIVATIVES_DIR, "hormones/tau_harmonics/melatonin_circadian_parameters.csv")

# Output directory
outcome_variable = "log_tcs" # "tcs" / "contrast_sensitivity"
results_dir = ensure_dir(file.path(DERIVATIVES_DIR, "log_tcs"))

# Define model specs
full_def = "log_tcs ~ 1 + cosine_component + sine_component + (1 + cosine_component + sine_component | participant_id)"
null_def = "log_tcs ~ 1 + (1 | participant_id)"

# Run model
model_results <- pipeline_fit_cosinor_tcs_lmm_main(
  data_path = data_path,
  tau_path = tau_path,
  out_dir = results_dir,
  group_cols = c("condition", "freq"),
  full_def = full_def,
  null_def = null_def,
  # FALSE fits all 6 condition x frequency combinations; TRUE (debugging only) fits a single combination
  eval_subset = FALSE
)

# Create visualisations ---------------------------------------------------

fig_dir <- ensure_dir(file.path(FIG_DIR, "log_tcs"))

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


# Report tables -----------------------------------------------------------
source("./r/report_tables_tcs.R")


outcome_variable = "log_tcs"
results_dir = file.path(DERIVATIVES_DIR, "log_tcs")
tau_path <-
  file.path(DERIVATIVES_DIR, "hormones/tau_harmonics/melatonin_circadian_parameters.csv")

# Output directories (generated tables + tex fragments -> results/)
tbl_dir <- ensure_dir(file.path(TABLE_DIR, outcome_variable))
tex_dir <- ensure_dir(file.path(TEX_DIR, outcome_variable))

cat("Processing results from:", results_dir)

# Generate hormone output
out_tex <- report_tables_tcs_main(tau_path=tau_path, metropsis_result_dir=results_dir, tbl_dir=tbl_dir, tex_dir=tex_dir)

# Tex reports -------------------------------------------------------------

data_path <-
  file.path(results_dir, "fitted_fixed_parameters.csv")
fitdf <- readr::read_csv(data_path, show_col_types = FALSE)

# Sentences
res_smry1 <- sprintf(
  "In summary, the obtained Bayes factors for all models were very small, ranging from \\ac{logbf} values of $%s$ to $%s$.",
  (round(min(fitdf$log_bf), 2)),
  (round(max(fitdf$log_bf), 2))
) %>% cat()


source("./r/report_tex.R") # log TCS
tex_descriptive_melatonin <-
  create_tex_descriptive_melatonin(data_path = file.path(RAW_DIR, "clean_saliva_data.csv"),
                                   tex_dir = tex_dir)
tex_inference_melatonin <-
  create_tex_inference_melatonin(parameter_path = file.path(DERIVATIVES_DIR, "hormones/tau_harmonics/melatonin_circadian_parameters.csv"),
                                 raw_path = file.path(RAW_DIR, "clean_saliva_data.csv"),
                                 tex_dir = tex_dir)
tex_descriptive_tcs <-
  create_tex_descriptive_tcs(data_path = file.path(results_dir, "input_data.csv"),
                             tex_dir = tex_dir)
tex_inference_tcs <-
  create_tex_inference_tcs(data_dir = results_dir,
                           tex_dir = tex_dir)

tex_methods_sample <-
  create_tex_methods_sample(
    labscreen_path = file.path(RAW_DIR, "Civibelabscreening_DATA_2025-08-11_1409.csv"),
    metropsis_path = file.path(RAW_DIR, "clean_metropsis_TCS-2e.csv"),
    tex_dir = ensure_dir(TEX_DIR)
  )


# data_path <- file.path(results_dir, "input_data.csv")
# df <- readr::read_csv(data_path)
# 
# data_path <- "./data/raw/clean_saliva_data.csv"
# in_cols <- c("participant_id", "sample_number", "melatonin_concentration", "hours_after_wakeup", "standard_clocktime", "standard_datetime")
# meldf <- readr::read_csv(data_path) %>% 
#   as.data.frame %>% 
#   dplyr::filter(participant_id != 200) %>% 
#   dplyr::select(dplyr::all_of(in_cols))
