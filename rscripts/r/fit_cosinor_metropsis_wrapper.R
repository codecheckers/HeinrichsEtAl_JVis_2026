#!/usr/bin/env Rscript

# ===============================================================
# Purpose:
#   Provide helper functions for circadian rhythm analysis and 
#   visualisation of psychophysical testing data from the visual system.
#
# Author:
#   Hannah Heinrichs
#
# Date:
#   2025-08-04
#
# Description:
#   This script is part of the core analysis pipeline for visual 
#   psychophysics and circadian modelling. It defines utility functions for:
#     - Creating harmonic sine and cosine components for modelling
#     - Calculating amplitude and phase from fitted sine-cosine terms on psychophysics data
#     - Identifying multilevel model formulas
#     - Loading and saving data outputs and plots with optional timestamps
#
#   These functions support data preparation, model interpretation, 
#   and visualisation workflows for psychophysical experiments and 
#   circadian analysis using tools like brms, ggplot2, and bayesplot.
#
# Usage:
#   source("utils_circadian.R")
#
# Example:
#   source("./analysis/src/r/utils_circadian.R")
#   df <- create_circadian_components(data, tau = 24)
#   amp <- calc_amplitude(a, b)
#   out_path <- save_output_dataframe("results/", df, "processed.csv")
#
# Dependencies:
#   ggplot2, dplyr, readr
# ===============================================================

# Imports -----------------------------------------------------------------

source("./r/paths.R")
source("./r/utils.R")
source("./r/fit_cosinor_metropsis_utils.R")

source("./r/plot_tcs.R")

# Functions ---------------------------------------------------------------

