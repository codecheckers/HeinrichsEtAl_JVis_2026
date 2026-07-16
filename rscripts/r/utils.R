#!/usr/bin/env Rscript

# ===============================================================
# Purpose:
#   Define helper and utility functions for use in circadian rhythm
#   analysis and psychophysical modelling pipelines.
#
# Author:
#   Hannah Heinrichs
#
# Date:
#   2025-08-04
#
# Description:
#   This script provides functions for:
#     - Saving output (data frames, figures, LaTeX files)
#     - Creating sine and cosine components for rhythmic modelling
#     - Calculating amplitude and phase from sine-cosine parameters
#     - Identifying multilevel formulas in brms models
#
#   The functions are designed to support analysis scripts using brms,
#   ggplot2, and custom modelling of circadian variation.
#
# Usage:
#   source("utils.R")
#
# Example:
#   source("./analysis/src/r/utils.R")
#   df <- create_circadian_components(df, tau = 24.2)
#   amp <- calc_amplitude(sine_est, cosine_est)
#   save_output_dataframe(out_dir = "results/", out_df = df, filename = "processed_data.csv")
#
# Dependencies:
#   ggplot2, dplyr, readr
# ===============================================================

library(dplyr)

#' Helper function to save output with or without timestamp
#'
#' @param out_dir (str)
#' @param out_df (data.frame)
#' @param filename (str)
#' @param timestamp_prefix (bool)
#'
#' @return (str) Output path.
#' @export
#'
save_output_dataframe <-
  function(out_dir,
           out_df,
           filename,
           timestamp_prefix = TRUE) {
    # Create filename
    timestamp <- format(Sys.time(), "%Y%m%dT%H%M")
    filename <-
      ifelse(timestamp_prefix,
             paste(timestamp, filename, sep = '_'),
             filename)
    # Save data and print information
    out_path = file.path(out_dir, filename)
    if (!dir.exists(out_dir)){
      cat(print("Creating non-existing directory:", out_dir))
      dir.create(out_dir)
    }
    write.csv(out_df, out_path, row.names = FALSE)
    cat(sprintf("File saved in this file: '%s'\n", out_path))
    return(out_path)
  }


#' Save ggplot figure with or without timestamp
#'
#' @param p ggplot object
#' @param out_dir output directory
#' @param filename filename (str)
#' @param timestamp_prefix default FALSE
#' @param w width in inches, default 6
#' @param h height in inches, default 4
#'
#' @returns (str) Output path.
#' @export
#'
#' @examples
save_figure <-
  function(p,
           out_dir,
           filename,
           timestamp_prefix = FALSE,
           w = 6,
           h = 4) {
    # Create filename
    timestamp <- format(Sys.time(), "%Y%m%dT%H%M")
    filename <-
      ifelse(timestamp_prefix,
             paste(timestamp, filename, sep = '_'),
             filename)
    # Save data and print information
    out_path = file.path(out_dir, filename)
    ggplot2::ggsave(
      filename = file.path(out_dir, filename),
      plot = p,
      width = w,
      height = h,
      dpi = 300
    )
    filename <-
      ifelse(timestamp_prefix,
             paste(timestamp, filename, sep = '_'),
             filename)
    cat(sprintf("Figure saved in: '%s'\n", out_path))
    return(out_path)
  }

#' Helper function to save a text as .tex file
#'
#' @param out_string (str) String to save as text file.
#' @param out_path (str) Path to save the text file.
#'
#' @returns
#' @export
#'
save_tex <- function(out_string, out_path){
  if (dir.exists(dirname(out_path))) { #tex_dir <- "./reports/log_tcs/multilevel/reports/tex"
    #cat(formatted_text, file = out_path)
    write(x=out_string, file=out_path)
    cat(sprintf("Text file saved in: '%s'\n", out_path))
  } else {
    warning("Directory does not exist, printing to console instead.\n")
    cat(out_string)
  }
  
}


#' Helper function to create harmonic components
#'
#' @param time time vector
#' @param period circadian period
#' @param harmonic_number e.g. 2 for second harmonic
#'
#' @returns list with sine and cosine components
#' @export
#'
create_harmonic <- function(time, period, harmonic_number) {
  list(
    sine = sin(2 * pi * harmonic_number * time / period),
    cosine = cos(2 * pi * harmonic_number * time / period)
  )
}

#' Helper function to create sine and cosine components
#'
#' @param data
#' @param tau Value for circadian period, or column name of tau column in data
#' @param hours_col Time columns to use for circadian rhythm. Defaults to "hours_since_start", i.e. hours since start of the experiment, e.g. FD.
#' @param match_id If tau is a dataframe, provide matching ID
#'
#' @return data.frame with sine and cosine component
#' @export
#'
create_circadian_components <- function(data, 
                                        tau, 
                                        hours_col = "hours_since_start", 
                                        harmonics = c(1)) {
  if (!(hours_col %in% colnames(data))) {
    stop(paste("Missing required column:", hours_col))
  }
  
  # Ensure fundamental (1) is always included and harmonics are unique and sorted
  harmonics <- sort(unique(c(1, harmonics)))
  
  # If tau is a dataframe, merge it first
  if (is.data.frame(tau)) {
    data <- merge(data, tau, by = "participant_id", all.x = TRUE)
    circ_period <- data$tau
  } else if (is.numeric(tau) && length(tau) == 1) {
    circ_period <- tau
  } else {
    stop("Error: tau must be a data frame, or a number.")
  }
  
  # Create all harmonic components at once
  for (h in harmonics) {
    if (h == 1) {
      # Fundamental frequency - no suffix
      data[["sine_component"]] <- sin(2 * pi * data[[hours_col]] / circ_period)
      data[["cosine_component"]] <- cos(2 * pi * data[[hours_col]] / circ_period)
    } else {
      # Higher harmonics - include suffix
      data[[paste0("sine_component_", h)]] <- sin(2 * pi * h * data[[hours_col]] / circ_period)
      data[[paste0("cosine_component_", h)]] <- cos(2 * pi * h * data[[hours_col]] / circ_period)
    }
  }
  
  return(data)
}

