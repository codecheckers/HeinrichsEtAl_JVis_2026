# #!/usr/bin/env Rscript

# ===============================================================
# Purpose:
#   Define modular plotting functions for visualising results from
#   Bayesian modelling and psychophysical testing of the visual system.
#
# Author:
#   Hannah Sophie Heinrichs
#
# Date:
#   2025-08-04
#
# Description:
#   This script provides reusable plotting functions for:
#     - Model diagnostics and posterior predictive checks (brms models)
#     - Observed vs. predicted scatter plots
#     - Sinusoidal fits of circadian patterns in psychophysical data
#     - Circular (polar) plots of phase and amplitude by condition
#
#   It is intended to be sourced from analysis scripts or R Markdown files
#   as part of the visualisation pipeline for circadian and sensory research.
#
# Usage:
#   source("plot_tcs.R")
#
# Example:
#   source("./analysis/src/r/plot_tcs.R")
#   create_plot_model_diagnostics(fit, plot_types = c("trace", "pp_check"))
#   create_scatter_sine_plot(df, est_amplitude, est_phase)
#
# Dependencies:
#   ggplot2, brms, bayesplot, dplyr, readr, (optionally: patchwork)
# ===============================================================

library(ggplot2)
library(brms)
library(bayesplot)


#' Function to create multiple diagnostic plots for a brms model on fit object
#'
#' @param fit Fit object from brms fit
#' @param plot_types Character vector specifying which plots to create.
#' @param group Character string specifying the group for which to create plots.
#' @param out_dir Character string specifying the output directory to save plots.
#'
#' @returns
#' @export
#'
create_plot_model_diagnostics <- function(fit,
                                          plot_types = c("trace", "hist", "dens", "scatter", "pp_check"),
                                          group = "",
                                          out_dir = NULL) {
  # Ensure the model is a valid brmsfit object
  if (!inherits(fit, "brmsfit")) {
    stop("Input must be a brmsfit object")
  }
  save_plot <- ifelse(!is.null(out_dir), TRUE, FALSE)
  
  # Create a list to store plots
  plots <- list()
  group_spec <-
    ifelse(group == "", group, sprintf(" for %s", group))
  
  # Trace plot
  if ("trace" %in% plot_types) {
    plots$trace <- bayesplot::mcmc_trace(fit) + theme_bw() +
      labs(title = paste0("Trace plot of MCMC chains", group_spec))
    if (save_plot) {
      save_figure(
        p = plots$trace,
        out_dir = out_dir,
        filename = sprintf("trace__%s.pdf", group)
      )
    }
  }
  
  # Histogram of posterior distributions
  if ("hist" %in% plot_types) {
    plots$histogram <- bayesplot::mcmc_hist(fit, bins = 30) + theme_bw() +
      labs(title = paste0("Histogram of posterior distributions", group_spec))
    if (save_plot) {
      out_path <- save_figure(
        p = plots$trace,
        out_dir = out_dir,
        filename = sprintf("hist__%s.pdf", group)
      )
    }
  }
  
  # Density plot of posterior distributions
  if ("dens" %in% plot_types) {
    plots$density <- bayesplot::mcmc_dens(fit) + theme_bw() +
      labs(title = paste0("Density plot of posterior distributions", group_spec))
    if (save_plot) {
      out_path <- save_figure(
        p = plots$density,
        out_dir = out_dir,
        filename = sprintf("dens__%s.pdf", group)
      )
    }
  }
  
  # Scatter plot of parameters
  if ("scatter" %in% plot_types) {
    plots$scatter <-
      bayesplot::mcmc_scatter(fit, pars = c("b_sine_component", "b_cosine_component")) + theme_bw() +
      labs(title = paste0("Scatter Plot of sine and cosine components", group_spec))
    if (save_plot) {
      out_path <- save_figure(
        p = plots$scatter,
        out_dir = out_dir,
        filename = sprintf("scatter__%s.pdf", group)
      )
    }
  }
  
  # Posterior predictive check
  if ("pp_check" %in% plot_types) {
    plots$pp_check1 <-
      bayesplot::pp_check(fit, type = "dens_overlay") + theme_bw() +
      labs(title = paste0("Posterior predictive check - Density plot", group_spec))
    if (save_plot) {
      out_path <- save_figure(
        p = plots$pp_check1,
        out_dir = out_dir,
        filename = sprintf("dens_overlay__%s.pdf", group)
      )
    }
    
    plots$pp_check2 <-
      pp_check(fit, type = "error_scatter_avg") + theme_bw() +
      labs(title = paste0(
        "Posterior predictive check - Error distribution",
        group_spec
      ))
    if (save_plot) {
      out_path <- save_figure(
        p = plots$pp_check2,
        out_dir = out_dir,
        filename = sprintf("error_scatter_avg__%s.pdf", group)
      )
    }
    
    plots$pp_check3 <-
      pp_check(fit, type = "scatter_avg") + theme_bw() +
      labs(title = paste0(
        "Posterior predictive check - Observed vs. predicted",
        group_spec
      ))
    if (save_plot) {
      out_path <- save_figure(
        p = plots$pp_check3,
        out_dir = out_dir,
        filename = sprintf("scatter_avg__%s.pdf", group)
      )
    }
  }
  
  return(plots)
}

