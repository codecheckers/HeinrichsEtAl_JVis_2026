# Imports -----------------------------------------------------------------

source("./r/utils.R")

# Packages ----------------------------------------------------------------

library(readr)
library(dplyr)
library(lubridate)
library(ggplot2)

# Functions ---------------------------------------------------------------

#' Prepare cleaned dataset of hormone data for cosinor fitting
#'
#' @param data_path Path to cleaned hormone data CSV file
#'
#' @return
#'
prepare_hormone_data <- function(data_path) {
  # Read the data
  df <- readr::read_csv(data_path, show_col_types = FALSE)
  
  # Prepare data.frame for analysis - only FD session
  df <- df %>%
    dplyr::rename(index = `...1`) %>%
    dplyr::arrange(.data$participant_id,
                   .data$session_id,
                   .data$timestamp_number) %>%
    dplyr::filter(.data$session_id == "FD") %>%
    # Start of FD was exactly 1 h after wake time
    dplyr::mutate(hours_since_start = .data$hours_after_wakeup - 1) %>%
    dplyr::mutate(participant_id = as.factor(.data$participant_id))
  return(df)
}

#' Fit a single simple circadian model with sine and cosine component
#'
#' @param data data.frame with hormone data
#' @param model_formula formatted as formula
#' 
fit_cosinor_hormone_lm <- function(data, model_formula) {
  # Estimate model
  fit <- try(lm(model_formula, data = data), silent = TRUE)
  # Return model and data
  result <- list(fit = fit, data = data)
  return(result)
}

#' Fit circadian model with lm for with different periods for one participant
#'
#' @description Function to fit circadian model with sine-cosine 
#' parameterisation and different taus
#'
#' @param min_period e.g. 20
#' @param max_period e.g. 28
#' @param period_step e.g. 1/60 (by minutes)
#' @param pdata participant specific data
#' @param model_formula formatted as formula
#'
#' @return Model summary
#' @export
#'
iterate_fit_over_circadian_periods <-
  function(pdata,
           model_formula,
           min_period = 20,
           max_period = 28,
           step_period = 1 / 60,
           harmonics = 1) {
    # Validate input
    if (length(unique(pdata$participant_id)) > 1) {
      stop("Function only allows to evaluate one participant at a time")
    } else {
      pid <- as.character(unique(pdata$participant_id))
    }
    # Grid search for optimal tau
    tau_values <- seq(min_period, max_period, by = step_period)
    
    # Compute AIC for different tau values
    gof_results <- lapply(tau_values, function(tau) {
      # Create circadian components (sine and cosine)
      pdata <- create_circadian_components(
        data = pdata,
        hours_col = "hours_after_wakeup",
        tau = tau,
        harmonics = harmonics
      )
      # Fit with specific tau and get goodness of fit metrics
      result <- fit_cosinor_hormone_lm(data = pdata, model_formula = model_formula)
      
      # Error handling
      if (inherits(result$fit, "try-error")) {
        sprintf(
          "tau = %f resulted in failed model fit. Returning Inf to prevent model selection.",
          tau
        )
        gof <- list(aic = Inf,
                    bic = Inf,
                    rsquared = 0)
        
      } else {
        gof <- list(
          aic = AIC(result$fit),
          bic = BIC(result$fit),
          rsquared = summary(result$fit)$r.squared
        )
      }
      return(gof)
    })
    
    # Find optimal tau based on AIC
    aic_results <- lapply(gof_results, function(gof)
      gof$aic)
    optimal_tau <- tau_values[which(min(unlist(aic_results)) == unlist(aic_results))]
    
    # Fit final model with optimal tau
    pdata <- create_circadian_components(
      data = pdata,
      hours_col = "hours_after_wakeup",
      tau = optimal_tau,
      harmonics = harmonics
    )
    result <- fit_cosinor_hormone_lm(data = pdata, model_formula = model_formula)
    
    # Collect all goodness of fit stats
    gof_df <- do.call(rbind, lapply(gof_results, as.data.frame)) %>%
      dplyr::mutate(tau = tau_values)
    
    # Extract model parameter
    params <- list(tau = optimal_tau, nharmonics = length(harmonics))
    tmp <- as.list(coef(result$fit))
    names(tmp)[1] <- "intercept"
    params <- c(params, tmp)
    
    # Circularity stats from fundamental
    if ("sine_component" %in% names(coef(result$fit))) {
      tmp <- list(
        amplitude = calc_amplitude(
          sine_estimate = coef(result$fit)["sine_component"],
          cosine_estimate = coef(result$fit)["cosine_component"]
        ),
        phase = calc_phase(
          sine_estimate = coef(result$fit)["sine_component"],
          cosine_estimate = coef(result$fit)["cosine_component"]
        )
      )
      params <- c(params, tmp)
    }
    # Circularity stats from harmonics
    if ("sine_component_2" %in% names(coef(result$fit))) {
      tmp <- list(
        amplitude_2 = calc_amplitude(
          sine_estimate = coef(result$fit)["sine_component_2"],
          cosine_estimate = coef(result$fit)["cosine_component_2"]
        ),
        phase_2 = calc_phase(
          sine_estimate = coef(result$fit)["sine_component_2"],
          cosine_estimate = coef(result$fit)["cosine_component_2"]
        )
      )
      params <- c(params, tmp)
    }
    
    # Collect all results in data structure
    model_results <- list(
      fit = result$fit,
      parameter = params,
      gof = gof_df,
      data = result$data
    )
    return(model_results)
  }


