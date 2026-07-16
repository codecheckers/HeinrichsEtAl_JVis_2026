

# Libraries ----------------------------------------------------------------

library(readr)
library(dplyr)
library(lubridate)
library(brms)
library(stringr)

# Functions ---------------------------------------------------------------

#' Function to extract sine wave parameters
#'
#' @param fit Fitted model object, either from lm() or brms::brm()
#'
#' @return
#' @export
#'
#' @examples
extract_sine_parameters_lm <- function(fit) {
  # Extract coefficients for linear model
  empty_list <- list(
    intercept = NA,
    amplitude = NA,
    phase = NA,
    sine_estimate = NA,
    cosine_estimate = NA
  )
  
  # Error handling
  if (!inherits(fit, "lm")) {
    return(empty_list)
  }
  
  # Get coefficients
  coefs <- stats::coef(fit)
  
  # Check if sine and cosine components exist
  if (!all(c("sine_component", "cosine_component") %in% names(coefs))) {
    return(empty_list)
  }
  
  # Calculate parameters
  sine_estimate <- coefs["sine_component"]
  cosine_estimate <- coefs["cosine_component"]
  
  amplitude <- sqrt(sine_estimate ^ 2 + cosine_estimate ^ 2)
  phase <- atan2(cosine_estimate, sine_estimate)
  
  return(
    list(
      intercept = coefs["Intercept"],
      amplitude = amplitude,
      phase = phase,
      sine_estimate = sine_estimate,
      cosine_estimate = cosine_estimate
    )
  )
}

#' Calculate sine wave parameters from a fitted brms model
#'
#' @param fit (brmsfit) Fitted brms model object
#'
#' @returns
#' @export
#'
extract_sine_parameters_brms <- function(fit) {
  # Check if model fitting was successful
  empty_list <- list(
    intercept = NA,
    amplitude = NA,
    phase = NA,
    sine_estimate = NA,
    cosine_estimate = NA
  )
  if (!inherits(fit, "brmsfit")) {
    return(empty_list)
  }
  
  # Extract fixed effects
  fixed_params <- try(brms::fixef(fit), silent = TRUE)
  
  # Check if parameter extraction was successful
  if (inherits(fixed_params, "try-error") ||
      !all(c("Intercept", "sine_component", "cosine_component") %in% rownames(fixed_params))) {
    return(empty_list)
  }
  
  # Calculate parameters
  sine_estimate <- fixed_params["sine_component", "Estimate"]
  cosine_estimate <- fixed_params["cosine_component", "Estimate"]
  
  amplitude <- sqrt(sine_estimate ^ 2 + cosine_estimate ^ 2)
  phase <- atan2(cosine_estimate, sine_estimate)
  
  return(
    list(
      intercept = fixed_params["Intercept", "Estimate"],
      amplitude = amplitude,
      phase = phase,
      sine_estimate = sine_estimate,
      cosine_estimate = cosine_estimate
    )
  )
  
}


# Function to fit full and null models
fit_models_lm <- function(data) {
  # Full model formula for linear model
  full_model <-
    stats::as.formula("contrast_sensitivity ~ 1 + sine_component + cosine_component")
  
  # Null model formula (intercept only)
  null_model <- stats::as.formula("contrast_sensitivity ~ 1")
  
  # Fit full model
  full_fit <- try(stats::lm(formula = full_model,
                            data = data), silent = TRUE)
  
  # Fit null model
  null_fit <- try(stats::lm(formula = null_model,
                            data = data), silent = TRUE)
  
  # Model comparison using AIC
  if (!inherits(full_fit, "try-error") &&
      !inherits(null_fit, "try-error")) {
    model_comparison <- data.frame(
      full_model_aic = stats::AIC(full_fit),
      null_model_aic = stats::AIC(null_fit)
    )
  } else {
    model_comparison <- NULL
  }
  
  # Extract parameters
  full_params <-
    extract_sine_parameters_lm(full_fit, model_type = "linear")
  
  return(
    list(
      full_fit = full_fit,
      null_fit = null_fit,
      model_comparison = model_comparison,
      parameters = full_params
    )
  )
  # End of function fit_models
}

