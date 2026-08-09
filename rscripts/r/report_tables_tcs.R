# Load required libraries
library(ggplot2)
library(gridExtra)
library(grid)
library(dplyr)

# Canonical paths (DERIVATIVES_DIR, TABLE_DIR, TEX_DIR, ...). See ../STRUCTURE.md.
source("./r/paths.R")
source("./r/utils.R")

options(readr.num_columns = 0)

# Functions ---------------------------------------------------------------

#' Create demographics table
create_tbl_demographics <- function(data_path) {
  df <- readr::read_csv(data_path) %>%
    as.data.frame
}


#' Hormone stats table with tau
#'
#' @param tau_path Path to the tau CSV file with circadian parameters tau.
#' @param out_dir Output directory to save the LaTeX table. If `NULL`, the table is not saved.
#'
#' @returns
#' @export
#'
create_tbl_tau <- function(tau_path,
                           out_dir = NULL, filename = "tbl_hormone_stats.tex") {
  tau_df <- readr::read_csv(tau_path, show_col_types = FALSE)
  
  with_harmonics <- ("amplitude_2" %in% colnames(tau_df))
  
  if (with_harmonics) {
    names_vec <-
      c(
        "participant_id",
        "tau",
        "aic",
        "mesor",
        "amplitude",
        "phase",
        "amplitude_2",
        "phase_2"
      )
    label_vec <-
      c(
        "Participant",
        "Optimal tau",
        "$AIC$",
        "Intercept",
        "Amplitude (1st)",
        "Phase (1st)",
        "Amplitude (2nd)",
        "Phase (2nd)"
      )
  } else {
    names_vec <-
      c("participant_id",
        "tau",
        "aic",
        "mesor",
        "amplitude",
        "phase")
    label_vec <-
      c("Participant",
        "Optimal tau",
        "$AIC$",
        "Intercept",
        "Amplitude",
        "Phase")
  }
  
  tex_out <- tau_df %>%
    dplyr::filter(.data$participant_id != 200) %>%
    dplyr::select(dplyr::all_of(names_vec)) %>%
    kableExtra::kable(
      format = "latex",
      booktabs = TRUE,
      linesep = "",
      digits = 2,
      col.names = label_vec,
      caption = "Results from best fitting participant-specific model on saliva melatonin data when iterating over $\\tau$s; optimal $\\tau$ and $AIC$, as well as calculated circadian parameters listed.",
      label = ifelse(with_harmonics, "tbl_tau_harmonics", "tbl_tau_fundamental"),
      escape = TRUE
    )
  if (with_harmonics) {
    tex_out <- tex_out %>%
      kableExtra::add_header_above(c(
        " " = 4,
        "Fundamental" = 2,
        "2nd harmonic" = 2
      ))
  } else {
    # Fundamental-only layout has 6 columns, so no harmonic spanner here
    tex_out <- tex_out %>%
      kableExtra::add_header_above(c(
        " " = 1,
        "Fit statistics" = 2,
        "Circadian parameters" = 3
      ))
  }
  
  mean_taus <- tau_df %>%
    dplyr::filter(.data$participant_id != 200) %>%
    dplyr::select(dplyr::all_of(names_vec))  %>%
    # Phase columns hold angles, so they need circular statistics: the linear
    # mean of angles straddling +/-pi can fall outside the observed range (the
    # second harmonic phases here do exactly that).
    summarise(across(where(is.numeric),
                     list(
                       mean = ~ if (dplyr::cur_column() %in% c("phase", "phase_2"))
                         circular_mean(.) else mean(.),
                       sd = ~ if (dplyr::cur_column() %in% c("phase", "phase_2"))
                         circular_sd(.) else sd(.)
                     ),
                     .names = "{.col} {.fn}")) %>%
    tidyr::pivot_longer(
      cols = everything(),
      names_to = c("variable", "stat"),
      names_sep = " "
    ) %>%
    tidyr::pivot_wider(names_from = "stat", values_from = "value") %>%
    dplyr::mutate(stat = sprintf("%.2f (%.2f)", mean, sd)) %>%
    dplyr::select(variable, stat) %>%
    t() %>% as.data.frame()
  mean_taus["stat", ][1] <- "$M (SD)$"
  mean_taus <-
    (paste0(
      "\\\\\n\\midrule\n",
      paste(mean_taus["stat", ], collapse = " & "),
      " \\\\\n\\bottomrule\n"
    ))
  
  # Merge last row (with summary stats) with previous row
  tex_out <-
      sub(
        pattern = "\\\\\n\\bottomrule\n",
        replacement = mean_taus,
        x = paste(tex_out),
        fixed = TRUE
      )
  
  # Save table as tex file
  if (!is.null(out_dir)) {
    save_tex(out_string = tex_out,
             out_path = file.path(out_dir, filename))
  }
  return(tex_out)
}

