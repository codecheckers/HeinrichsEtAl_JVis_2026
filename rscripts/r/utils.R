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

#' Calculate cosinor phase from the sine and cosine coefficients
#'
#' @description Returns phi of the cosinor form y = M + A * cos(omega * t + phi),
#'   NOT the phase of a sine form. Expanding the cosinor form against the
#'   regression y = M + alpha * sin(omega * t) + beta * cos(omega * t) gives
#'   sine_estimate = -A sin(phi) and cosine_estimate = A cos(phi), hence phi = atan2(-sine_estimate, cosine_estimate).
#'   The sine form y = M + A * sin(omega * t + psi) would instead give
#'   psi = atan2(beta, alpha) = phi + pi/2. Use this function throughout so that
#'   phases are on one convention; see [phase_to_peak_time()] for the time of peak.
#'
#' @param cosine_estimate (num) beta, the coefficient on `cosine_component`
#' @param sine_estimate (num) alpha, the coefficient on `sine_component`
#'
#' @return phase (num) phi in radians, in (-pi, pi]
#' @export
#'
calc_phase <- function(cosine_estimate, sine_estimate){
  theta <- atan2(-sine_estimate, cosine_estimate)
  return(theta)
}

#' Calculate time of peak from a cosinor phase
#'
#' @description The cosinor component A * cos(harmonic * omega * t + theta), with
#'   omega = 2 * pi / tau, is maximal where its argument is a multiple of 2 * pi,
#'   i.e. at t = -theta / (harmonic * omega). The returned time is reduced onto
#'   one cycle of the component, [0, tau / harmonic).
#'
#'   Note the sign flip: the peak sits at the NEGATED phase. Feeding a phase
#'   straight through the scaling alone would return the trough.
#'
#'   The returned time is on the same origin as the time variable the model was
#'   fitted on. For the melatonin fits that variable is `hours_after_wakeup`, so
#'   the result is hours after wakeup, not a clock time.
#'
#' @param theta (num) phase in radians, as returned by `calc_phase()`
#' @param tau (num) period of the fundamental in hours, defaults to 24
#' @param harmonic (num) harmonic number the phase belongs to; 1 for the
#'   fundamental, 2 for the second harmonic
#'
#' @returns (num) time of peak in hours, in [0, tau / harmonic)
#' @export
#'
#' @examples
#' # participant 113: phi = 1.23, tau = 24.48
#' # phase_to_decimal_time(1.23, tau = 24.48)  # 19.70, the melatonin peak
#'
phase_to_decimal_time <- function(theta, tau=24, harmonic=1){
  omega <- harmonic * 2 * pi / tau
  decimal_time <- (-theta / omega) %% (tau / harmonic)
  return(decimal_time)
}

#' Convert an angular difference to hours
#'
#' @description Scales radians to hours by tau / (2 * pi), with no sign flip and
#'   no reduction onto a cycle. Use for differences between phases, such as an SD
#'   across participants or a shift between conditions, where the quantity is a
#'   spread rather than a position in the cycle. For positions use
#'   [phase_to_decimal_time()].
#'
#' @param theta (num) angular difference in radians
#' @param tau (num) period in hours, defaults to 24
#'
#' @returns (num) hours
#' @export
#'
radians_to_hours <- function(theta, tau=24){
  theta * tau / (2 * pi)
}