#' Fit full and null models using brms
#'
#' @param full_def (str)
#' @param null_def (str)
#' @param data
#'
#' @return
#' @export
#'
#' @examples
fit_models_brms <-
  function(data,
           full_def,
           null_def, 
           brm_posterior_samples = 40000,
           fix_seed = 123) {
    # if (!all(c("bla", "blub", "blob") %in% colnames(data))) {
    #   stop("Missing required columns: ", paste(setdiff(c("bla", "blub", "blob"), colnames(data)), collapse = ", "))
    # }
    set.seed(fix_seed)
    # Full model formula
    full_model <- as.formula(full_def)
    
    # Null model formula (intercept only)
    null_model <- as.formula(null_def)
    
    # Fit full model
    cat("Estimating full model ...\n")
    full_fit <- try(brms::brm(
      formula = full_model,
      data = data,
      family = gaussian(),
      chains = 4,
      cores = 4,
      warmup = 1000,
      iter = brm_posterior_samples,
      thin = 1,
      #sample = 40000,
      silent = TRUE,
      refresh = 0,
      save_pars = save_pars(all = TRUE),
      seed = fix_seed
    ),
    silent = TRUE)
    
    # Fit null model
    cat("Estimating null model ...\n")
    null_fit <- try(brms::brm(
      formula = null_model,
      data = data,
      family = gaussian(),
      chains = 4,
      cores = 4,
      warmup = 1000,
      iter = brm_posterior_samples,
      thin = 1,
      #sample = 40000,
      silent = TRUE,
      refresh = 0,
      save_pars = save_pars(all = TRUE),
      seed = fix_seed
    ),
    silent = TRUE)
    cat("... estimations completed.\n")
    
    # Comprehensive model comparison
    if (!inherits(full_fit, "try-error") &&
        !inherits(null_fit, "try-error")) {
      # WAIC Comparison
      cat("WAIC comparison... \n")
      waic_comp <-
        try(brms::waic(full_fit, null_fit), silent = TRUE)
      
      # LOO Comparison
      cat("Loo comparison... \n")
      loo_comp <- try(brms::loo_compare(brms::loo(full_fit),
                                        brms::loo(null_fit)), silent = TRUE)
      
      # Bayes Factor
      cat("BF calculations... \n")
      bayes_factor <-
        try(bayestestR::bayesfactor_models(full_fit, denominator = null_fit),
            silent = FALSE)
      
      # Parameter significance
      cat("Model summary... \n")
      model_summary <- summary(full_fit)
      
      # Probability of Direction
      cat("Parameter / p-values... \n")
      parameter_pd <-
        try(bayestestR::p_direction(full_fit), silent = TRUE)
      parameter_pval <-
        try(bayestestR::p_direction(full_fit, as_p = TRUE), silent = TRUE)
      pvals <- try(data.frame(parameter = parameter_pval$Parameter, pval = parameter_pval$p), silent = TRUE)
      
      # Credible Intervals
      parameter_ci <- try(bayestestR::ci(full_fit, effects = "all", parameters="^(?!r_).*"), silent = TRUE)
      
      model_comparison <- list(
        waic = waic_comp,
        loo = loo_comp,
        bayes_factor = bayes_factor,
        ci = parameter_ci,
        p_value = pvals,
        probability_of_direction = parameter_pd
      )
      
    } else {
      model_comparison <- NULL
    }
    
    # Extract fixed parameters
    full_params <- extract_sine_parameters_brms(full_fit)
    
    
    return(
      list(
        full_fit = full_fit,
        null_fit = null_fit,
        model_comparison = model_comparison,
        parameters = full_params,
        #p_value = pvals,
        data = data
      )
    )
    
    # End of function fit_models
  }