#' Create LaTeX table with descriptive statistics of tau
#'
#' @param tau_path Path to the tau CSV file.
#' @param out_dir Output directory to save the LaTeX table. If `NULL`, the table is not saved.
#'
#' @returns
#' @export
#'
create_tex_tau <- function(tau_path, out_dir = NULL, filename = "tex_tau_stats.tex") {
  tau_df <- readr::read_csv(tau_path, show_col_types = FALSE)
  descriptive_sentence_tau <-
    sprintf(
      "The mean duration of the participant-specific circadian period was estimated at %.2f\\textpm{%.2f} hours, ranging from a duration of %.2f to %.2f hours",
      round(mean(tau_df$tau), 2),
      round(sd(tau_df$tau), 2),
      round(min(tau_df$tau), 2),
      round(max(tau_df$tau), 2)
    )
  if (!is.null(out_dir)) {
    file_path <- file.path(out_dir, filename)
    save_tex(out_string = descriptive_sentence_tau, out_path = file_path)
  }
  return(descriptive_sentence_tau)
}


#' Descriptive statistics tables for temporal contrast sensitivity tasks
#'
#' @param tcs_data_path Path to the TCS data CSV file.
#' @param group_cols Columns to group by in the data frame. Default is `c("condition", "freq")`.
#' @param out_dir Output directory to save the LaTeX table. If `NULL`, the table is not saved.
#'
#' @returns
#' @export
#'
create_tbl_descriptive_tcs <-
  function(tcs_data_path,
           group_cols = c("condition", "freq"),
           out_dir = NULL,
           filename = "tbl_descriptives_tcs.tex") {
    df <- readr::read_csv(tcs_data_path, show_col_types = FALSE)
    
    pid_condition_freq_means <- df %>%
      dplyr::group_by(participant_id, block, condition, freq) %>%
      dplyr::summarise(
        contrast_sensitivity = mean(contrast_sensitivity, na.rm = TRUE),
        .groups = 'drop'
      )
    
    group_condition_freq_mean <- pid_condition_freq_means %>%
      dplyr::group_by_at(group_cols) %>%
      dplyr::summarise(
        # mean_tau = round(mean(.data$tau, na.rm = TRUE),3),
        # sd_tau = round(mean(.data$tau, na.rm = TRUE),3),
        mean_cs = round(mean(.data$contrast_sensitivity, na.rm = TRUE), 3),
        sd_cs = round(sd(.data$contrast_sensitivity, na.rm = TRUE), 3),
        .groups = 'drop'
      ) %>%
      dplyr::mutate(
        condition = dplyr::recode(
          condition,
          'red-green' = 'L-M (red-green)',
          'blue-yellow' = 'S (blue-yellow)',
          'achromatic' = 'L+M+S (luminance)'
        )
      ) 
    
    tex_descriptives <- group_condition_freq_mean %>%
      dplyr::select(condition, freq, mean_cs, sd_cs) %>%
      dplyr::arrange(dplyr::across(dplyr::all_of(group_cols), ~ dplyr::desc(.))) %>%
      kableExtra::kable(
        format = "latex",
        digits = 3,
        linesep = "",
        align = c("lcrr"),
        escape = FALSE,
        booktabs = TRUE,
        col.names = c(
          "Postreceptoral channel",
          "Temporal frequency [Hz]",
          "Mean",
          "Standard deviation"
        ),
        caption = "Descriptive statistics of temporal contrast sensitivity tasks; average contrast sensitivities per colour condition and frequency across participants and time.",
        label = "tbl_descriptives_tcs"
      ) %>%
      kableExtra::add_header_above(c(" " = 2, "Temporal contrast sensitivity" = 2)) %>%
      kableExtra::collapse_rows(
        columns = 1:4,
        latex_hline = "major",
        row_group_label_position = "first"
      )
    
    if (!(is.null(out_dir))) {
      save_tex(
        out_string = tex_descriptives,
        out_path = file.path(out_dir, filename)
      )
    }
    
    return(tex_descriptives)
  }