#' Loads and fit melatonin data to retrieve best fitting tau
#'
#' @description
#' Loads preprocessed and cleaned melatonin data, and fits sine-cosine
#' parameterisation with different periods (tau). Then extracts the best ftting
#' period length per participant based on AIC. Saves all output data, including
#' fits and estimates in out_dir.
#'
#' @param data_path for cleand melatonin data
#' @param out_dir directory
#'
#' @return data.frame with tau and fit statistic per participant in rows
#' @export
#'
determine_melatonin_period <-
  function(data_path,
           out_dir,
           harmonics = 1,
           save_out = TRUE,
           min_period = 20,
           max_period = 28,
           step_period = 1 / 60) {
    if (all(harmonics == 1)) {
      # only fundamental frequency
      model_form <- as.formula("melatonin_concentration ~ 1 + cosine_component + sine_component")
    } else if (all(sort(unique(c(1, harmonics))) == sort(unique(c(2, 1))))) {
      # second harmonic
      model_form <- as.formula(
        "melatonin_concentration ~ 1 + cosine_component + sine_component + cosine_component_2 + sine_component_2"
      )
    } else {
      stop(
        "Provide fundamental frequency only vs. harmonics-containing model in determine_melatonin_period."
      )
    }
    
    # Data preparation
    df <- prepare_hormone_data(data_path = data_path)
    
    # Iterate over single participant data.frames
    model_results <-
      lapply(unique(df$participant_id), function(x) {
        pdata = df[df$participant_id == x, ]
        iterate_fit_over_circadian_periods(
          pdata = pdata,
          model_formula = model_form,
          min_period = min_period,
          max_period = max_period,
          step_period = step_period,
          harmonics = harmonics
        )
      })
    names(model_results) <- unique(df$participant_id)
    return(model_results)
  }

#' Process model results into data.frame and save as CSV
#'
#' @param model_results list of model results from determine_melatonin_period function
#' @param out_dir directory to save CSV file, if FALSE no file is saved
#' 
#' @return data.frame with fitted parameters per participant in rows
#' @export
#' 
process_model_results <- function(model_results, out_dir = FALSE) {
  # Process results into data frame
  results_data <-
    do.call(rbind, lapply(model_results, function(result) {
      gof_tau <-
        result$gof[result$gof$tau == result$parameter$tau, ] %>% as.list()
      
      param_df <- data.frame(
        participant_id = unique(result$data$participant_id),
        tau = result$parameter$tau,
        aic = gof_tau$aic,
        mesor = result$parameter$intercept,
        amplitude = result$parameter$amplitude,
        phase = result$parameter$phase
      )
      
      # Add estimates for fundamental
      if ("sine_component" %in% names(result$fit$coefficients)) {
        param_df[["sine_component"]] <- result$fit$coefficients[["sine_component"]]
        param_df[["cosine_component"]] <- result$fit$coefficients[["cosine_component"]]
      }
      
      # Add estimates for second harmonics
      if ("sine_component_2" %in% names(result$fit$coefficients)) {
        param_df[["amplitude_2"]] <- result$parameter$`amplitude_2`
        param_df[["phase_2"]] <- result$parameter$`phase_2`
        param_df[["sine_component_2"]] <- result$fit$coefficients[["sine_component_2"]]
        param_df[["cosine_component_2"]] <- result$fit$coefficients[["cosine_component_2"]]
      }
      return(param_df)
    }))
  
  # Store data frame with fitted parameters as CSV
  if (is.character(out_dir) & dir.exists(out_dir)) {
    out_path <- save_output_dataframe(
      out_dir = out_dir,
      out_df = results_data,
      filename = "melatonin_circadian_parameters.csv",
      timestamp_prefix = FALSE
    )
  }
  return(results_data)
}