#' Extract and summarize results from brms model fits
#'
#' @param results (list) List of model results from fit_models_brms(), each 
#' containing a "full_fit" entry
#'
#' @returns
#' @export
#'
#' @examples
summarise_results_brms <- function(results) {
  # Preallocate a list to store results
  params_list <- vector("list", length(results))
  
  # Loop through group results
  for (i in seq_along(results)) {
    # per group, e.g. "202_achromatic_8" or "achromatic_8"
    result <- results[[i]]
    
    # Extract group identifiers and parameters
    group_name <-
      if (!is.null(result$group_name))
        result$group_name
    else
      paste("Group", i)
    
    # Create a single row data frame
    params_list[[i]] <- data.frame(
      #participant_id = group_info$participant_id,
      #condition = group_info$condition,
      #freq = group_info$freq,
      group = group_name,
      intercept = result$parameters$intercept,
      amplitude = result$parameters$amplitude,
      phase = result$parameters$phase,
      sine_estimate = result$parameters$sine_estimate,
      cosine_estimate = result$parameters$cosine_estimate,
      
      # Model Comparison Metrics
      waic_full_fit = ifelse(
        !is.null(result$model_comparison$waic),
        result$model_comparison$waic$loos$full_fit$estimates["waic", "Estimate"],
        NA
      ),
      waic_null_fit = ifelse(
        !is.null(result$model_comparison),
        result$model_comparison$waic$loos$null_fit$estimates["waic", "Estimate"],
        NA
      ),
      
      bf = ifelse(
        !is.null(result$model_comparison$bayes_factor),
        # get log of marginal likelihoods (common practise for interpretation)
        as.numeric(result$model_comparison$bayes_factor)[1],
        NA
      ),
      log_bf = ifelse(
        !is.null(result$model_comparison$bayes_factor),
        # get log of marginal likelihoods (common practise for interpretation)
        result$model_comparison$bayes_factor$log_BF[1],
        NA
      ),
      
      # Probability of Direction for sine and cosine components
      pd_sine = if (!is.null(result$model_comparison$probability_of_direction))
        result$model_comparison$probability_of_direction$pd[result$model_comparison$probability_of_direction$Parameter == "b_sine_component"]
      else
        NA,
      
      pd_cosine = if (!is.null(result$model_comparison$probability_of_direction))
        result$model_comparison$probability_of_direction$pd[result$model_comparison$probability_of_direction$Parameter == "b_cosine_component"]
      else
        NA,
      
      pval_intercept = if (!is.null(result$p_value$parameter))
        result$p_value$pval[result$p_value$parameter == "b_Intercept"]
      else
        NA,
      pval_sine = if (!is.null(result$p_value$parameter))
        result$p_value$pval[result$p_value$parameter == "b_sine_component"]
      else
        NA,
      pval_cosine = if (!is.null(result$p_value$parameter))
        result$p_value$pval[result$p_value$parameter == "b_cosine_component"]
      else
        NA
    )
  }
  
  # Combine the list of data frames
  params_df <- do.call(rbind, params_list)
  
  return(params_df)
  
}

summarise_results_lm <- function(results) {
  # Preallocate a list to store results
  params_list <- vector("list", length(results))
  
  # Loop through results
  for (i in seq_along(results)) {
    result <- results[[i]]
    
    # Extract group identifiers
    # For LINEAE models, extract group info works differently
    group_data <- result$full_fit$model
    
    # Create a single row data frame
    params_list[[i]] <- data.frame(
      participant_id = unique(group_data$participant_id),
      condition = unique(group_data$condition),
      freq = unique(group_data$freq),
      intercept = result$parameters$intercept,
      amplitude = result$parameters$amplitude,
      phase = result$parameters$phase,
      sine_estimate = result$parameters$sine_estimate,
      cosine_estimate = result$parameters$cosine_estimate,
      aic_full_model = ifelse(
        !is.null(result$model_comparison),
        result$model_comparison$full_model_aic,
        NA
      ),
      aic_null_model = ifelse(
        !is.null(result$model_comparison),
        result$model_comparison$null_model_aic,
        NA
      )
    )
  }
  
  # Combine the list of data frames
  params_df <- do.call(rbind, params_list)
  
  return(params_df)
}

# Extract observed and predicted values

#' Extract observed and predicted values across time
#'
#' @param model_results list of list including the fit (full_fit)
#'
#' @return data.frame with y_pred and y_obs
#' @export
#'
#' @examples
extract_timecourse_from_model_list <- function(model_results) {
  # print(names(model_results))
  result_list <-
    lapply(model_results, function(result) {
      #print(result$group_name)
      df <- as.data.frame(fitted(result$full_fit)) %>%
        dplyr::mutate(result$full_fit$data) %>%
        dplyr::mutate(x = result$data$hours_since_start) %>%
        dplyr::rename(
          y_obs = as.character(result$full_fit$formula$formula)[2],
          y_pred = "Estimate",
          y_err = "Est.Error", 
          lower_ci = "Q2.5",
          higher_ci = "Q97.5"
        )
      return(df)
    })
  names(result_list) <- names(model_results)
  
  result_df <- do.call(rbind, result_list)
  result_df <- result_df %>%
    dplyr::mutate(
      group = stringr::str_split(rownames(result_df), "\\.", simplify = TRUE)[, 1],
      index = stringr::str_split(rownames(result_df), "\\.", simplify = TRUE)[, 2]
    )
  return(result_df)
}