#' Table with number of tests per participant, block, and condition
#'
#' @param tcs_data_path Path to the TCS data CSV file.
#' @param out_dir Output directory to save the LaTeX table. If `NULL`, the table is not saved.
#'
#' @returns 
#' @export
#'
create_tbl_describtive_ntcstest <- function(tcs_data_path, out_dir = NULL, filename = "tbl_descriptives_ntcstests.tex") {
  df <- readr::read_csv(tcs_data_path, show_col_types = FALSE)
  # Count tests per participant, block, and condition
  test_counts <- df %>%
    # Sort by participant_id
    dplyr::arrange(participant_id, block, condition) %>%
    dplyr::filter(freq == 8) %>%
    dplyr::group_by(participant_id, block, condition) %>%
    dplyr::summarise(count = n(),
                     .groups = 'drop') %>%
    # Recode condition names if desired (optional)
    dplyr::mutate(
      condition = dplyr::recode(
        condition,
        'red-green' = 'L-M (red-green)',
        'blue-yellow' = 'S (blue-yellow)',
        'achromatic' = 'L+M+S (luminance)'
      )
    )
  # Create wide format with conditions as columns for easier viewing
  test_counts_wide <- test_counts %>%
    tidyr::pivot_wider(
      id_cols = c(participant_id, block),
      names_from = condition,
      values_from = count,
      values_fill = 0  # Fill NA values with 0
    ) %>%
    # Add a total column for all tests in a block
    dplyr::mutate(total_tests = `L-M (red-green)` + `S (blue-yellow)` + `L+M+S (luminance)`) %>%
    dplyr::arrange(participant_id, block)
  
  # Filter rows where at least one condition column is not equal to 3
  filtered_counts_wide <- test_counts_wide %>%
    dplyr::filter(`L-M (red-green)` != 3 |
                    `S (blue-yellow)` != 3 |
                    `L+M+S (luminance)` != 3) %>%
    # Sort by total_tests in ascending order
    dplyr::arrange(total_tests) %>% 
    # Reorder columns for LaTeX table
    dplyr::select(total_tests, participant_id, block, `L-M (red-green)`, `S (blue-yellow)`, `L+M+S (luminance)`)
  
  tex_tbl_ntcs_tests <- filtered_counts_wide %>%
    kableExtra::kable(
      format = "latex",
      linesep = "",
      align = c("rcrrrr"),
      escape = FALSE,
      booktabs = TRUE,
      col.names = c(
        "$N_{\\text{Tests}}$",
        "Participant ID",
        "Experimental Block",
        "L+M+S (luminance)", "S (blue-yellow)", "L-M (red-green)"
      ),
      caption = paste0("Deviations in test count for temporal contrast sensitivity in each colour direction. ", 
                       "Each participant needed to complete three tests per colour direction per block. ", 
                       "Table only contains test count per participant per experimental blocks, ", 
                       "when there were either more or less than three tests in at least one colour direction."),
      caption.above = FALSE,
      label = "tbl_descriptives_ntcstests"
    ) %>%
    kableExtra::kable_styling(latex_options = "hold_position") %>% 
    kableExtra::add_header_above(c(" " = 3, "Postreceptoral mechanism" = 3)) %>%
    kableExtra::collapse_rows(
      columns = 1,
      latex_hline = "major",
      row_group_label_position = "first"
    )
  
  if (!(is.null(out_dir))) {
    save_tex(
      out_string = tex_tbl_ntcs_tests,
      out_path = file.path(out_dir, filename)
    )
  }
  return(tex_tbl_ntcs_tests)
}