#' Create goodness of fit figure per participant
#'
#' @param model_results list of model results from determine_melatonin_period function
#' @param out_dir directory to save figures, if NULL no figures are saved
#'
#' @returns list of ggplot2 objects
#' @export
#'
create_gof_figure <- function(model_results, out_dir = NULL) {
  # Visualise GOF stats per participant, R2 depending on tau
  p_list <- lapply(model_results, function(result) {
    p <-
      create_plot_r2_against_tau(
        gof_df = result$gof,
        optimal_tau = result$parameter$tau,
        pid = unique(result$data$participant_id)
      )
    
    if (!is.null(out_dir)) {
      filename <-
        sprintf("fig_melatonin_tau_gof_%s.png", gsub("_", "-", unique(result$data$participant_id)))
      save_figure(out_dir = out_dir,
                  p = p,
                  filename = filename)
    }
    return(p)
  })
  return(p_list)
}

#' Create plot of R-squared against tau with optimal tau indicated
#'
#' @param gof_df data.frame with goodness of fit statistics per tau
#' @param optimal_tau optimal tau value based on AIC
#' @param pid participant ID
#'
#' @returns ggplot2 objects
#' @export
#'
create_plot_r2_against_tau <- function(gof_df, optimal_tau, pid) {
  label_text <- paste0('"Optimal " * tau * " = ', round(optimal_tau, 2), '"')
  title_text <- substitute("R-squared vs. period " * tau * " for " * value, list(value = as.character(pid)))
  #print(pid)
  p <- ggplot2::ggplot(gof_df, ggplot2::aes(x = tau, y = rsquared)) +
    ggplot2::geom_point(
      color = "#2C69B0",
      fill = "#6397C3",
      size = 1,
      stroke = 0.5
    ) +
    #ggplot2::geom_line(color = "#30476B", size = 1) +
    ggplot2::geom_vline(
      xintercept = optimal_tau,
      color = "#30476B",
      linetype = "dashed",
      size = 0.8
    ) +
    ggplot2::annotate(
      geom = "text",
      x = optimal_tau,
      y = max(gof_df$rsquared, na.rm = TRUE) * 0.9,
      # Position text near the top
      label = label_text,
      color = "#30476B",
      hjust = -0.1,
      # Adjust horizontal position of text
      size = 5,
      parse = TRUE
    ) +
    ggplot2::labs(
      title = title_text,
      #title = sprintf("R-squared vs. period tau for %s", pid),
      x = expression(tau),
      y = expression(R^2)
    ) +
    ggplot2::theme_bw(base_size = 12) +
    ggplot2::theme(
      panel.grid.major = ggplot2::element_line(color = "#DDDDDD", linewidth = 0.3),
      panel.grid.minor = ggplot2::element_line(color = "#EEEEEE", linewidth = 0.3)
    )
  return(p)
}