#' Read and prepare data for analysis input
#'
#' @param data_path (str) Path to data source
#' @param tau (str | num) Path to data file with same participant_ids and taus, or numeric
#'
#' @return
#' @export
#'
prepare_derivative_data <- function(data_path, tau) {
  # if (!file.exists(tau)) {
  #   stop(
  #     "Participant specific melatonin-derived taus are doesn't exist. You can also specify a number, e.g. tau = 24 ...\n"
  #   )
  # }
  
  # Read the data
  df <- readr::read_csv(data_path, show_col_types = FALSE)
  
  # Prepare dataframe for analysis
  df <- df %>%
    #dplyr::arrange(.data$datetime) %>%
    dplyr::mutate(
      participant_id = as.factor(.data$participant_id),
      block = as.factor(.data$block)
    )
  if(any(colnames(df) == "...1")){
    df <- dplyr::rename(df, index = `...1`)
  }  #dplyr::rename(index = `...1`) %>%
  
  # Handle tau, circadian period
  if (is.numeric(tau) &&
      length(tau) == 1) {
    #  && tau %% 1 != 0: If tau is a number with decimals, create a dataframe
    taudf <-
      data.frame(participant_id = unique(df$participant_id),
                 tau = tau)
  } else {
    if (is.data.frame(tau)) {
      taudf <- tau
    } else if (is.character(tau) && file.exists(tau)) {
      taudf <- readr::read_csv(tau, show_col_types = FALSE)
    } else {
      # If tau is neither a valid file nor a numeric value, throw an error
      stop("Error: tau must be either a valid file path or a number with decimals.")
    }
  }
  
  # Create circadian components (sine and cosine)
  df <-
    create_circadian_components(
      data = df,
      tau = taudf[c("participant_id", "tau")],
      hours_col = "hours_since_start"
    )
  return(df)
}


#' Runs model estimation of multiple models on data.frame with grouping columns
#'
#' @param df data.frame
#' @param group_cols grouping variables
#'
#' @return list of models
#' @export
#'
fit_models_on_groups <-
  function(df,
           group_cols,
           full_def = "contrast_sensitivity ~ 1 + sine_component + cosine_component", #"log_tcs ~ 1 + cosine_component + sine_component + (1 + cosine_component + sine_component | participant_id)"
           null_def = "contrast_sensitivity ~ 1") {
    # Group the data
    grouped_data <- df %>%
      dplyr::group_by(dplyr::across(dplyr::all_of(group_cols)))
    grouped_list <- grouped_data %>%
      dplyr::group_split()
    group_names <- grouped_data %>%
      group_keys() %>%
      dplyr::mutate(group = do.call(paste, c(select(
        ., all_of(group_cols)
      ), sep = "_"))) %>%
      dplyr::pull(group)
    names(grouped_list) <- group_names
    
    
    # Statistical Analysis ---------------------------------------------------
    
    # Extract model results and parameters
    model_results <-
      lapply(names(grouped_list), function(group_name) {
        cat(sprintf("Fit model *%s* ...\n", group_name))
        # Get the group data
        gdata <- grouped_list[[group_name]]
        
        # Fit the model
        model_result <-
          fit_models_brms(data = gdata,
                          full_def = full_def,
                          null_def = null_def)
        
        # Add the group name as an additional element to the model result
        model_result$group_name <- group_name
        
        return(model_result)
      })
    # Add name to list entry (check if list entry corresponds group_name)
    names(model_results) <- names(grouped_list)
    
    return(model_results)
  }