#' Calculate sinus amplitude from a and b
#'
#' @param sine_estimate (num) 
#' @param cosine_estimate (num)
#'
#' @return amplitude (num)
#' @export
#'
calc_amplitude <- function(sine_estimate, cosine_estimate){
  ampl <- sqrt(sine_estimate ^ 2 + cosine_estimate ^ 2)
  return(ampl)
}

#' Calculate sinus phase from a and b
#'
#' @param cosine_estimate (num) a 
#' @param sine_estimate (num) b
#'
#' @return phase (num)
#' @export
#'
calc_phase <- function(cosine_estimate, sine_estimate){
  theta <- atan2(-sine_estimate, cosine_estimate)
  return(theta)
}

#' Calculate decimal time from angle (e.g. phase)
#' 
#' @description Pi would be 12 hours, 2pi would be 24 hours, -pi would be 0 hours
#'
#' @param theta (num) phase in radians
#' @param tau (num) period, defaults to 24
#'
#' @returns
#' 
phase_to_decimal_time <- function(theta, tau=24){
  decimal_time <- ((theta %% (2 * pi) * tau )/ (2 * pi)) 
  return(decimal_time)
}

#' Calculate HH:MM from angle (e.g. phase)
#' 
#' @description #' Pi would be 12 hours, 2pi would be 24 hours, -pi would be 0 hours
#' 
#'
#' @param theta (num) phase in radians
#' @param tau (num) period, defaults to 24
#'
#' @returns 
#' @export
#'
phase_to_hm <- function(theta, tau=24){
  decimal_t <- phase_to_decimal_time(theta=theta, tau=tau)
  hhmm <- decimal_to_hm(decimal_time=decimal_t)
  return(hhmm)
}

#' Create HH:MM string from decimal hours
#'
#' @param decimal_time (num) decimal time in hours
#' @param origin (str) origin date for POSIXct conversion, defaults to "1970-01-01"
#'
#' @returns (str) for time in HH:MM format
#' @export
#'
decimal_to_hm <- function(decimal_time, origin = "1970-01-01"){
  #strftime(as.POSIXct(decimal_time * 60 * 60, origin = origin, tz="UTC"), "%H:%M")
  hours <- floor(decimal_time)
  minutes <- round((decimal_time - hours) * 60)
  
  # Format as "HH:MM"
  time_str <- sprintf("%02d:%02d", hours, minutes)
  return(time_str)
}

#' Wrap phase to positive values
#' 
#' @description Converts negative angles to equivalent positive angles in [0, 2pi]
#'
#' @param theta 
#'
#' @returns
#' @export
#'
#' @examples
wrap_phase <- function(theta){
  wrapped_phase <- ifelse(theta < 0, theta %% 2 * pi, theta)
  return(wrapped_phase)
}

#' Indicates whether formula specifies multiple levels
#'
#' @param formula (chr | object) formula string. To extract from fit object, use formula(fit)
#'
#' @return (bool)
#' @export
#'
is_multilevel <- function(formula) {
  # Ensure the formula is a brms formula object
  if (!inherits(formula, "formula") && !inherits(formula, "brmsterms")) {
    # Convert the formula to a character string
    formula_str <- deparse(formula)
  } else if (!is.character(formula)) {
    stop("Must be a formula object or string.")
  }
  
  # Check if the formula includes a multi-level term with a "|" symbol
  has_clustering <- any(grepl("\\|", formula_str))
  
  return(has_clustering)
}

#' Format Small Numbers in Scientific Notation or Rounded Numeric
#'
#' @describtion
#' Converts a numeric value to a character string with scientific notation in LaTex style.
#'
#' @param x Numeric value to format.
#' 
#' @return Character string with LaTeX-style scientific notation if |x| < 0.01, 
#' or numeric rounded to 2 decimal places otherwise.
#' 
#' @export
roundsci <- function(x){
  if (x < 0.01 & x > -0.01) {
    output <-
      gsub("e([+-]?)0*([1-9]\\d*)",
           " \\\\times 10^{\\1\\2}",
           formatC(x, format = "e", digits = 2))
  } else {
    output = round(x, 2)
  }
  
  return(output)
}

#' Round Numeric Value with Threshold Formatting
#'
#' @description Rounds a numeric value to 2 decimal places.
#' If the rounded value is smaller than 0.01, returns a character string "<0.01".
#' Otherwise returns the rounded numeric value.
#'
#' @param x Numeric value to round.
#' 
#' @return Numeric rounded to 2 decimal places or character string "<0.01" if rounded value < 0.01.
#' 
#' @export
#'
roundless <- function(x){
  output <- round(x, 2)
  if (output == 0.000000) {
    output <- "0"
  }
  if (output < 0.01) {
    output <- paste0("<0.01")
  }
  return(output)
}