#' Calculate HH:MM of the peak from a cosinor phase
#'
#' @description Formats [phase_to_decimal_time()] as HH:MM. The result is an
#'   elapsed time on the model's own time origin, so it only reads as a clock
#'   time if the model was fitted on clock hours.
#'
#' @param theta (num) phase in radians, as returned by `calc_phase()`
#' @param tau (num) period of the fundamental in hours, defaults to 24
#' @param harmonic (num) harmonic number the phase belongs to
#'
#' @returns (str) time of peak as "HH:MM"
#' @export
#'
phase_to_hm <- function(theta, tau=24, harmonic=1){
  decimal_t <- phase_to_decimal_time(theta=theta, tau=tau, harmonic=harmonic)
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
#' @description Converts angles to equivalent positive angles in [0, 2pi)
#'
#' @param theta (num) angle in radians
#'
#' @returns (num) angle in radians, wrapped to [0, 2pi)
#' @export
#'
#' @examples
#' # wrap_phase(-1.5)  # 4.783, not 1.571
wrap_phase <- function(theta){
  # Parenthesise 2 * pi: %% binds tighter than * in R, so `theta %% 2 * pi`
  # would evaluate as `(theta %% 2) * pi`
  wrapped_phase <- theta %% (2 * pi)
  return(wrapped_phase)
}

#' Wrap angles onto the branch centred on a reference angle
#'
#' @description Maps each angle to the equivalent angle within (center - pi,
#'   center + pi]. Use before taking `min()`/`max()` of a set of phases, so that
#'   the reported range is not split by an arbitrary branch cut at 0 or +/-pi.
#'
#' @param theta (num) angles in radians
#' @param center (num) reference angle in radians, e.g. the circular mean
#'
#' @returns (num) angles in radians
#' @export
#'
wrap_phase_around <- function(theta, center){
  center + ((theta - center + pi) %% (2 * pi)) - pi
}

#' Circular mean of a set of angles
#'
#' @description The arithmetic mean is not meaningful for angles that straddle a
#'   branch cut (e.g. phases near +/-pi): it can fall outside the observed range.
#'   This resolves the angles into unit vectors and averages those instead.
#'
#' @param theta (num) angles in radians
#' @param na.rm (bool) drop missing values
#'
#' @returns (num) mean angle in radians, in (-pi, pi]
#' @export
#'
circular_mean <- function(theta, na.rm = FALSE){
  if (na.rm) theta <- theta[!is.na(theta)]
  atan2(mean(sin(theta)), mean(cos(theta)))
}

#' Circular standard deviation of a set of angles
#'
#' @description Computed as sqrt(-2 * log(R)), with R the mean resultant length.
#'   Unlike the linear `sd()`, this does not depend on where the branch cut
#'   falls. It approaches the linear SD for tightly clustered angles and
#'   diverges as the angles approach a uniform spread.
#'
#' @param theta (num) angles in radians
#' @param na.rm (bool) drop missing values
#'
#' @returns (num) circular SD in radians
#' @export
#'
circular_sd <- function(theta, na.rm = FALSE){
  if (na.rm) theta <- theta[!is.na(theta)]
  resultant_length <- sqrt(mean(sin(theta)) ^ 2 + mean(cos(theta)) ^ 2)
  sqrt(-2 * log(resultant_length))
}

#' Range of a set of angles, taken on the circle
#'
#' @description `min()`/`max()` applied to angles directly are split by the
#'   branch cut at +/-pi: a cluster straddling it is reported as spanning almost
#'   the whole circle. This wraps the angles onto the branch centred on their
#'   circular mean first, so the range covers the arc the angles actually occupy.
#'   The returned bounds may therefore fall outside (-pi, pi].
#'
#'   This is exact for clustered angles (the case where a range is interpretable
#'   at all) and matches the smallest containing arc on every cell of the
#'   melatonin and tCS data. It is not the smallest containing arc in general:
#'   for near-uniform angles the circular mean is unstable and the span can be
#'   overstated. Compute the largest-gap arc instead if such data ever needs a
#'   reported range.
#'
#' @param theta (num) angles in radians
#' @param na.rm (bool) drop missing values
#'
#' @returns (num) named vector with elements `min` and `max`, in radians
#' @export
#'
#' @examples
#' # circular_range(c(3.0, -3.0))  # min -3.28, max -3.00: a span of 0.28,
#' #                               # where min/max would report 6.00
circular_range <- function(theta, na.rm = FALSE){
  if (na.rm) theta <- theta[!is.na(theta)]
  branch <- wrap_phase_around(theta, center = circular_mean(theta))
  c(min = min(branch), max = max(branch))
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