#' Main pipeline to evaluate lmm cosinor models on all conditions
#'
#' @param data_path String with the path to the input data file, e.g. "data/clean_fd_civibe_TCS-2e.csv"
#' @param tau_path String with the path to the tau harmonics file, e.g. "data/derivatives/hormones/tau_harmonics/melatonin_circadian_parameters.csv"
#' @param out_dir String with the output directory where to save the results, e.g. "data/derivatives/tcs/multilevel"
#' @param group_cols String vector with the names of the columns to group by, e.g. c("condition", "freq"). If `NA`, no grouping is applied.
#' @param full_def Model definition for the full model, e.g. "contrast_sensitivity ~ 1 + sine_component + cosine_component + (1 + sine_component + cosine_component | participant_id)"
#' @param null_def Model definition for the null model, e.g. "contrast_sensitivity ~ 1 + (1 | participant_id)"
#' @param save_plot Logical, whether to save the plots or not. If `TRUE`, plots are saved in the `out_dir` directory.
#' @param eval_subset Logical, whether to evaluate a subset of the data or not. If `TRUE`, only a subset of the data is used for evaluation. This is useful for debugging and testing purposes.
#'
#' @internal
#' @noRd
pipeline_fit_cosinor_tcs_lmm_main <- function(data_path = data_path,
                                              tau_path = tau_path,
                                              out_dir = out_dir,
                                              group_cols = NA,
                                              full_def = NA,
                                              null_def = NA,
                                              save_plot = TRUE,
                                              eval_subset = FALSE) {
  # Check arguments
  if (any(is.na(group_cols))) {
    stop("No grouping specified.")
  }
  if (is.na(full_def) | is.na(null_def)) {
    stop("No Model definition. Add full_def and null_def to arguments.")
  }
  if (any(stringr::str_detect(full_def, group_cols))) {
    warning("One of the grouping cols appears in the")
  }
  
  # Prepare data ----------------------------------------------------------
  df <-
    prepare_derivative_data(data_path = data_path, tau = tau_path)
  
  if (eval_subset) {
    # Select data by participant, condition, and frequency
    df <- df %>%
      dplyr::filter((.data$condition == "red-green") & (.data$freq == 2)) %>%
                     # (.data$condition == "red-green") %>%
      dplyr::filter(
        .data$participant_id == "113" |
          .data$participant_id == "202" |
          .data$participant_id == "204" |
          .data$participant_id == "205"
      )
  }
  
  out_path <- save_output_dataframe(
    out_dir = out_dir,
    out_df = df,
    filename = "input_data.csv",
    timestamp_prefix = FALSE
  )
  
  df <- df %>%
    dplyr::mutate(group = do.call(paste, c(dplyr::across(
      dplyr::all_of(group_cols)
    ), sep = "_"))) %>%
    dplyr::arrange(dplyr::across(dplyr::all_of(group_cols), ~ dplyr::desc(.)))
  input_df <- df
  

  # Evaluate model --------------------------------------
  model_results <-
    fit_models_on_groups(
      df = df,
      group_cols = group_cols,
      # multilevel - "contrast_sensitivity ~ 1 + sine_component + cosine_component + (1 + sine_component + cosine_component | participant_id)"
      # simple - "contrast_sensitivity ~ 1 + sine_component + cosine_component",
      full_def = full_def,
      # multilevel - "contrast_sensitivity ~ 1 + (1 | participant_id)"
      # simple - "contrast_sensitivity ~ 1"
      null_def = null_def
    )

  # Create summary CSV ------------------------------------------------------
  # from results and fit
  csv_model_summaries <- c()
  for (idx in seq_along(names(model_results))) {
    result <- model_results[[idx]]
    model_df <- model_summary_to_df(result = result)
    if (!is.null(out_dir)) {
      model_name <- result$group_name
      filename <- sprintf("model_summary__%s.csv", model_name)
      out_path <- save_output_dataframe(
        out_df = model_df,
        out_dir = out_dir,
        filename = filename,
        timestamp_prefix = FALSE
      )
      csv_model_summaries <- c(csv_model_summaries, out_path)
    }
  }
  
  fixef_df <-
    summarise_results_brms(results = model_results) %>%
    tidyr::separate_wider_delim(
      cols = group,
      names = group_cols,
      delim = "_",
      names_repair = "minimal",
      cols_remove = FALSE
    )
  
  out_path <- save_output_dataframe(
    out_dir = out_dir,
    out_df = fixef_df,
    filename = "fitted_fixed_parameters.csv",
    timestamp_prefix = FALSE
  )
  
  # Check if the fit is multi-level
  if (is_multilevel(formula(model_results[[1]]$full_fit))) {
    # Summarise random effects across cluster
    cluster_df <-
      summarise_results_lmm_brms(results = model_results) %>%
      dplyr::left_join(y = dplyr::distinct(input_df[, c("participant_id", "tau")]),
                       by = "participant_id")
    
    # Make LMM summary about fixef AND ranef
    params_df <-
      merge_fixed_and_cluster_summaries(cluster_df = cluster_df, fixef_df = fixef_df)
    
    out_df <- params_df %>%
      dplyr::select(dplyr::all_of(
        c(
          group_cols,
          "group",
          "intercept",
          "amplitude",
          "phase",
          "participant_id",
          "intercept_p",
          "re_intercept",
          "amplitude_p",
          "phase_p"
        )
      ), dplyr::everything())
    
    out_path <- save_output_dataframe(
      out_dir = out_dir,
      out_df = out_df,
      filename = "fitted_all_parameters.csv",
      timestamp_prefix = FALSE
    )
    
    out_string <- "Variable names:
* `intercept` - intercept of fixed effect, i.e. group-level
* `re_intercept` - intercept of random effect
* `intercept_p` - person-specific intercept, i.e. sum of group-leven and person-specific random effect"
    save_tex(out_string = out_string,
             out_path = gsub(".csv$", "_meta.md", out_path))
    
    # Create the nested list structure
    params <- param_df_to_list(params_df = params_df)
    
  } else {
    params_df <- fixed_df
  }
  
  # Extract predicted and observed data
  pred_df <-
    extract_timecourse_from_model_list(model_results = model_results)
  out_df <- pred_df %>%
    tidyr::separate_wider_delim(
      cols = group,
      names = group_cols,
      delim = "_",
      names_repair = "minimal",
      cols_remove = FALSE
    ) %>%
    dplyr::select(dplyr::all_of(group_cols), dplyr::everything())
  
  out_path <- save_output_dataframe(
    out_dir = out_dir,
    out_df = out_df,
    filename = "fitted_data.csv",
    timestamp_prefix = FALSE
  )
  return(model_results)
}

# Visualisations ----------------------------------------------------------

