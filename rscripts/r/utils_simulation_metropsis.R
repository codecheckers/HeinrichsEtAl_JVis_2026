
# Libraries  --------------------------------------------------------------

library(dplyr)
# library - gitr

# Imports -----------------------------------------------------------------

source("./rscripts/r/utils.R")

# Directories -------------------------------------------------------------

# Output directory
# subfolder <- "tcs_simulation"
# modality_dir <- file.path(project_dir, subfolder)
# out_dir = ifelse(
#   in_progress,
#   file.path(modality_dir, "", format(Sys.time(), "%Y%m%dT%H%M")),
#   modality_dir
# )
# 
# # Create output directory
# if (!dir.exists(out_dir)) {
#   dir.create(out_dir, recursive = TRUE)
# }

# Simulation & Test -------------------------------------------------------

get_ideal_hours_vec <- function(){
  hours_since_start = c(
    0.00,
    1.00,
    1.50,
    3.75,
    4.25,
    4.75,
    7.50,
    8.50,
    9.00,
    11.25,
    12.25,
    12.75,
    15.00,
    16.25,
    17.25,
    17.75,
    20.50,
    21.50,
    22.00,
    24.25,
    25.25,
    25.75,
    28.00,
    29.00,
    29.50,
    31.75,
    32.75,
    33.25,
    35.50,
    36.50,
    37.00,
    39.25,
    40.25#,
    #40.75
  )
  return(hours_since_start)
}


#' Draws true values
#' 
#' @description
#' Samples true parameters from normal distributions if is_random. Dispersion is 
#' defined internally in the function.
#' 
#' @param num_participants (num) e.g. 2
#' @param conditions e.g. c("blue-yellow", "red-greed") or "blue-yellow"
#' @param freqs c(2, 8) or 2
#' @param mesor (num) offset
#' @param a (num) sine weight
#' @param b (num) cosine weight
#' @param seed (int) 
#'
#' @return data.frame with parameters for all condition combinations
#' @export
#'
generate_true_parameters <- function(num_participants,
                                     conditions,
                                     freqs,
                                     mesor,
                                     a,
                                     b,
                                     seed = NA, 
                                     is_random = TRUE) {
  
  # Create the data frame with the mesor, a, and b values
  params_df = expand.grid(
    participant_id = 200 + 1:num_participants,
    condition = conditions,
    freq = freqs
  )  %>%
    dplyr::arrange(.data$participant_id, .data$condition, .data$freq) %>% 
    dplyr::mutate(participant_id = as.factor(.data$participant_id))
  
  # Draw mesor, a, and b values from distributions
  if (is_random) {
    if (!is.na(seed)){
      set.seed(seed)
    }
    params_df$mesor = rnorm(nrow(params_df), mean = mesor, sd = 1)
    params_df$a = rnorm(nrow(params_df), mean = a, sd = 5)
    params_df$b = rnorm(nrow(params_df), mean = b, sd = 5)
  } else {
    params_df$mesor = mesor
    params_df$a = a
    params_df$b = b
  }
  
  # Calculate circadian phase and amplitude
  params_df$amplitude <- sqrt(params_df$a ^ 2 + params_df$b ^ 2)
  params_df$phase <- atan2(params_df$a, params_df$b)
  
  return(params_df)
}

#' Simulates outcome based on true data frame of parameters and time vector
#'
#' @param params_df output of generate_true_parameters
#' @param hours_since_start_vec e.g. 1:40
#'
#' @return
#'
#' @examples
generate_circadian_outcome_over_time <-
  function(params_df, hours_since_start_vec, tau) {
    # Extend parameter specification to data frame with time course
    df <-
      params_df %>% tidyr::expand_grid(hours_since_start = hours_since_start_vec)
    
    # Calculate the sine and cosine components
    df$sine_component = sin((2 * pi * df$hours_since_start)/ tau)
    df$cosine_component = cos((2 * pi * df$hours_since_start)/ tau)
    
    # Calculate the error term for each participant
    error_df = data.frame(
      participant_id = unique(df$participant_id),
      error_participant_id = rnorm(length(unique(
        df$participant_id
      )), mean = 0, sd = 0.5)
    )
    
    # Merge the error term with the original data frame
    df = merge(df, error_df, by = "participant_id")
    
    # Calculate the simulated values for circadian rhythm
    df$contrast_sensitivity <- df$mesor +
      (params_df$a * df$sine_component) +
      (params_df$b * df$cosine_component) +
      df$error_participant_id +
      rnorm(nrow(df), mean = 0, sd = 1)
    return(df)
  }


#' Simulation function from parameter definition to
#'
#' @param num_participants (int), Number of participants
#' @param conditions Colour condition; array of strings
#' @param freqs Temporal frequency condition (NOT frequency of rhythm !); array of strings.
#' @param seed (int)
#' @param sine_weight (num); True value of parameter estimate for sine component.
#' @param cosine_weight (num); True value of parameter estimate for cosine component.
#' @param mesor (num) offset
#' @param hours_since_start_vec 
#' @param tau 
#' @param is_random (bool) for parameter sampling
#'
#' @return (str) Path to CSV with true parameter values and generated outcome variable "contrast_sensitivity"
#'
#' @examples
simulate_circadian_pychophysics <-
  function(num_participants = 2,
           conditions = c("blue-yellow", "red-greed"),
           freqs = c(2, 8),
           mesor = NA,
           sine_weight = NA,
           cosine_weight = NA,
           hours_since_start_vec = NA,
           tau = 24,
           seed = 751,
           is_random = TRUE
           ) {
           # Draw true values from normal distributions
           params_df <- generate_true_parameters(
             num_participants = num_participants,
             conditions = conditions,
             freqs = freqs,
             mesor = mesor,
             a = sine_weight,
             b = cosine_weight,
             seed = seed,
             is_random = is_random
           )
           
           # Use parameters to generate outcome variable
           if (is.na(hours_since_start_vec)) {
             hours_since_start_vec <- get_ideal_hours_vec()
           }
            
           # Predictor variables
           df <-
             generate_circadian_outcome_over_time(params_df = params_df,
                                        hours_since_start = hours_since_start_vec, tau=tau)
           
           # Outcome variable
           out_df <-
             create_circadian_components(data = df, tau = tau)
           
           # Additional variables
           out_df$datetime <- (as.POSIXct("2024-01-01") + (8 * 60^2)) + df$hours_since_start * 60^2
           out_df <- out_df %>%
             dplyr::group_by(participant_id, condition, freq) %>%
             dplyr::mutate(block = (dplyr::row_number() - 1) %/% 3) %>%
             dplyr::ungroup() 
          
           return(out_df)
           }

# Script ------------------------------------------------------------------

run_example <- function(out_dir) {
  # Run simulation
  df <-
    simulate_circadian_pychophysics(
      num_participants = 2,
      conditions = c("blue-yellow", "red-greed"),
      freqs = c(2, 8),
      offset = 8.35,
      sine_weight = 5.2,
      cosine_weight = 6.14,
      seed = 751,
      out_dir = out_dir
    )
  
  # Save data
  if (!is.na(out_dir)){
    out_path = save_output_dataframe(
      out_dir = out_dir,
      out_df = df,
      filename = "simulated_tcs.csv",
      timestamp_prefix = TRUE
    )
  } else {
    out_path = NA
  }
  return(out_path)
}