#' Create LaTeX table summarizing model estimation results
#'
#' @param model_summary_filepath Path to the model summary CSV file.
#' @param out_dir Output directory to save the LaTeX table. If `NULL`, the table is not saved.
#'
#' @returns
#' @export
#'
create_tbl_model_summary <-
  function(model_summary_filepath, out_dir = NULL) {
    # Make LaTeX table
    lookup_table <- data.frame(
      model_name = c(
        "red-green_8",
        "red-green_2",
        "achromatic_8",
        "achromatic_2",
        "blue-yellow_8",
        "blue-yellow_2"
      ),
      label = c(
        "\\rg{high}",
        "\\rg{low}",
        "\\ach{high}",
        "\\ach{low}",
        "\\by{high}",
        "\\by{low}"
      )
    )
    
    model_df <- readr::read_csv(file = model_summary_filepath, show_col_types = FALSE)
    model_name <-
      strsplit(strsplit(basename(model_summary_filepath), "__")[[1]][2], "\\.")[[1]][1]
    if (is.na(model_name)) {
      stop(
        "Filepath does not contain any model name information of type: omdel_summary__'<colour-condition>_<frequencey>.csv'\n"
      )
    }
    model_label <-
      lookup_table[lookup_table$model_name == model_name, "label"]
    tex_out <- model_df %>%
      dplyr::mutate(
        Predictor = case_when(
          Predictor == "b_Intercept" ~ "Intercept",
          Predictor == "b_sine_component" ~ "$\\alpha$",
          Predictor == "b_cosine_component" ~ "$\\beta$",
          Predictor == "sd_participant_id__Intercept" ~ "SD(Intercept)",
          Predictor == "sd_participant_id__sine_component" ~ "SD($\\alpha$)",
          Predictor == "sd_participant_id__cosine_component" ~ "SD($\\beta$)",
          Predictor == "cor_participant_id__Intercept__sine_component" ~ "$\\rho(\\text{Intercept},\\alpha)$",
          Predictor == "cor_participant_id__Intercept__cosine_component" ~ "$\\rho(\\text{Intercept},\\beta)$",
          Predictor == "cor_participant_id__sine_component__cosine_component" ~ "$\\rho(\\alpha, \\beta)$",
          Predictor == "n_obs" ~ "$N_{\\text{Observations}}$",
          Predictor == "n_cluster" ~ "$N_{\\text{Clusters}}$",
          Predictor == "BF" ~ "%$BF$",
          Predictor == "\\ac{logbf}" ~ "\\ac{logbf}",
          Predictor == "conditional_r2" ~ "Conditional $R^2$",
          Predictor == "marginal_r2" ~ "Marginal $R^2$",
          Predictor == "Amplitude" ~ "Amplitude",
          Predictor == "Phase" ~ "Phase"
        )
      ) %>%
      kableExtra::kable(
        format = "latex",
        booktabs = TRUE,
        col.names = c(
          "\\textit{Predictor}",
          "\\textit{Estimate}",
          "\\textit{2.5\\%}",
          "\\textit{97.5\\%}",
          "\\textit{Estimate}",
          "\\textit{2.5\\%}",
          "\\textit{97.5\\%}"
        ),
        align = c('l', rep('r', 7)),
        digits = 3,
        escape = FALSE,
        #italic = TRUE,
        na = " ",
        linesep = c(
          "",
          "",
          "",
          "",
          "",
          "",
          "",
          "",
          "\\addlinespace[0.3em]",
          "",
          "",
          "",
          "\\addlinespace[0.3em]",
          "",
          "\\addlinespace[0.3em]"
        ),
        caption = sprintf("Summary of model estimation for model %s.", model_label),
        label = paste0("tbl_", model_name)
      ) %>%
      kableExtra::add_header_above(c(
        " " = 2,
        "$CI$" = 2,
        " " = 1,
        "$CI$" = 2
      ), escape = FALSE) %>%
      kableExtra::pack_rows("Fixed effects", 1, 3) %>%
      kableExtra::pack_rows("Random effects", 4, 9) %>%
      kableExtra::row_spec(9, extra_latex_after = "\\midrule")# %>%
    # kableExtra::kable_styling(full_width = TRUE) %>%
    # kableExtra::footnote(general = "$R^2$ is residual based; conditional means conditioned on the random effects, while marginal is based on fixed effects only.", escape = FALSE)
    
    tex_out <- gsub("NA", "", tex_out)
    
    filename <- sprintf("tbl_model_summary__%s.tex", model_name)
    if (!is.null(out_dir)) {
      save_tex(out_string = tex_out,
               out_path = file.path(out_dir, filename))
    }
    return(tex_out)
  }