#' Posterior predictive check - Observed vs. predicted
#'
#' @param fit Fit object from brms fit
#' @param include_fit Logical, whether to include a fitted line
#'
#' @returns
#' @export
#'
create_plot_scatter_fit_obs <- function(fit, include_fit = FALSE) {
  pred_df <- as.data.frame(fitted(fit)) %>%
    dplyr::mutate(fit$data) %>%
    dplyr::rename_with(~ "y_obs", .cols = 5) %>%
    dplyr::rename(
      y_pred = Estimate,
      y_err = Est.Error,
      lower_ci = Q2.5,
      upper_ci = Q97.5
    )
  p <-
    ggplot2::ggplot(pred_df, ggplot2::aes(y = y_obs, x = y_pred)) +
    # Scatter plot of points
    ggplot2::geom_point(
      color = "#3575A3",
      # Edge color (typically a darker shade)
      fill = "#83ABBF",
      # Fill color (lighter shade of the edge color)
      #alpha = 0.6,                # Transparency
      shape = 21,
      # Circular point with separate fill and edge
      size = 2.4,
      # Size of the point
      stroke = 0.5
    ) +
    # Add a perfect prediction line (y = x)
    ggplot2::geom_abline(
      slope = 1,
      intercept = 0,
      color = "black",
      linetype = "dashed"
    ) +
    # Bayesplot-inspired theme
    ggplot2::theme_bw(base_size = 12) +
    ggplot2::theme(
      panel.grid.major = ggplot2::element_line(color = "#DDDDDD", linewidth = 0.3),
      panel.grid.minor = ggplot2::element_line(color = "#EEEEEE", linewidth = 0.3)
    ) +
    # Add more minor grid lines
    ggplot2::scale_x_continuous(minor_breaks = waiver()) +
    ggplot2::scale_y_continuous(breaks = scales::extended_breaks(n = 7),
                                minor_breaks = waiver()) +
    # Labels
    ggplot2::labs(title = "Posterior predictive check - Observed vs. predicted",
                  x = "Predicted",
                  y = "Observed")
  if (include_fit) {
    # Add a fitted line
    p <- p + ggplot2::geom_smooth(
      method = "lm",
      color = "#30476B",
      #"#CC5C4C",
      fill = "#CDDDEA",
      se = TRUE,
      linetype = "solid"
    )
  }
  return(p)
}


#' Scatter plot with sine curve for circadain rhythm
#'
#' @param df Data frame containing the data to plot
#' @param est_amplitude Estimated amplitude of the sine wave
#' @param est_phase Estimated phase of the sine wave
#' @param est_mesor Estimated mesor (midline) of the sine wave
#' @param tau Estimated period of the sine wave (default is 24 hours)
#' @param y_col Name of the column in `df` containing the observed values (default is "y_obs")
#' @param x_col Name of the column in `df` containing the x-axis values (default is "x")
#'
#' @returns
#' @export
#'
create_scatter_sine_plot <- function(df,
                                     est_amplitude,
                                     est_phase,
                                     est_mesor = 0,
                                     tau = 24,
                                     y_col = "y_obs",
                                     x_col = "x") {
  # Check if columns are available
  required_columns <- c(y_col, x_col)
  missing <- required_columns[!(required_columns %in% colnames(df))]
  if (length(missing)) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }
  
  # Assuming y_pred and hours_since_start are in your data.frame
  p <-
    ggplot2::ggplot(df, ggplot2::aes(x = .data[[x_col]], y = .data[[y_col]])) +
    # Your data points
    ggplot2::geom_point(
      color = "#2C69B0",
      #aes(color = "Observed data"),
      # Edge color
      fill = "#6397C3",
      # Fill color
      # alpha = 0.6,        # Transparency
      shape = 21,
      # Filled circle
      size = 2,
      # Point size
      stroke = 0.5          # Edge width
    ) +
    # Cosine curve
    ggplot2::stat_function(
      # fun = function(x)
      #   est_mesor + est_amplitude * cos((2 * pi * x / tau) + est_phase),
      fun = function(x)
        est_mesor + est_amplitude * cos((2 * pi * x / tau) + est_phase),
      color = "#30476B",
      linetype = "dashed"
    ) +
    # Bayesplot-inspired theme
    ggplot2::theme_bw(base_size = 12) +
    ggplot2::theme(
      panel.grid.major = ggplot2::element_line(color = "#DDDDDD", linewidth = 0.3),
      panel.grid.minor = ggplot2::element_line(color = "#EEEEEE", linewidth = 0.3)
    ) +
    # Legend with costum colours
    # ggplot2::scale_color_manual(
    #   name = "Legend",  # Legend title
    #   values = c("Data Points" = "#2C69B0", "Fitted Curve" = "#30476B")
    # ) +
    # Labels
    ggplot2::labs(title = "Observed data with fitted line",
                  x = "Hours since start",
                  y = "Observed")
  return(p)
}