#' Create simple polar plot of amplitude and phase estimates
#'
#' @param df_plot data.frame with columns "participant_id", "amplitude", "phase"
#' @param save_plots logical, if TRUE saves plot as PDF in out_dir/fig
#'
#' @returns ggplot2 object
#' @export
#'
create_polar_plot_simple <- function(df_plot, save_plots) {
  tau = 24
  df_plot <- df_plot %>%
    # Create a new column for the angle (in radians)
    dplyr::mutate(
      hours = (.data$phase) * (tau / (2 * pi)),
      # hours = (.data$phase + pi) * (24 / (2 * pi))
      angle = ((.data$phase * 180 / pi) %% 360),
    )
  
  p <- ggplot2::ggplot(df_plot) +
    # Add lines from center to points
    ggplot2::geom_segment(aes(
      x = angle,
      y = 0,
      xend = angle,
      yend = amplitude
    )) +
    # Add points
    ggplot2::geom_point(shape = 21,
                        size = 3,
                        aes(
                          x = angle,
                          y = amplitude,
                          fill = as.factor(participant_id)
                        )) +
    # Customize the appearance
    ggplot2::scale_x_continuous(
      breaks = seq(0, 360, by = 60),
      limits = c(0, 360),
      labels = seq(0, 24, by = 4)
    ) +
    # Convert to polar coordinates
    ggplot2::coord_polar()
  
  # Customize theme
  p <- p +
    ggplot2::theme_bw() +
    ggplot2::theme(
      text = element_text(family = "Arial"),
      plot.title = ggplot2::element_text(
        face = "bold",
        color = "black",
        hjust = 0
      ),
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
      y = "Circadian amplitude",
      # ifelse(freq == 2, "Circadian amplitude", ""),
      # Only show y-axis label for leftmost plots
      fill = "Participants",
      title = "Oscillation parameters of salivary melatonin rhythms"
      # We'll add titles using text_grob ladfter
    ) +
    ggplot2::guides(
      # Only show legend for rightmost plot
      fill = ggplot2::guide_legend(title = "Participants", ncol = 2),
      #
      colour = ggplot2::guide_none(),
      linetype = ggplot2::guide_none()
    ) +
    ggplot2::guides()
  
  if (save_plots) {
    filepath = file.path(out_dir, "fig", "fig_hormone_polar_plot.pdf")
    ggplot2::ggsave(
      filename = filepath,
      plot = p,
      width = 5.5,
      height = 3.3,
      dpi = 300
    )
    print(sprintf("Figure saved in: '%s'", filepath))
  }
  return(p)
}

#' Add design elements to scatter plot
#'
#' @param p ggplot2 object
#' @param participant_id participant ID, can be NULL
#' @param tau Can be NULL, otherwise used in plot title
#'
#' @returns
#' @export
#'
add_scatter_plot_design <- function(p,
                                    participant_id = NULL,
                                    tau = NULL) {
  p <- p +
    labs(y = "Salivary melatonin concentr. [pg/ml]", x = "Time since wake up")
  
  p <- p +
    # Bayesplot-inspired theme
    ggplot2::theme_bw(base_size = 12) +
    ggplot2::theme(
      panel.grid.major = ggplot2::element_line(color = "#DDDDDD", linewidth = 0.3),
      panel.grid.minor = ggplot2::element_line(color = "#EEEEEE", linewidth = 0.3),
      # Remove default title
      plot.title = element_blank()
    )
  
  # Add participant/tau text if participant_id is provided
  if (!is.null(participant_id)) {
    p <- p + annotate(
      "text",
      x = -Inf,
      y = Inf,
      label = sprintf("Participant %s", as.character(participant_id)),
      # label = ifelse(
      #   is.null(tau),
      #   sprintf("Participant %s", as.character(participant_id)),
      #   substitute(
      #     "Participant" * pid * " fitted with " * italic(tau) * " = " * value,
      #     list(pid = as.character(participant_id), value = round(tau, 2))
      #   )
      # ),
      hjust = -0.1,
      vjust = 1.5,
      size = 4
    )
  }
  
  p <- p + ggplot2::labs(
    title = substitute(
      "Salivary melatonin of participant " * pid * " fitted with " * italic(tau) * " = " * value,
      list(value = round(tau, 2), pid = as.character(unique(participant_id)))
    ),
    x = "Time since wake up [hours]",
    y = "Salivary melatonin concentr. [pg/ml]"
  )
  # p <- p +
  #   guides(
  #     colour = guide_legend(
  #       override.aes = list(
  #         shape = c(21, NA, NA), # Shapes for points, no shape for lines
  #         linetype = c(NA, "dashed", "solid"), # Line types for hline and stat_function
  #         color = c("#2C69B0", "#990033", "#30476B"), # Colours for each element
  #         fill = c("#6397C3", NA, NA) # Fill colour for the points
  #       )
  #     )
  #   ) +
  #   scale_colour_manual(
  #     name = "Legend",
  #     values = c("#2C69B0", "#990033", "#30476B"),
  #     labels = c("Data", "Zero", "Fitted")
  #   )
  #
  return(p)
}