#' Create LaTeX table with descriptive statistics of temporal contrast sensitivity tasks
#'
#' @param tcs_data_path Path to the TCS data CSV file.
#' @param group_cols Columns to group by in the data frame. Default is `c("condition", "freq")`.
#' @param out_dir Output directory to save the LaTeX table. If `NULL`, the table is not saved.
#'
#' @returns
#' @export 
#' 
create_tbl_descriptive_tcs <-
  function(tcs_data_path,
           group_cols = c("condition", "freq"),
           out_dir = NULL) {
    df <- readr::read_csv(tcs_data_path, show_col_types = FALSE)
    tex_descriptives <- df %>%
      dplyr::group_by_at(group_cols) %>%
      dplyr::summarise(
        # mean_tau = round(mean(.data$tau, na.rm = TRUE),3),
        # sd_tau = round(mean(.data$tau, na.rm = TRUE),3),
        mean_cs = round(mean(.data$contrast_sensitivity, na.rm = TRUE), 3),
        sd_cs = round(sd(.data$contrast_sensitivity, na.rm = TRUE), 3),
        .groups = 'drop'
      ) %>%
      dplyr::mutate(
        condition = dplyr::recode(
          condition,
          'red-green' = 'L-M (red-green)',
          'blue-yellow' = 'S (blue-yellow)',
          'achromatic' = 'L+M+S (luminance)'
        )
      ) %>%
      dplyr::select(condition, freq, mean_cs, sd_cs) %>%
      dplyr::arrange(dplyr::across(dplyr::all_of(group_cols), ~ dplyr::desc(.))) %>%
      kableExtra::kable(
        format = "latex",
        digits = 3,
        linesep = "",
        align = c("lcrr"),
        escape = FALSE,
        booktabs = TRUE,
        col.names = c(
          "Postreceptoral channel",
          "Temporal frequency [Hz]",
          "Mean",
          "Standard deviation"
        ),
        caption = "Descriptive statistics of temporal contrast sensitivity tasks; average contrast sensitivities per colour condition and frequency across participants and time.",
        label = "tbl_descriptives_tcs"
      ) %>%
      kableExtra::add_header_above(c(" " = 2, "Temporal contrast sensitivity" = 2)) %>%
      kableExtra::collapse_rows(
        columns = 1:4,
        latex_hline = "major",
        row_group_label_position = "first"
      )
    
    if (!(is.null(out_dir))) {
      save_tex(
        out_string = tex_descriptives,
        out_path = file.path(out_dir, "tbl_descriptives_tcs.tex")
      )
    }
    
    return(tex_descriptives)
  }