#' Extracts random effects for each model fit in a list
#'
#' @param results List of models with model fits in "full_fit" entry; output from fit_models_brms()
#'
#' @return
#' @export
#'
summarise_results_lmm_brms <- function(results) {
  # Preallocate a list to store results
  randef_list <- vector("list", length(results))
  
  # Loop through results
  for (i in seq_along(results)) {
    result <- results[[i]]
    
    # Get random effects for participants
    cluster_df <- extract_random_effects(fit = result$full_fit) %>%
      dplyr::mutate(group = result$group_name) %>%
      dplyr::rename_with(tolower) %>%
      dplyr::select(group, dplyr::everything())
    
    # Create list entry for random effects of group i
    randef_list[[i]] <- cluster_df
  }
  
  # Combine the list of dataframes
  randef_df <- do.call(rbind, randef_list)
  return(randef_df)
}

#' Extract random effect estimates for each group as data.frame
#'
#' @param fit fit objects
#'
#' @return data.frame with random effects
#' @export
#'
extract_random_effects <- function(fit) {
  # Extract random effects
  random_effects <- brms::ranef(fit)
  
  # Grouping factor should be "participant_id"
  grouping_factor <- names(random_effects)
  
  # Extract random effects for participant_id
  cluster_re <- as.data.frame(random_effects[[grouping_factor]])
  
  # Convert to a data frame for easier handling
  cluster_re$participant_id <- rownames(cluster_re)
  
  # Extract the last group
  cluster_re_est <- cluster_re %>%
    dplyr::select(participant_id, dplyr::starts_with("Estimate")) %>%
    dplyr::rename_with( ~ sub("component$", "estimate", .),
                        .cols = dplyr::ends_with("component"))
  colnames(cluster_re_est) <-
    gsub("^Estimate\\.", "re_", colnames(cluster_re_est))
  
  return(cluster_re_est)
}

#' Merge fixed and cluster summary data.frames
#'
#' @param params_df Result from summarise_results_brms
#' @param cluster_df Result from summarise_results_lmm_brms()
#'
#' @return
#' @export
#'
merge_fixed_and_cluster_summaries <- function(cluster_df, fixef_df){
  multi_df <- cluster_df %>%
    dplyr::left_join(fixef_df, by = "group") %>%
    dplyr::mutate(
      intercept_p = .data$intercept + .data$re_intercept,
      sine_estimate_p = .data$sine_estimate + .data$re_sine_estimate,
      cosine_estimate_p = .data$cosine_estimate + .data$re_cosine_estimate,
    ) %>%
    dplyr::mutate(
      amplitude_p = calc_amplitude(sine_estimate = sine_estimate_p, 
                                   cosine_estimate = cosine_estimate_p),
      phase_p = calc_phase(sine_estimate = sine_estimate_p, 
                           cosine_estimate = cosine_estimate_p)
    ) %>%
    dplyr::left_join(dplyr::distinct(cluster_df["participant_id"]), by = #, "participant_id", "tau"
                       "participant_id")
  return(multi_df)
}

#' Turn dataframe into list of lists
#'
#' @param param_df (data.frame) Dataframe with parameters with information on clusters "group" and "participant_id"
#'
#' @return
#' @export
#'
param_df_to_list <- function(params_df){
  grouped <- params_df %>%
    dplyr::group_by(.data$group) 
  group_names <- grouped %>% dplyr::group_keys() %>% dplyr::pull(group)
  group_list <- grouped %>% 
    dplyr::group_by(.data$group) %>% 
    dplyr::group_split() 
  names(group_list) <- group_names
  
  group_list %>%             # Name the list by `group`
    lapply(function(group_data) {
      pid_grouped <- group_data %>%
        dplyr::group_by(.data$participant_id) 
      pid_names <- pid_grouped %>% dplyr::group_keys() %>% dplyr::pull(.data$participant_id)
      pid_list <- pid_grouped %>% dplyr::group_by(.data$participant_id) %>%  dplyr::group_split() 
      names(pid_list) <- pid_names
      return(pid_list)
    })
}