#' All important visualisations for the lmm cosinor models
#'
#' @param model_results Object of class `list` with model results, as returned by lmm pipeline
#' @param outcome_var String with the name of the outcome variable, e.g. "log_tcs" or "contrast_sensitivity"
#' @param out_dir String with the output directory where to save the plots. If `NULL`, no plots are saved.
#'
#' @returns
#' @export
#'
main_visualisation <-
  function(model_results,
           outcome_var = "log_tcs",
           out_dir = NULL, 
           fig_dir = NULL) {
    
    save_plot <- ifelse (!is.null(fig_dir), TRUE, FALSE)
    if (save_plot) {
      diagnostics_dir <-  
        ifelse(basename(fig_dir) == "diagnostics",
               fig_dir,
               file.path(fig_dir, "diagnostics"))
      dir.create(diagnostics_dir, recursive = TRUE)
    }
    
    
    if (!is_multilevel(formula(model_results[[1]]$full_fit))) {
      return(NULL)
    }
    
    
    fitted_data_path = file.path(results_dir, "fitted_all_parameters.csv")
    params_df <- 
      readr::read_csv(fitted_data_path,
                      show_col_types = FALSE)
    
    # Fitted sine wave for all models (combining all participants)
    plots_list <-
      lapply(names(model_results), function(model_name) {
        result <- model_results[[model_name]]
        plots <-
          lapply(unique(result$data$participant_id), function(pid) {
            # Get participant-wise sine parameters
            pid_params <-
              as.list(params_df[params_df$group == model_name &
                                  params_df$participant_id == pid, ])
            pid_data <- result$data[result$data$participant_id == pid,]
            # Create plot
            p <- create_scatter_sine_plot(
              df = pid_data,
              est_amplitude = pid_params$amplitude_p,
              est_phase = pid_params$phase_p,
              est_mesor = pid_params$intercept_p,
              tau = pid_params$tau,
              y_col = outcome_var,
              x_col = "hours_since_start"
            ) + labs(title = sprintf("Observed vs. predicted for '%s', %s",
                                     model_name, pid))
            return(p)
          })
        names(plots) <- unique(result$data$participant_id)

        # Save the plot as a PNG file
        if (save_plot) {
          combined_plot <- cowplot::plot_grid(plotlist = plots, ncol = 3)
          filename <-
            sprintf("fig_ppc-obs-fit_%s.png", gsub("_", "-", model_name))
          out_path <-
            save_figure(p = combined_plot,
                        out_dir = diagnostics_dir,
                        filename = filename,
                        w = 15, h = 12)
        }
        return(plots)
      })
    names(plots_list) <- names(model_results)
    
    # Diagnostic plots (fit, distribution, etc)
    plots_diagnostics <-
      lapply(names(model_results), function(model_name) {
        result <- model_results[[model_name]]
        diagnostics <- create_plot_model_diagnostics(
          fit = result$full_fit,
          plot_types = c("pp_check", "scatter"), #"trace", "pp_check", "hist", "dens", "scatter", 
          group = model_name,
          out_dir = NULL
        )
        return(diagnostics)
      })
    names(plots_diagnostics) <- names(model_results)
    
    if (save_plot) {
      # Reorganize to combine participants and save
      reorganized_plots <- list()
      plot_types <- unique(unlist(lapply(plots_diagnostics, names)))
      for(plot_type in plot_types) {
        reorganized_plots[[plot_type]] <- list()
        
        for(condition_name in names(plots_diagnostics)) {
          if(plot_type %in% names(plots_diagnostics[[condition_name]])) {
            reorganized_plots[[plot_type]][[condition_name]] <- 
              plots_diagnostics[[condition_name]][[plot_type]]
          }
        }
        plots_combined <- cowplot::plot_grid(
          plotlist = reorganized_plots[[plot_type]],
          labels = NULL,
          ncol = 2
        )
        filename <-
          sprintf("fig_diagnostic_%s_%s.png", gsub("_", "-", plot_type), gsub("_", "-", plot_type))
        out_path <-
          save_figure(p = plots_combined,
                      out_dir = diagnostics_dir,
                      filename = filename,
                      w = 10, h = 15)
      }
    }
    return(NULL)
  }
      
      # plots_circular <-
      #   lapply(names(model_results), function(group) {
      #     group_data <- params_df[params_df$group == group,]
      #     p <- create_polar_plot_condition(params_df = params_df)
      #
      #     if (save_plot) {
      #       filename <-
      #         sprintf("fig_ppc-circ__%s.png", gsub("_", "-", group))
      #       out_path <-
      #         save_figure(p = p,
      #                     out_dir = diagnostics_dir,
      #                     filename = filename)
      #     }
      #   })

# Script ------------------------------------------------------------------

# Run model
# model_results <- pipeline_fit_cosinor_tcs_lmm_main(
#   data_path = "./data/clean_fd_civibe_TCS-2e.csv",
#   tau_path =  "./data/derivatives/hormones/tau_harmonics/melatonin_circadian_parameters.csv",
#   out_dir = ifelse(
#     in_progress,
#     file.path(
#       "./data/derivatives/tcs/multilevel",
#       format(Sys.time(), "%Y%m%dT%H%M")
#     ),
#     "./data/derivatives/tcs/multilevel"
#   ),
#   group_cols = c("condition", "freq"),
#   full_def = "contrast_sensitivity ~ 1 + sine_component + cosine_component + (1 + sine_component + cosine_component | participant_id)",
#   null_def = "contrast_sensitivity ~ 1 + (1 | participant_id)"
# )
# main_visualisation(model_results = model_results, out_dir = "./data/derivatives/tcs/multilevel")


# model_results_1 <- main(
#   data_path = "/Volumes/tscn-projects/civibe/projects/civibe_psychophysics/data/tcs/tau_simulation/m10_a0_b0/simulated_tcs.csv",
#   tau_path = 24,
#   out_dir = "/Volumes/tscn-projects/civibe/projects/civibe_psychophysics/data/tcs/tau_simulation/m10_a0_b0",
#   group_cols = c("condition", "freq"),
#   full_def = "contrast_sensitivity ~ 1 + sine_component + cosine_component + (1 + sine_component + cosine_component | participant_id)",
#   null_def = "contrast_sensitivity ~ 1 + (1 | participant_id)"
# )