#' Create LaTeX table summarizing model estimation results
#'
#' @param model_summary_filepath Path to the model summary CSV file.
#' @param out_dir Output directory to save the LaTeX table. If `NULL`, the table is not saved.
#'
#' @returns
#' @export
#'
create_tbl_model_summary2 <-
  function(model_summary_filepath, out_dir = NULL) {
    # Make LaTeX table
    lookup_table <- data.frame(
      model_name = c(
        "red-green_8",
        "red-green_2",
        "achromatic_8",
        "achromatic_2",
        "blue-yellow_8",
        "blue-yellow_2"
      ),
      label = c(
        "\\rg{high}",
        "\\rg{low}",
        "\\ach{high}",
        "\\ach{low}",
        "\\by{high}",
        "\\by{low}"
      )
    )
    

    if (!file.exists(model_summary_filepath)) {
      stop(sprintf("Model summary file does not exist: %s", model_summary_filepath))
    }
    model_df <- readr::read_csv(model_summary_filepath, show_col_types = FALSE)
    #print(model_df)
    model_name <-
      strsplit(strsplit(basename(model_summary_filepath), "__")[[1]][2], "\\.")[[1]][1]
    if (is.na(model_name)) {
      stop(
        "Filepath does not contain any model name information of type: omdel_summary__'<colour-condition>_<frequencey>.csv'\n"
      )
    }
    model_label <-
      lookup_table[lookup_table$model_name == model_name, "label"]
    tex_out <- model_df %>%
      dplyr::mutate(
        Predictor = case_when(
          Predictor == "b_Intercept" ~ "Intercept",
          Predictor == "b_sine_component" ~ "$\\alpha$",
          Predictor == "b_cosine_component" ~ "$\\beta$",
          Predictor == "sd_participant_id__Intercept" ~ "SD(Intercept)",
          Predictor == "sd_participant_id__sine_component" ~ "SD($\\alpha$)",
          Predictor == "sd_participant_id__cosine_component" ~ "SD($\\beta$)",
          Predictor == "cor_participant_id__Intercept__sine_component" ~ "$\\rho(\\text{Intercept},\\alpha)$",
          Predictor == "cor_participant_id__Intercept__cosine_component" ~ "$\\rho(\\text{Intercept},\\beta)$",
          Predictor == "cor_participant_id__sine_component__cosine_component" ~ "$\\rho(\\alpha, \\beta)$",
          Predictor == "n_obs" ~ "$N_\\text{Observations}$",
          Predictor == "n_cluster" ~ "$N_\\text{Clusters}$",
          Predictor == "BF" ~ "$BF$",
          Predictor == "ln(BF)" ~ "$ln(BF)$",
          Predictor == "conditional_r2" ~ "Conditional $R^2$",
          Predictor == "marginal_r2" ~ "Marginal $R^2$",
          Predictor == "Amplitude" ~ "Amplitude",
          Predictor == "Phase" ~ "Phase"
        )
      ) %>%
      kableExtra::kable(
        format = "latex",
        booktabs = TRUE,
        col.names = c(
          "\\textit{Predictor}",
          "\\textit{Estimate}",
          "\\textit{2.5\\%}",
          "\\textit{97.5\\%}",
          "\\textit{Estimate}",
          "\\textit{2.5\\%}",
          "\\textit{97.5\\%}"
        ),
        align = c('l', rep('r', 7)),
        digits = 3,
        escape = FALSE,
        #italic = TRUE,
        na = " ",
        linesep = c(
          "",
          "",
          "",
          "",
          "",
          "",
          "",
          "",
          "\\addlinespace[0.3em]",
          "",
          "",
          "",
          "\\addlinespace[0.3em]",
          "",
          "\\addlinespace[0.3em]"
        ),
        caption = sprintf("Summary of model estimation for model %s.", model_label),
        label = paste0("tbl_", model_name)
      ) %>%
      kableExtra::add_header_above(c(
        " " = 2,
        "$CI$" = 2,
        " " = 1,
        "$CI$" = 2
      ), escape = FALSE) %>%
      kableExtra::pack_rows("Fixed effects", 1, 3) %>%
      kableExtra::pack_rows("Random effects", 4, 9) %>%
      kableExtra::row_spec(9, extra_latex_after = "\\midrule")# %>%
    # kableExtra::kable_styling(full_width = TRUE) %>%
    # kableExtra::footnote(general = "$R^2$ is residual based; conditional means conditioned on the random effects, while marginal is based on fixed effects only.", escape = FALSE)
    
    tex_out <- gsub("NA", "", tex_out)
    
    filename <- sprintf("tbl_model_summary__%s.tex", model_name)
    if (!is.null(out_dir)) {
      save_tex(out_string = tex_out,
               out_path = file.path(out_dir, filename))
    }
    return(tex_out)
  }