#' Create scatter plot with empirical data and fitted sine-cosine function parameters
#'
#' @param df data.frame with hormone data
#' @param est_amplitude estimate of amplitude
#' @param est_phase estimate of phase
#' @param est_mesor estimate of mesor
#' @param tau circadian period estimate
#' @param y_col outcome variable in data.frame ("melatonin_concentration")
#' @param x_col time variable in data.frame ("hours_since_wakeup")
#' @param show_x_axis default TRUE
#' @param show_y_axis default TRUE
#'
#' @returns ggplot2 object
#' @export
#'
create_scatter_sine_plot <- function(df,
                                     est_amplitude = NULL,
                                     est_phase = NULL,
                                     est_mesor = NULL,
                                     tau = NULL,
                                     y_col = "melatonin_concentration",
                                     x_col = "hours_after_wakeup",
                                     show_x_axis = TRUE,
                                     show_y_axis = TRUE) {
  # Check if columns are available
  required_columns <- c(y_col, x_col)
  missing <- required_columns[!(required_columns %in% colnames(df))]
  if (length(missing)) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }
  
  # Create base plot
  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data[[x_col]], y = .data[[y_col]])) +
    geom_hline(
      yintercept = 0,
      linetype = "dashed",
      color = "#990033",
      ggplot2::aes(linetype = "zero")
    ) +
    # Data points
    ggplot2::geom_point(
      color = "#2C69B0",
      fill = "#6397C3",
      shape = 21,
      size = 2,
      stroke = 0.5,
      ggplot2::aes(colour = "Data"),
    )
  p <- if (is.null(tau) |
           is.null(est_amplitude) | is.null(est_phase) | is.null(est_mesor)) {
    warning("Circular parameters are missing.")
  } else {
    p +
      # Sinus curve
      ggplot2::stat_function(
        fun = function(x)
          est_mesor + est_amplitude * cos((2 * pi * x / tau) + est_phase),
        color = "#30476B",
        linetype = "solid",
        ggplot2::aes(colour = "Fitted"),
      )
  }
  p <- p +
    labs(
      y = if (show_y_axis)
        "This is a shared axis title"
      else
        NULL,
      x = if (show_x_axis)
        "This is a shared axis title"
      else
        NULL
    )
  
  p <- add_scatter_plot_design(
    p = p,
    tau = unique(df$tau),
    participant_id = unique(df$participant_id)
  )
  
  return(p)
}

#' Create scatter plot with empirical data and fitted data points 
#'
#' @param df data.frame with hormone data, including fitted data from lm function
#' @param fit_col Fitted data e.g.from lm function ("fitted")
#' @param tau Can be NULL, otherwise used in plot title
#' @param y_col EVariable with empirical in data.frame("melatonin_concentration")
#' @param x_col Time variable in data.frame ("hours_since_wakeup")
#'
#' @returns ggplot2 object
#' @export
create_scatter_plot_fitted <- function(df,
                                       fit_col = "fitted",
                                       tau,
                                       y_col = "melatonin_concentration",
                                       x_col = "hours_after_wakeup") {
  # Check if columns are available
  required_columns <- c(y_col, x_col, fit_col)
  missing <- required_columns[!(required_columns %in% colnames(df))]
  if (length(missing)) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }
  
  # Create base plot
  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data[[x_col]], y = .data[[y_col]])) +
    geom_hline(
      yintercept = 0,
      linetype = "dashed",
      color = "#990033",
      ggplot2::aes(linetype = "zero")
    ) +
    # Data points
    ggplot2::geom_point(
      color = "#2C69B0",
      fill = "#6397C3",
      shape = 21,
      size = 2,
      stroke = 0.5,
      ggplot2::aes(colour = "Empirical data"),
    )
  
  # Add additional y2_col points if provided
  if (!is.null(fit_col)) {
    p <- p + ggplot2::geom_point(
      data = df,
      ggplot2::aes(
        x = .data[[x_col]],
        y = .data[[fit_col]],
        colour = "Fitted data"
      ),
      fill = "#FFFFFF",
      size = 2.5#,
      #ggplot2::aes(colour = "Fitted data"),
    )
  }
  
  p <- add_scatter_plot_design(p, tau = tau, participant_id = as.character(unique(df$participant_id)))
  return(p)
}

