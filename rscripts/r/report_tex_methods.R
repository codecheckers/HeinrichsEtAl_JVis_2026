
# Canonical paths (RAW_DIR, TEX_DIR, ...). See ../STRUCTURE.md.
source("./r/paths.R")

#' Process participant data from lab screening as is (no filtering by participation)
#'
#' @param labscreen_path (str) Path to the lab screening CSV file.
#'
#' @returns
#' @export
#'
preprocess_labscreen <- function(labscreen_path) {
  # Show the *guessed* column specification that readr would use
  # spec_guess <- readr::spec_csv(labscreen_path, na = c("", "NA"))
  #spec_guess
  
  custom_col_types <- readr::cols(
    # ---- IDs -------------------------------------------------------------
    record_id               = readr::col_integer(),
    participant_id          = readr::col_integer(),
    med_participant_id      = readr::col_integer(),
    antrop_participant_id   = readr::col_integer(),
    # ---- Dates -----------------------------------------------------------
    demo_dob                = readr::col_date(format = "%Y-%m-%d"),
    # ---- Date‑times ------------------------------------------------------
    med_timestamp           = readr::col_datetime(format = "%Y-%m-%d %H:%M:%S"),
    #, tz = "UTC"),
    med_timestamp_start     = readr::col_datetime(format = "%Y-%m-%d %H:%M:%S"),
    #, tz = "UTC"),
    tests_timestamp         = readr::col_datetime(format = "%Y-%m-%d %H:%M:%S"),
    #, tz = "UTC"),
    antrop_timestamp        = readr::col_datetime(format = "%Y-%m-%d %H:%M:%S"),
    #, tz = "UTC"),
    prep_timestamp          = readr::col_datetime(format = "%Y-%m-%d %H:%M:%S"),
    #, tz = "UTC"),
    prep_timestamp_start    = readr::col_datetime(format = "%Y-%m-%d %H:%M:%S"),
    #, tz = "UTC"),
    # ---- Times ------------------------------------------------------------
    prep_select_sleeptime = readr::col_time(format = ""),
    prep_select_waketime = readr::col_time(format = ""),
    # ---- Categorical ------------------------------------------------------
    #demo_sex               = readr::col_factor(levels = c("M","F")),
    # ---- Characters -------------------------------------------------------
    .default                = readr::col_guess() # safest fallback
  )
  
  df <- readr::read_csv(
    file = labscreen_path,
    na = c("", "NA"),
    show_col_types = FALSE,
    col_types = custom_col_types
  )
  
  
  # Convert timestamp columns to character and then to POSIXct
  df <- df %>%
    dplyr::mutate(
      dplyr::across(
        .cols = dplyr::ends_with("spec", ignore.case = TRUE),
        # any column name with "timestamp"
        .fns  = ~ as.character(.x)
      ),
      dplyr::across(
        .cols = dplyr::matches("timestamp", ignore.case = TRUE),
        # any column name with "timestamp"
        .fns  = ~ as.POSIXct(.x, format = "%Y-%m-%d %H:%M:%S") #, tz = "UTC")
      )
    ) %>%
    dplyr::select(
      # drop all columns starting with "bfi" (questionnaire not used)
      -dplyr::starts_with("bfi", ignore.case = TRUE)
    )
  
  return(df)
}


  #' Clean lab screening data and merge with experimental data from metropsis
#'
#' @param labscreen_path (str) Path to the lab screening CSV file.
#' @param metropsis_path (str) Path to the psychophysical CSV file from metropsis.
#'
#' @returns
#' @export
#'
clean_labscreen_with_metropsis <- function(labscreen_path, metropsis_path) {
  # Read and preprocess lab screening data
  df <- preprocess_labscreen(labscreen_path)
  
  # Read experimental psychophyics metropsis data
  metropsis <- readr::read_csv(
    metropsis_path,
    #col_names = c("participant_id", "condition", "datetime"),
    col_types = readr::cols(
      participant_id = readr::col_integer(),
      datetime = readr::col_datetime(format = "%Y-%m-%d %H:%M:%S")
    )
  )
  
  # Select start date per participant from metropsis data
  pid_experiment_dates <- metropsis %>%
    dplyr::ungroup() %>%
    dplyr::group_by(participant_id) %>%
    dplyr::slice_min(order_by = datetime, n = 1) %>%
    # reduce unique datetimes
    dplyr::distinct(participant_id, datetime) %>%
    # extract date from datetime
    dplyr::mutate(experiment_date = as.Date(datetime)) %>%
    dplyr::select(-datetime)
  # Merge df and metropsis on participant_id
  df <- df %>%
    dplyr::left_join(pid_experiment_dates, by = "participant_id")
  
  # Override age at with calculation based on start of study
  df$demo_age <- as.numeric(difftime(df$experiment_date, df$demo_dob, units = "days")) / 365.25
  
  
  # Select only participants with experimental data
  valid_pid <- sort(unique(metropsis$participant_id))
  df <- df %>%
    filter(participant_id %in% valid_pid)
  return(df)
}



#' Create a LaTeX text file with participant demographics
#'
#' @param labscreen_path (str) Path to the lab screening CSV file.
#' @param metropsis_path (str) Path to the psychophysical CSV file from metropsis.
#' @param tex_dir (str) Directory to save the LaTeX text file.
#'
#' @returns
#' @export
#'
create_tex_methods_sample <- function(labscreen_path = file.path(RAW_DIR, "Civibelabscreening_DATA.csv"),
                                      metropsis_path = file.path(RAW_DIR, "clean_metropsis_TCS-2e.csv"),
                                      tex_dir = file.path(TEX_DIR, "log_tcs/multilevel")){
  
  
  df <- clean_labscreen_with_metropsis(
    labscreen_path = labscreen_path,
    metropsis_path = metropsis_path
  )
  
  n_participants <- length(unique(df$participant_id))
  min_age <- as.integer(min(df$demo_age, na.rm = TRUE))
  max_age <- as.integer(max(df$demo_age, na.rm = TRUE))
  mean_age <- round(mean(df$demo_age, na.rm = TRUE), 2)
  sd_age <- round(sd(df$demo_age, na.rm = TRUE), 2)
  n_female <- sum(df$demo_sex == 1, na.rm=TRUE)
  percentage_female <- (sum(df$demo_sex == 1, na.rm=TRUE) / length(df$participant_id)) * 100
  
  n_oral_contr <- sum(df$demo_sex == 1, na.rm=TRUE)
  
  raw_text = 
    "The final study sample consisted of healthy volunteers ($N$ = {n_participants}) with a mean age of ${mean_age} \\pm {sd_age}$, range of  [${min_age}; {max_age}$] years). 
  The sample included five females (${percentage_female}$\\%), two of whom were on oral contraceptives, while the others had natural menstrual cycles without any hormonal influence. 
  One of the participants had corrected vision; they wore glasses during the experimental session and took them off during visual testing."
  
  formatted_text <- glue::glue(
    raw_text,
    n_participants = n_participants,
    min_age = min_age,
    max_age = max_age,
    mean_age = mean_age,
    sd_age = sd_age,
    #n_female = n_female,
    percentage_female = round(percentage_female, 2)
  )
  
  out_path <-
    file.path(tex_dir, "tex_methods_sample.tex")
  
  save_tex(out_string = formatted_text, out_path = out_path)
  
  return(formatted_text)
}