#'  Create LaTeX table with fitted sine and cosine parameters from TCS models
#'
#' @param params_df_path Path to the CSV file containing fitted parameters.
#' @param out_dir Output directory to save the LaTeX table. If `NULL`, the table is not saved.
#'
#' @returns
#' @export
#'
#' @examples
create_tbl_fitted_parameters <- function(params_df_path, out_dir=NULL) {
  df <- options(readr.num_columns = 0)
  df <- readr::read_csv(params_df_path, show_col_types = FALSE)
  
  # Create df
  df_out <- df %>% dplyr::select(c(
    "condition",
    "freq",
    "group",
    "intercept",
    "amplitude",
    "phase",
    "participant_id",
    "intercept_p",
    "amplitude_p",
    "phase_p")
  ) %>% 
    dplyr::mutate(
      condition = dplyr::recode(
        condition,
        'red-green' = 'L-M (red-green)',
        'blue-yellow' = 'S (blue-yellow)',
        'achromatic' = 'L+M+S (luminance)'
      )
    ) %>%
    #dplyr::mutate(condition = stringr::str_to_title(condition)) %>% 
    dplyr::mutate(across(c(4, 5, 6, 8, 9, 10), ~ round(., 3))) 
  
  # Create tex from 
  tex_out <- df_out %>%
    kableExtra::kable(
      format = "latex",
      booktabs = TRUE,
      col.names = c(
        "Postreceptoral mechanism",
        "Temporal frequency [Hz]",
        "Model",
        "Mesor",
        "Amplitude",
        "Phase",
        "Participant",
        "Intercept",
        "Amplitude",
        "Phase"
      ),
      caption = "Average and participant-wise mesor, amplitude and phase based on participant-specific periods.",
      label = "tbl_fitted_circadian_parameters",
      escape = TRUE
    ) %>%
    kableExtra::add_header_above(c(
      " " = 3,
      "Fixed effects outcomes" = 3,
      " " = 1,
      "Random effects outcomes" = 3
    )) %>%
    kableExtra::collapse_rows(
      columns = 1:6,
      latex_hline = "major",
      row_group_label_position = "first"
    ) %>% 
    stringr::str_replace_all(pattern=c(
      "red-green\\\\_8" = "\\\\rg{high}",
      "red-green\\\\_2 " = "\\\\rg{low} ",
      "achromatic\\\\_8" = "\\\\ach{high}",
      "achromatic\\\\_2" = "\\\\ach{low}",
      "blue-yellow\\\\_8" = "\\\\by{high}",
      "blue-yellow\\\\_2" = "\\\\by{low}"
    ))
  
  body_tex_out <- stringr::str_extract(tex_out, "(?s)(?<=Phase\\\\\\\\\n\\\\midrule)(.*?)(?=\\\\bottomrule)")
  
  if (!is.null(out_dir)){
    filename <- sub('\\.csv$', '', basename(params_df_path))
    save_tex(
      out_string = tex_out,
      out_path = file.path(out_dir, paste0("tbl_", filename, ".tex")) #"fitted_tcs_all_parameters.tex")
    )
    save_tex(
      out_string = body_tex_out,
      out_path = file.path(out_dir, paste0("tbl_", filename, "_body.tex")) #"fitted_tcs_all_parameters_body.tex")
    )
    #cat(env_tbl_fitted_parameters, file=file.path(out_dir, "tbl_fitted_circadian_parameters_env.tex"))
    save_tex(
      out_string = "Insert the body in the table environment that is already in the latex files. Comments indicate the place of insertion.",
      out_path = file.path(out_dir, paste0("tbl_", filename, "_meta.tex")) #"fitted_tcs_all_parameters_meta.tex")
    )
    warning("Insert the body in the table environment that is already in the latex files. Comments indicate the place of insertion.")
  }
  
  
  return(tex_out)
}


#' Main function to generate all report tables for temporal contrast sensitivity tasks
#'
#' @param tau_path Path to the CSV file containing circadian parameters (tau).
#' @param metropsis_result_dir Path to the directory containing fitting results.
#' @param out_dir Subdirectory of reports directory to save the tables. If `NULL`, the tables are not saved.
#'
#' @returns 
#' @export
#'
report_tables_tcs_main <- function(
    tau_path = file.path(DERIVATIVES_DIR, "hormones/tau_harmonics/melatonin_circadian_parameters.csv"),
    metropsis_result_dir = file.path(DERIVATIVES_DIR, "log_tcs/multilevel"),
    tbl_dir = file.path(TABLE_DIR, "log_tcs/multilevel"),
    tex_dir = file.path(TEX_DIR, "log_tcs/multilevel")){
  if (!file.exists(tau_path)) {
    warning(sprintf("File '%s' does not exists.", tau_path))
  }
  
  # Generate hormone output
  tbl_tau <- create_tbl_tau(tau_path = tau_path, out_dir = tbl_dir)
  tex_tau <- create_tex_tau(tau_path = tau_path, out_dir = tex_dir)
  
  # Descriptive statistics tables
  data_path <- file.path(metropsis_result_dir, "input_data.csv")
  tbl_descr_tcs <-
    create_tbl_descriptive_tcs(tcs_data_path = data_path, out_dir = tbl_dir)
  tbl_descr_ntcstest <- create_tbl_describtive_ntcstest(tcs_data_path = data_path, out_dir = tbl_dir) 
  
  # Process model CSVs into TEX tables
  list_model_files <- list.files(path = metropsis_result_dir,
                                 pattern = "^model_summary__.*\\.csv$",
                                 full.names = TRUE)

  for (filepath in list_model_files) {
    sprintf("Filepath: File exists({%s}))", filepath)
    cat("This is a filepath", filepath)
    tbl_model_summary <-
      create_tbl_model_summary(model_summary_filepath = filepath, out_dir = tbl_dir)
  }
  
  # Table with group-level and person-specific circular parameters
  data_path = file.path(metropsis_result_dir, "fitted_all_parameters.csv")
  tbl_fitted_params <-
    create_tbl_fitted_parameters(params_df_path = data_path, out_dir = tbl_dir)
  return(tbl_fitted_params)
}