#' Create scatter plot with fitted sine-cosine function
#'
#' @param df data.frame with hormone data
#' @param fit lm object with fitted model
#' @param tau circadian period
#' @param y_col outcome variable in data.frame
#' @param x_col time variable in data.frame (hours_since_wakeup)
#'
#' @returns ggplot2 object
#' @export
create_scatter_plot_fun <- function(df,
                                    fit,
                                    tau,
                                    y_col = "melatonin_concentration",
                                    x_col = "hours_after_wakeup") {
  # Fit function preparation
  if (!("sine_component_2" %in% names(fit$coefficients))) {
    # Fundamental only function
    model_form <- as.formula("melatonin_concentration ~ 1 + sine_component + cosine_component")
    
    # Calculate amplitude and phase from coefficients
    phase_1 <- calc_phase(
      sine_estimate = fit$coefficients[["sine_component"]],
      cosine_estimate = fit$coefficients[["cosine_component"]]
    )
    amplitude_1 <- calc_amplitude(
      sine_estimate = fit$coefficients[["sine_component"]],
      cosine_estimate = fit$coefficients[["cosine_component"]]
    )
    
    # Plotting function
    fitted_fun <- function(x) {
      fit$coefficients[["(Intercept)"]] +
        amplitude_1 * (cos(1 * 2 * pi * x / tau + phase_1))
    }
  } else if ("sine_component_2" %in% names(fit$coefficients)) {
    # Second harmonic
    model_form <- as.formula(
      "melatonin_concentration ~ 1 + sine_component + cosine_component + sine_component_2 + cosine_component_2"
    )
    fitted_fun <-
      function(x) {
        fit$coefficients[["(Intercept)"]] +
          (fit$coefficients[["cosine_component"]] * (cos(1 * 2 * pi * x / tau))) +
          (fit$coefficients[["sine_component"]] * (sin(1 * 2 * pi * x / tau))) +
          (fit$coefficients[["cosine_component_2"]] * (cos(2 * 2 * pi * x / tau))) +
          (fit$coefficients[["sine_component_2"]] * (sin(2 * 2 * pi * x / tau)))
      }
    
    # Calculate amplitude and phase from coefficients
    phase_1 <- calc_phase(
      sine_estimate = fit$coefficients[["sine_component"]],
      cosine_estimate = fit$coefficients[["cosine_component"]]
    )
    amplitude_1 <- calc_amplitude(
      sine_estimate = fit$coefficients[["sine_component"]],
      cosine_estimate = fit$coefficients[["cosine_component"]]
    )
    phase_2 <- calc_phase(
      sine_estimate = fit$coefficients[["sine_component_2"]],
      cosine_estimate = fit$coefficients[["cosine_component_2"]]
    )
    amplitude_2 <- calc_amplitude(
      sine_estimate = fit$coefficients[["sine_component_2"]],
      cosine_estimate = fit$coefficients[["cosine_component_2"]]
    )
    
    # Plotting function
    fitted_fun <- function(x) {
      fit$coefficients[["(Intercept)"]] +
        amplitude_1 * (cos(1 * 2 * pi * x / tau + phase_1)) +
        amplitude_2 * (cos(2 * 2 * pi * x / tau + phase_2))
    }
  } else {
    stop(
      "Provide fundamental frequency only vs. harmonics-containing model in determine_melatonin_period function."
    )
  }
  
  # Handle missing columns
  required_columns <- c(y_col, x_col)
  missing <- required_columns[!(required_columns %in% colnames(df))]
  if (length(missing)) {
    stop("Missing columns: ", paste(missing, collapse = ", "))
  }
  
  # Create plot
  p <-
    # Base line plot
    ggplot2::ggplot(df, ggplot2::aes(x = .data[[x_col]], y = .data[[y_col]])) +
    geom_hline(
      yintercept = 0,
      linetype = "dashed",
      color = "#990033",
      ggplot2::aes(linetype = "zero")
    ) +
    # Data points
    ggplot2::geom_point(
      color = "#2C69B0",
      fill = "#6397C3",
      shape = 21,
      size = 2,
      stroke = 0.5,
      ggplot2::aes(colour = "Empirical data"),
    )
  
  if (!is.null(fitted_fun)) {
    # Fit function added
    p <- p +
      ggplot2::stat_function(
        fun = fitted_fun,
        color = "#30476B",
        linetype = "solid",
        ggplot2::aes(colour = "Sinusoid fit")
      )
  } else {
    warning("No fitted function provided, showing only data points")
  }
  p <- add_scatter_plot_design(p,
                               tau = unique(df$tau),
                               participant_id = as.character(unique(df$participant_id)))
  return(p)
}


