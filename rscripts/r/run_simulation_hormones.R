
# Simulate hormone data ---------------------------------------------------

# run python script
system("conda activate civibe")
system("python .././src/pymetropsis/simulate/simulate_hormones.py")

# Hormone analysis --------------------------------------------------------

# Canonical output locations. See ../STRUCTURE.md for the results/ vs reports/ rule.
source("./r/paths.R")

# Fit hormone data to fundamental only or model with harmonics
source("./r/fit_cosinor_hormones.R")

folder_spec = "hormones_24_fundamental"
model_results <- fit_cosinor_hormones_main(
  data_path = file.path(DATA_DIR, "simulation", folder_spec, "simulated_melatonin_data.csv"),
  harmonics = 1,
  out_data = file.path(DERIVATIVES_DIR, "simulation", folder_spec),
  out_figs = ensure_dir(file.path(FIG_DIR, "simulation", folder_spec))
)

folder_spec = "hormones_tau_fundamental"
model_results <- fit_cosinor_hormones_main(
  data_path = file.path(DATA_DIR, "simulation", folder_spec, "simulated_melatonin_data.csv"),
  harmonics = 1,
  out_data = file.path(DERIVATIVES_DIR, "simulation", folder_spec),
  out_figs = ensure_dir(file.path(FIG_DIR, "simulation", folder_spec))
)

folder_spec = "hormones_24_harmonics"
model_results <- fit_cosinor_hormones_main(
  data_path = file.path(DATA_DIR, "simulation", folder_spec, "simulated_melatonin_data.csv"),
  harmonics = c(1, 2),
  out_data = file.path(DERIVATIVES_DIR, "simulation", folder_spec),
  out_figs = ensure_dir(file.path(FIG_DIR, "simulation", folder_spec))
)

folder_spec = "hormones_tau_harmonics"
model_results <- fit_cosinor_hormones_main(
  data_path = file.path(DATA_DIR, "simulation", folder_spec, "simulated_melatonin_data.csv"),
  harmonics = c(1, 2),
  out_data = file.path(DERIVATIVES_DIR, "simulation", folder_spec),
  out_figs = ensure_dir(file.path(FIG_DIR, "simulation", folder_spec))
)

# Clear environment
rm(list = ls())