#' Create readable model output as dataframe
#' 
#' @description
#' Similar to console output from "summary(fit)", but as a data.frame, and as
#' preparation for LaTeX output.
#'
#' @param result (list) Result from fit_models_brms() or fit_models_lm(); 
#' labelled model with fit object in "full_fit entry and comparison model "null_fit" entry
#'
#' @returns
#' @export
#'
model_summary_to_df <- function(result) {
  full_fit <- result$full_fit
  null_fit <- result$null_fit
  # Check if full_fit and null_fit are valid brmsfit objects
  
  full_df <- brms::posterior_summary(full_fit) %>%
    as.data.frame() %>%
    tibble::rownames_to_column("Predictor") %>%
    dplyr::filter(stringr::str_detect(Predictor, "^b_|^sd_|^cor_")) %>% # "^b_|^sd_|^cor"
    dplyr::mutate(dplyr::across(dplyr::where(is.numeric), ~ round(., 3))) %>%
    dplyr::mutate(model = result$group_name) %>%
    dplyr::select(model, dplyr::everything())
  
  null_df <- brms::posterior_summary(null_fit) %>%
    as.data.frame() %>%
    tibble::rownames_to_column("Predictor") %>%
    dplyr::filter(stringr::str_detect(Predictor, "^b_|^sd_|^cor_")) %>%  # "^b_|^sd_|^cor"
    dplyr::mutate(dplyr::across(dplyr::where(is.numeric), ~ round(., 3))) %>%
    dplyr::rename_all( ~ paste0(., "_null")) %>%
    dplyr::mutate(model = result$group_name) %>%
    dplyr::select(model, dplyr::everything()) %>%
    dplyr::rename(Predictor = Predictor_null)
  fit_df <-
    dplyr::full_join(full_df, null_df, by = c("model", "Predictor"))
  
  # Number of observations and clusters
  n_data <- data.frame(Predictor = c("n_obs", "n_cluster"),
                       Estimate = c(dim(full_fit$data)[1], dim(unique(full_fit$data[4]))[1]))
  
  # Bayes Factor statistics
  bf <- data.frame(
    Predictor = c("\\ac{logbf}", "BF"),
    Estimate = c(
      bayestestR::bayesfactor_models(full_fit, denominator = null_fit)$log_BF[1],
      as.numeric(
        bayestestR::bayesfactor_models(full_fit, denominator = null_fit)
      )[1]
    )
  )
  bayesr2  <- brms::bayes_R2(full_fit)
  bayesr2_null  <- brms::bayes_R2(null_fit)
  r2conditional <- data.frame(
    Predictor = "conditional_r2",
    Estimate = bayesr2[1],
    Q2.5 = bayesr2[3],
    Q97.5 = bayesr2[4],
    Estimate_null = bayesr2_null[1],
    Q2.5_null = bayesr2_null[3],
    Q97.5_null = bayesr2_null[4]
  )
  bayesr2  <- brms::bayes_R2(full_fit, re.form = NA)
  bayesr2_null  <- brms::bayes_R2(null_fit, re.form = NA)
  r2marginal <- data.frame(
    Predictor = "marginal_r2",
    Estimate = bayesr2[1],
    Q2.5 = bayesr2[3],
    Q97.5 = bayesr2[4],
    Estimate_null = bayesr2_null[1],
    Q2.5_null = bayesr2_null[3],
    Q97.5_null = bayesr2_null[4]
  )
  
  # Circadian parameters
  circadian_param <- data.frame(
    Predictor = c("Amplitude", "Phase"),
    Estimate = c(
      result$parameters$amplitude,
      result$parameters$phase
    )
  )
  
  # Concatenate all dataframes into one result data frame
  model_df <-
    dplyr::bind_rows(fit_df,
                     n_data,
                     bf,
                     r2conditional,
                     r2marginal,
                     circadian_param) %>%
    dplyr::select(Predictor,
                  Estimate,
                  Q2.5,
                  Q97.5,
                  Estimate_null,
                  Q2.5_null,
                  Q97.5_null) %>%
    dplyr::mutate(dplyr::across(dplyr::where(~ !is.character(.)), ~ round(., 3))) %>%
    dplyr::mutate(dplyr::across(Estimate, as.character)) %>%
    dplyr::mutate(
      Estimate = ifelse(
        Predictor == "n_obs",
        as.character(as.integer(Estimate)),
        as.character(Estimate)
      ),
      Estimate = ifelse(
        Predictor == "n_cluster",
        as.character(as.integer(Estimate)),
        as.character(Estimate)
      )
    )
  return(model_df)
}