#' Create plot to describe zero-inflation in melatonin data
#'
#' @param mel_df data.frame with melatonin data, including 
#' columns "melatonin_concentration" and "hours_after_wakeup"
#'
#' @returns ggplot2 object
#' @export
#'
create_plot_zero_inflation <- function(mel_df) {
  plt <- mel_df %>%
    ggplot2::ggplot(aes(x = as.integer(.data$melatonin_concentration))) +
    ggplot2::geom_histogram(bins = 50,
                            color = "black",
                            fill = "lightblue") +
    ggplot2::geom_vline(xintercept = 0, color = "red") +
    ggplot2::labs(title = "Zero-inflation plot", x = "Salivary melatonin concentr. [pg/ml]", y = "Frequency") +
    ggplot2::theme_bw(base_size = 12) +
    ggplot2::theme(
      panel.grid.major = ggplot2::element_line(color = "#DDDDDD", linewidth = 0.3),
      panel.grid.minor = ggplot2::element_line(color = "#EEEEEE", linewidth = 0.3)
    )
  
  return(plt)
}


# Script ------------------------------------------------------------------
fit_cosinor_hormones_main <-
  function(data_path,
           harmonics = c(1, 2),
           out_data = NULL,
           out_figs = NULL) {
    # Input
    #"/Volumes/tscn-projects/civibe/data/derivatives/group/saliva", 
    
    # Create output directory
    if (!dir.exists(out_data)) {
      dir.create(out_data, recursive = TRUE)
      print(cat("Output directory: ", out_data))
    }
    
    save_plot = ifelse(!is.null(out_figs), TRUE, FALSE)
    if (!dir.exists(out_figs)) {
      dir.create(out_figs, recursive = TRUE)
    }
    
    # Fit tau based on input data
    model_results <- determine_melatonin_period(
      data_path = data_path,
      harmonics = harmonics,
      out_dir = out_data,
      save_out = save_plot
    )
    
    # Extract parameters as table from model results
    results_data <-
      process_model_results(model_results = model_results, out_dir = out_data)
    
    
    # Describe zero inflation
    plt <- prepare_hormone_data(data_path) %>%
      dplyr::filter(.data$participant_id != 200) %>%
      create_plot_zero_inflation()
    save_figure(
      p = plt,
      out_dir = out_figs,
      filename = "fig_melatonin_zero-infl.pdf",
      w = 8,
      h = 5
    )
    
    # Visualisation of goodness of fit
    plot_list_gof <- create_gof_figure(model_results = model_results, out_dir = NULL)
    combined_plot <- cowplot::plot_grid(plotlist = plot_list_gof, ncol = 3)
    save_figure(
      p = combined_plot,
      out_dir = out_figs,
      filename = "fig_melatonin_tau_gof.pdf",
      w = 15,
      h = 15
    )
    
    # Create scatter plot with fitted function
    plot_list_func <-
      lapply(model_results, function(result) {
        # Plot data and fit function
        df <- result$data
        df$tau <- round(result$parameter$tau, 2)
        p <- create_scatter_plot_fun(
          df = df,
          fit = result$fit,
          tau = result$parameter$tau,
          y_col = "melatonin_concentration",
          x_col = "hours_after_wakeup"
        )
        # save_figure(
        #   p = p,
        #   out_dir = out_figs,
        #   filename = sprintf(
        #     "fig_melatonin_scatter-func_%s.png",
        #     gsub("_", "-", as.character(
        #       unique(result$data$participant_id)
        #     ))))
        return(p)
      })
    combined_plot <- cowplot::plot_grid(plotlist = plot_list_func, ncol = 3)
    save_figure(
      p = combined_plot,
      out_dir = out_figs,
      filename = "fig_melatonin_scatter-func.pdf",
      w = 15,
      h = 15
    )
    
    
    
    # plot_list_2scatter <-
    #   lapply(model_results, function(result) {
    #     # Plot empirical data and fitted data points
    #     df <- result$data
    #     df$fitted <- fitted(result$fit)
    #     p <- create_scatter_plot_fitted(
    #       df = df,
    #       fit = result$fit,
    #       tau = result$parameter$tau,
    #       fit_col = "fitted",
    #       y_col = "melatonin_concentration",
    #       x_col = "hours_after_wakeup"
    #     )
    #     if (save_plots) {
    #       save_figure(
    #         p = p,
    #         out_dir = file.path(out_dir, "fig"),
    #         filename = sprintf(
    #           "fig_melatonin_scatter-fit_%s.png",
    #           gsub("_", "-", as.character(unique(
    #             result$data$participant_id
    #           )))
    #         )
    #       )
    #     }
    #     return(p)
    #   })
    # End of main()
    return(model_results)
  }