#' Circular rhythmicity of groups
#'
#' @description
#' Adapted from https://github.com/thomazbastiaanssen/kronos
#'
#' @param params_df_path (from "./data/derivatives/tcs/multilevel/fitted_tcs_all_parameters.csv")
#' 
create_polar_plot_condition <- function(params_df_path) {
  params_df <- readr::read_csv(params_df_path, show_col_types = FALSE)
  df_plot <- params_df %>%
    # Create a new column for the angle (in radians)
    dplyr::mutate(hours_p = (.data$phase_p + pi) * (24 / (2 * pi)),
                  angle_p = ((.data$phase_p * 180 / pi) %% 360),
    )
  
  # Establish group definition in variables
  condition <- unique(df_plot$condition)
  freq <- unique(df_plot$freq)
  
  p <- ggplot2::ggplot(df_plot) +
    # Add lines from center to points
    ggplot2::geom_segment(aes(
      x = angle_p,
      y = 0,
      xend = angle_p,
      yend = amplitude_p
    )) +
    # Add points
    ggplot2::geom_point(
      shape = 21,
      size = 3,
      aes(
        x = angle_p,
        y = amplitude_p,
        fill = as.factor(participant_id)
      )
    ) +
    # Customize the appearance
    ggplot2::scale_x_continuous(
      breaks = seq(0, 360, by = 60),
      limits = c(0, 360),
      labels = seq(0, 24, by = 4)
    ) +
    # Convert to polar coordinates
    ggplot2::coord_polar() +
    ggplot2::facet_grid(
      condition ~  freq,#group,
      scales = "free",
      switch = "y",
      labeller = labeller(
        condition = c("achromatic"="L+M+S\n(luminance)",
                      "red-green"="L-M\n(red-green)",
                      "blue-yellow"="S\n(blue-yellow)"),
        freq = c("2" = "2 Hz", "8" = "8 Hz")
      ))
      
  # Customize theme
  p <- p +
    ggplot2::theme_bw() + 
    ggplot2::theme(
      # face not bold
      plot.title = ggplot2::element_text(face = "plain", color = "black"),#, hjust = 0),
      plot.title.position = 'plot',
      #axis.text = ggplot2::element_text("Phase shift in hours", colour = "black"),
      axis.text.x = ggplot2::element_text(colour = "black"),
      # Move x-axis labels outward using margin
      # Adds 10 units of margin to the top
      axis.line.y = ggplot2::element_line(color = "black"),
      axis.text.y = ggplot2::element_text(color = "black"),
      # axis.title.y = ggplot2::element_text(size = 14),
      # legend.title = ggplot2::element_text(size = 14),
      # panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(colour = "darkgray"),
      panel.border = ggplot2::element_blank(),
      strip.background.x = ggplot2::element_rect(fill = "white", color = "black"),
      strip.background.y = ggplot2::element_rect(fill = "white", color = "black"),
      legend.position = "right"
    ) +
    ggplot2::labs(
      x = "Phase angle in hours",
      y = "Circadian amplitude",# ifelse(freq == 2, "Circadian amplitude", ""),
      # Only show y-axis label for leftmost plots
      fill = "Participants",
      #title = 
      # We'll add titles using text_grob ladfter
    ) +
    ggplot2::guides(
      # Only show legend for rightmost plot
      fill = ggplot2::guide_legend(title = "Participants"), #ncol = 2
      colour = ggplot2::guide_none(),
      linetype = ggplot2::guide_none()
    ) +
    ggplot2::ggtitle("Amplitude and phase of variations in log temporal contrast sensitivity")
  return(p)
}

