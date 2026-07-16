

# Imports -----------------------------------------------------------------

source("./r/utils_simulation_metropsis.R")

# Libraries ---------------------------------------------------------------

library(dplyr)
library(tidyr)
library(ggplot2)

# Directories -------------------------------------------------------------

# Output directory
# root_dir <- "/Volumes/tscn-projects/civibe/projects"
# project_subfolder <- "civibe_psychphysics"
# subfolder <- "tcs_simulation"
# 
# project_dir <- file.path(root_dir, project_subfolder)
# modality_dir <- file.path(project_dir, subfolder)
# timestamp <- format(Sys.time(), "%Y%m%dT%H%M")
# out_dir <- file.path(project_dir, "simulation", timestamp)

# Settings for script -----------------------------------------------------

in_progress = TRUE

# Directories -------------------------------------------------------------

# Output directory
root_dir <- "/Volumes/tscn-projects/civibe/projects"
project <- "civibe_psychophysics"
data_folder <- "data"
modality <- "tcs"
subfolder <- "tau_simulation"
in_progress_folder <- "m10_a3_b2"#format(Sys.time(), "%Y%m%dT%H%M")

project_dir <- file.path(root_dir, project, data_folder)
modality_dir <- file.path(project_dir, modality)
out_dir = ifelse(
  in_progress,
  file.path(modality_dir, subfolder, in_progress_folder),
  file.path(modality_dir, subfolder)
)

# Create output directory
if (!dir.exists(out_dir)) {
  dir.create(out_dir, recursive = TRUE)
}


# Data simulation ---------------------------------------------------------

df <- simulate_circadian_pychophysics(
  num_participants = 11,
  conditions = c("achromatic", "red-green", "blue-yellow"),
  freqs = c(2, 8),
  mesor = 10,
  sine_weight = 3,
  cosine_weight = 2,
  tau = 24,
  seed = 751,
  is_random = FALSE
) 


# df <- df %>%
#   dplyr::filter(
#     (.data$condition == "red-green" | .data$condition == "achromatic") &
#       (.data$freq == 2) &
#       (.data$participant_id == unique(df$participant_id[1]))
#   )

# Save data
out_path = save_output_dataframe(
  out_dir = out_dir,
  out_df = df,
  filename = "simulated_tcs.csv",
  timestamp_prefix = FALSE
)

# # Data fitting ------------------------------------------------------------
# 
# # Evaluate and fit model
# group_cols = c("participant_id", "condition", "freq")
# df <- df %>%
#   #dplyr::mutate(across(all_of(group_cols), as.character)) %>%
#   dplyr::mutate(group = do.call(paste, c(dplyr::across(
#     dplyr::all_of(group_cols)
#   ), sep = "_"))) %>%
#   dplyr::arrange(dplyr::across(dplyr::all_of(group_cols), ~ desc(.)))
# 
# model_results <-
#   fit_models_on_groups(df = df, group_cols = group_cols)
# 
# # Create summary overview over results and fit
# params_df <- summarize_results_brms(results = model_results)
# out_df <- params_df %>%
#   tidyr::separate(.data$group,
#                   into = group_cols,
#                   sep = "_") %>%
#   dplyr::select(dplyr::all_of(group_cols), everything())
# 
# # Save data
# out_path = save_output_dataframe(
#   out_dir = out_dir,
#   out_df = out_df,
#   filename = "fitted_tcs_parameters.csv",
#   timestamp_prefix = FALSE
# )
# 
# # Extract predicted and observed data
# pred_df <- extract_timecourse_from_model_list(models_results)
# out_df <- pred_df %>%
#   tidyr::separate(.data$group, into = group_cols, sep = "_") %>%
#   dplyr::select(dplyr::all_of(group_cols), everything())
# 
# out_path <- save_output_dataframe(
#   out_dir = out_dir,
#   out_df = out_df,
#   filename = "fitted_tcs_data.csv",
#   timestamp_prefix = FALSE
# )
# 
# # Visualisations ----------------------------------------------------------
# 
# save_plot = TRUE
# 
# # group_name <- model_results[[1]]$group_name
# # result <- model_results[[1]]
# # fit <- result$full_fit
# # pred <- pred_df[pred_df$group == group_name, ]
# 
# #plot_scatter_fit_obs(fit)
# #plots$pp_check <- pp_check(fit, type = "scatter_avg")
# 
# plot_observed <- lapply(unique(pred_df$group), function(group_name) {
#   # Plot against time, including sine with parameter
#   result <- model_results[[group_name]]
#   p <- plot_scatter_sine_obs(
#     df = pred_df[pred_df$group == group_name, ],
#     y_col = "y_obs",
#     est_amplitude = result$parameters$amplitude,
#     est_phase = result$parameters$phase,
#     est_mesor = result$parameters$intercept
#   )
#   p + labs(title = sprintf(
#     "Posterior predictive check - Observed vs. predicted for '%s'",
#     group_name
#   ))
#   
#   # Save the plot as a PNG file
#   if (save_plot) {
#     filename <-
#       sprintf("fig_ppc-obs-fit_%s.png", gsub("_", "-", group_name))
#     ggplot2::ggsave(
#       filename = file.path(out_dir, filename),
#       plot = p,
#       width = 6,
#       height = 4,
#       dpi = 300
#     )
#   }
#   return(p)
# })
# names(plot_observed) <- unique(pred_df$group)
# 
# plots_diagnostics <- lapply(model_results, function(result) {
#   diagnostics <-
#     plot_model_diagnostics(fit = result$full_fit, group = result$group_name)
# })
# names(plots_diagnostics) <- model_results
