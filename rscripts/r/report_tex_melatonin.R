# Canonical paths (RAW_DIR, DERIVATIVES_DIR, TEX_DIR, ...). See ../STRUCTURE.md.
source("./r/paths.R")
source("./r/utils.R")

#' Create LaTeX report with descriptive statistics of melatonin
#'
#' @param data_path Path to the melatonin data CSV file.
#' @param tex_dir Directory where the LaTeX file will be saved.
#'
#' @returns
#' @export
#'
create_tex_descriptive_melatonin <-
  function(data_path = file.path(RAW_DIR, "clean_saliva_data.csv"),
           tex_dir = file.path(TEX_DIR, "log_tcs/multilevel")) {
    df <- readr::read_csv(data_path, show_col_types = FALSE) %>%
      as.data.frame %>%
      dplyr::select(dplyr::all_of(
        c(
          "participant_id",
          "session_id",
          #"block",
          "sample_number",
          "melatonin_concentration",
          "hours_after_wakeup",
          "standard_clocktime",
          "standard_datetime"
        )
      )) %>%
      dplyr::filter(participant_id != 200 & session_id == "FD")
    
    
    # Calculate mel_avg: Average melatonin concentration across participants and time
    mel_avg <- mean(df$melatonin_concentration)
    mel_median <- median(df$melatonin_concentration)
    mel_max <- max(df$melatonin_concentration)
    mel_min <- min(df$melatonin_concentration)
    
    
    # Calculate mel_sd: Standard deviation of melatonin concentration across participants and time
    mel_sd <- sd(df$melatonin_concentration)
    
    # Assuming your dataframe is named 'df'
    # Convert standard_datetime to POSIXct for easier manipulation
    df$standard_datetime <-
      as.POSIXct(df$standard_datetime, tz = "UTC")
    
    # Calculate mel_avg_day_both: Average melatonin concentration across participants from 7am to 8pm both days
    # Assuming 7am to 8pm is from 7:00:00 to 20:00:00
    day_start <- as.POSIXct("2024-01-01 07:00:00", tz = "UTC")
    day_end <- as.POSIXct("2024-01-01 23:00:00", tz = "UTC")
    
    # Filter data for the first day
    day_data_1 <- df %>%
      filter(standard_datetime >= day_start) %>%
      filter(standard_datetime <= day_end)
    print(day_data_1)
    
    # Filter data for the second day
    day_data_2 <- df %>%
      filter(standard_datetime >= day_start + 24 * 60 * 60 &
               standard_datetime <= day_end + 24 * 60 * 60)
    
    # Combine data for both days
    day_data_both <- bind_rows(day_data_1, day_data_2)
    
    # Calculate average melatonin concentration for both days
    mel_avg_day_both <- mean(day_data_both$melatonin_concentration)
    
    # Calculate mel_pid_avg_sd: Standard deviation of the average participant-wise melatonin concentration
    mel_pid_avg_sd <- df %>%
      group_by(participant_id) %>%
      summarize(avg_mel = mean(melatonin_concentration)) %>%
      summarize(sd_avg_mel = sd(avg_mel)) %>%
      pull(sd_avg_mel)
    
    # Calculate mel_pid_max_min: Smallest value (minimum) of the participant-wise maximum
    mel_pid_max_min <- df %>%
      group_by(participant_id) %>%
      summarize(max_mel = max(melatonin_concentration)) %>%
      summarize(min_max_mel = min(max_mel)) %>%
      pull(min_max_mel)
    
    # Calculate pid_pid_max_min: Participant ID with the smallest maximum melatonin concentration
    pid_pid_max_min <- df %>%
      group_by(participant_id) %>%
      summarize(max_mel = max(melatonin_concentration)) %>%
      filter(max_mel == mel_pid_max_min) %>%
      pull(participant_id) %>%
      unique()
    
    # Calculate mel_pid_max_max: Largest value (maximum) of the participant-wise maximum
    mel_pid_max_max <- df %>%
      group_by(participant_id) %>%
      summarize(max_mel = max(melatonin_concentration)) %>%
      summarize(max_max_mel = max(max_mel)) %>%
      pull(max_max_mel)
    
    # Calculate pid_pid_max_max: Participant ID with the largest maximum melatonin concentration
    pid_pid_max_max <- df %>%
      group_by(participant_id) %>%
      summarize(max_mel = max(melatonin_concentration)) %>%
      filter(max_mel == mel_pid_max_max) %>%
      pull(participant_id) %>%
      unique()
    
    # Calculate mel_avg_sample5: Average melatonin concentration at sample 8
    mel_avg_sample5 <- df %>%
      filter(sample_number == 5) %>%
      summarize(avg_mel_sample5 = mean(melatonin_concentration)) %>%
      pull(avg_mel_sample5)
    mel_avg_sample30 <- df %>%
      filter(sample_number == 30) %>%
      summarize(avg_mel_sample30 = mean(melatonin_concentration)) %>%
      pull(avg_mel_sample30)
    
    # Calculate mel_night_both_avg: Average melatonin concentration from -3 hours before habitual bedtime to habitual wake-up across both nights
    # Assuming habitual bedtime is 10:30 PM and habitual wake-up is 7:00 AM
    bedtime_start <- as.POSIXct("2024-01-01 23:0:00", tz = "UTC")
    bedtime_end <- as.POSIXct("2024-01-02 07:00:00", tz = "UTC")
    
    # Filter data for the first night
    night_data_1 <- df %>%
      filter(standard_datetime >= bedtime_start &
               standard_datetime <= bedtime_end)
    
    night_data_1_cut <- df %>%
      filter(standard_datetime >= bedtime_start &
               standard_datetime <= (bedtime_start + 2 * 60 * 60))
    
    # Filter data for the second night
    night_data_2 <- df %>%
      filter(
        standard_datetime >= bedtime_start + 24 * 60 * 60 &
          standard_datetime <= bedtime_end + 24 * 60 * 60
      )
    
    # Combine data for both nights
    night_data_both <- bind_rows(night_data_1, night_data_2)
    
    # Calculate average melatonin concentration for both nights
    mel_night_both_avg <-
      mean(night_data_both$melatonin_concentration)
    
    # Calculate mel_night_both_sd: Standard deviation of melatonin concentration from -3 hours before habitual bedtime to habitual wake-up across both nights
    mel_night_both_sd <- sd(night_data_both$melatonin_concentration)
    
    # Calculate mel_night_1_avg: Average melatonin concentration during the first night
    mel_night_1_avg <- mean(night_data_1_cut$melatonin_concentration)
    
    # Calculate mel_night_1_sd: Standard deviation of melatonin concentration during the first night
    mel_night_1_sd <- sd(night_data_1_cut$melatonin_concentration)
    
    # Calculate mel_night_2_avg: Average melatonin concentration during the second night
    mel_night_2_avg <- mean(night_data_2$melatonin_concentration)
    
    # Calculate mel_night_2_sd: Standard deviation of melatonin concentration during the second night
    mel_night_2_sd <- sd(night_data_2$melatonin_concentration)
    
    # Calculate participant-wise statistics
    pid_stats <- df %>%
      group_by(participant_id) %>%
      summarize(
        avg_mel = mean(melatonin_concentration),
        sd_mel = sd(melatonin_concentration),
        min_mel = min(melatonin_concentration),
        max_mel = max(melatonin_concentration),
        range_mel = max_mel - min_mel
      )
    
    # Calculate mel_pid_avg_avg: Average of the average participant-wise melatonin concentration
    mel_pid_avg_avg <- mean(pid_stats$avg_mel)
    
    # Calculate mel_pid_avg_sd: Average of the average participant-wise melatonin concentration
    mel_pid_avg_sd <- sd(pid_stats$avg_mel)
    
    # Average participant-wise melatonin range
    mel_pid_range_avg <- mean(pid_stats$range_mel)
    mel_pid_range_sd <- sd(pid_stats$range_mel)
    
    # Maximal participant-wise melatonin range
    mel_pid_range_max <- max(pid_stats$range_mel)
    
    # Minimal participant-wise melatonin range
    mel_pid_range_min <- min(pid_stats$range_mel)
    
    # Maximal and minimal participant-wise melatonin minimum
    mel_pid_min_max <- max(pid_stats$min_mel)
    mel_pid_min_min <- min(pid_stats$min_mel[pid_stats$min_mel > 0])
    
    # Maximal and minimal participant-wise melatonin range
    mel_pid_range_max <-
      pid_stats[pid_stats$range_mel == max(pid_stats$range_mel), "range_mel"]
    pid_pid_range_max <-
      pid_stats[pid_stats$range_mel == max(pid_stats$range_mel), "participant_id"]
    mel_pid_range_min <-
      pid_stats[pid_stats$range_mel == min(pid_stats$range_mel), "range_mel"]
    pid_pid_range_min <-
      pid_stats[pid_stats$range_mel == min(pid_stats$range_mel), "participant_id"]
    
    # List of participants with non-zero melatonin minima
    non_zero_min_participants <- pid_stats %>%
      filter(min_mel > 0) %>%
      pull(participant_id)
    n_pid_non_zero_min <- length(non_zero_min_participants)
    n_pid <- length(unique(pid_stats$participant_id))
    
    
    # Create the LaTeX text template with placeholders and escape characters:
    raw_tex <- "
\\subsubsection{{Salivary melatonin concentrations}}

Salivary melatonin concentration levels in our study were ranging between ${mel_min}$ and ${mel_max}$ \\ac{{pgml}}.
% Distributions
The overall average melatonin concentration is ${mel_avg}\\pm{mel_sd}$ \\ac{{pgml}}, median concentration was markedly at a level of ${mel_median}$ \\ac{{pgml}}. The difference between mean and median suggests a non-normal distribution of overall melatonin levels.
Indeed, the distribution of concentration levels across time and all participants for salivary melatonin is a zero-inflated distribution, see Figure~\\ref{{fig:img_melatonin_overview_figure}}.

\\paragraph{{Individual and group dynamic in melatonin concentration}}
Onset of melatonin secretion as well as concentration peaks vary between participants, as can be seen in participant-specific plots in Figure~\\ref{{fig:fig_psychophysics_individual}}, panels C and D.
%\\ref{{fig:fig_timecourses_individual_a}} and Figure~\\ref{{fig:fig_timecourses_individual_b}}.
%The average melatonin profile across participants in Figure~\\ref{{fig:fig_average_tcs_melatonin}}B, is informative about the nature melatonin values in our sample giving rise to this distribution: 
The average melatonin profile plotted in Figure~\\ref{{fig:fig_average_tcs_melatonin}}B reflect time-restricted melatonin secretion: across the sample, there are consistently low or null concentration values during habitual daytime, with small standard deviation.
For {(n_pid - n_pid_non_zero_min)} participants, at some point during the day, salivary melatonin concentration did not exceed the detection threshold, as indicated by zero values; 
for the other {n_pid_non_zero_min} participants the individual minimum salivary melatonin levels does not fall below {mel_pid_min_min} and {mel_pid_min_max} \\ac{{pgml}}.
There is a broad peak in concentration levels starting a few hours before habitual bedtime, extending across the night, and dropping before habitual wake time. Daytime levels re-establish shortly after habitual wake time.

% Dynamics throughout study - daytime
The dynamics of individual salivary melatonin levels throughout the study protocol are visually consistent with the average melatonin profile: 
For all participants, melatonin concentrations intially decrease as the protocol starts one hour after after the habitual wake up.
Thereafter, the participant-specific melatonin profiles all exhibit low levels during subjective daytime, 
dropping close to zero with an average of ${mel_avg_sample5}$ \\ac{{pgml}} by the start of the second cycle (approx. 3.5 hours after wake-up) and an average daytime value 
(defined as time between habitual wake-up and habitual bedtime) of ${mel_avg_day_both}$ \\ac{{pgml}.
A similar drop can be seen in the until the seventh experimental block (mean concentration of ${mel_avg_sample30}$ \\ac{{pgml}}) which again corresponds to 3.5 hours after habitual wake time.

% Dynamics throughout stud - nighttime  
At subjective nighttime, average melatonin levels rise to an average of ${mel_night_both_avg}\\pm{mel_night_both_sd}$ \\ac{{pgml}} for the time between habitual bedtime and habitual wake-up.
Note, that habitual daytime and habitual nighttime refer to pre-session stabilization and do not reflect the sleep-wake or rest-activity behaviour during the experiment, which takes place on a 3.75-hour rhythm (corresponding to the duration of a experimental block). % Visually, neither in the participant-specific plots nor in the average melatonin concentration levels.
The course of concentration levels for the second night is cut off at 2 hour after habitual bedtime during the second night, peak concentration levels do not seem to differ greatly between the first and second habitual nighttime; 
the average concentration in the beginning of the first night is ${mel_night_1_avg}\\pm{mel_night_1_sd}$ \\ac{{pgml}} while the average concentration at the beginning of the second night is ${mel_night_2_avg}\\pm{mel_night_2_sd}$ \\ac{{pgml}}.

\\paragraph{{Inter-individual variability in melatonin profiles}}
% There is visible inter-individual variability in the melatonin profiles. 
Participants differed in their average concentration (${mel_pid_avg_avg}\\pm{mel_pid_avg_sd}$ \\ac{{pgml}}) likely reflecting differences in the range of melatonin secretion,
peak levels, or duration of melatonin secretion (i.e. elevated salivary melatonin levels).

All participants exhibited time-dependent variation in their melatonin profiles with discernible peaks. The highest peak occurred in participant ${pid_pid_max_max} (${mel_pid_max_max} \\ac{{pgml}}) and 
was sixfold higher than the lowest peak observed in participant ${pid_pid_max_min} (${mel_pid_max_min} \\ac{{pgml}}).
Accordingly, the within-subject range (maximum - minimum) also varied across participants (mean ${mel_pid_range_avg}\\pm{mel_pid_range_sd}$ \\ac{{pgml}}).
% Participant ${pid_pid_range_min}$ exhibited the smalles range of salivary melatonin concentration, ${mel_pid_range_min}$ \\ac{{pgml}}, and participant ${pid_pid_range_max}$ the maximal range of ${mel_pid_range_max}$ \\ac{{pgml}}.
% compare also Figure \\ref{{fig:fig_hormone_polar_plot}}B.
"
    
    # Replace placeholders:
    formatted_text <- glue::glue(
      raw_tex,
      mel_min = roundsci(mel_min),
      mel_max = roundsci(mel_max),
      mel_avg = roundsci(mel_avg),
      mel_median = roundsci(mel_median),
      mel_sd = roundsci(mel_sd),
      mel_avg_sample5 = roundsci(mel_avg_sample5),
      mel_avg_sample30 = roundsci(mel_avg_sample30),
      mel_avg_day_both = roundsci(mel_avg_day_both),
      mel_night_both_avg = roundsci(mel_night_both_avg),
      mel_night_both_sd = roundsci(mel_night_both_sd),
      mel_night_1_avg = roundsci(mel_night_1_avg),
      mel_night_1_sd = roundsci(mel_night_1_sd),
      mel_night_2_avg = roundsci(mel_night_2_avg),
      mel_night_2_sd = roundsci(mel_night_2_sd),
      mel_pid_avg_avg = roundsci(mel_pid_avg_avg),
      mel_pid_avg_sd = roundsci(mel_pid_avg_sd),
      mel_pid_max_min = roundsci(mel_pid_max_min),
      mel_pid_max_max = roundsci(mel_pid_max_max),
      pid_pid_max_min = pid_pid_max_min,
      pid_pid_max_max = pid_pid_max_max,
      mel_pid_min_max = roundsci(mel_pid_min_max),
      mel_pid_min_min = roundsci(mel_pid_min_min),
      mel_pid_range_avg = roundsci(mel_pid_range_avg),
      mel_pid_range_sd = roundsci(mel_pid_range_sd),
      mel_pid_range_max = roundsci(mel_pid_range_max),
      pid_pid_range_max = pid_pid_range_max,
      mel_pid_range_min = roundsci(mel_pid_range_min),
      pid_pid_range_min = pid_pid_range_min,
      n_pid_non_zero_min = n_pid_non_zero_min,
      n_pid = n_pid
    )
    
    # Export the text to a .tex file
    if (dir.exists(tex_dir)) {
      #tex_dir <- "./reports/log_tcs/multilevel/reports/tex"
      save_tex(
        out_string = formatted_text,
        out_path = file.path(tex_dir, "tex_descriptives_melatonin.tex")
      )
      
      #dir.exists(dirname(out_path))
      #cat(formatted_text, file = out_path)
      #cat(paste("File saved in: ", out_path))
    } else {
      print(paste("Directory does not exist.\n", sep=" "))
      cat(formatted_text)
    }
    
    # Return text
    return(formatted_text)
  }

#' Create LaTeX report with inference results of melatonin
#'
#' @param parameter_path Path to the circadian melatonin parameters CSV file.
#' @param input_path Path to the input data CSV file.
#' @param tex_dir Directory where the LaTeX file will be saved.
#'
#' @returns
#' @export
#'
create_tex_inference_melatonin <-
  function(parameter_path = file.path(DERIVATIVES_DIR, "hormones/tau_harmonics/melatonin_circadian_parameters.csv"),
           raw_path = file.path(RAW_DIR, "clean_saliva_data.csv"),
           tex_dir = file.path(TEX_DIR, "log_tcs/multilevel")) {
    fitdf <- readr::read_csv(parameter_path, show_col_types = FALSE) %>%
      as.data.frame %>%
      dplyr::filter(participant_id != 200)
    meldf <- readr::read_csv(raw_path) %>%
      as.data.frame %>%
      dplyr::select(dplyr::all_of(
        c(
          "participant_id",
          "session_id",
          #"block",
          "sample_number",
          "timestamp_number",
          "melatonin_concentration",
          "hours_after_wakeup",
          "standard_clocktime",
          "standard_datetime"
        )
      )) %>% 
      dplyr::filter(participant_id != 200 & session_id == "FD") %>% 
      dplyr::group_by(participant_id) %>%
      dplyr::summarize(
        avg_mel = mean(melatonin_concentration),
        sd_mel = sd(melatonin_concentration),
        min_mel = min(melatonin_concentration),
        max_mel = max(melatonin_concentration),
        range_mel = max_mel - min_mel
      )
    df <- merge(fitdf, meldf, by="participant_id") %>% 
      dplyr::select(participant_id, aic, mesor, tau, max_mel, avg_mel, range_mel, mesor, amplitude, phase, amplitude_2, phase_2)
    
    # Assuming your dataframe is named 'df'
    # Calculate tau_mean and tau_sd
    tau_mean <- mean(df$tau)
    tau_sd <- sd(df$tau)
    
    # Calculate tau_min and tau_max
    tau_min <- min(df$tau)
    tau_max <- max(df$tau)
    
    # Find participant IDs with tau_min and tau_max
    pid_tau_min <- df %>%
      filter(tau == tau_min) %>%
      pull(participant_id) %>%
      unique()
    
    pid_tau_max <- df %>%
      filter(tau == tau_max) %>%
      pull(participant_id) %>%
      unique()
    
    tau_201 <- df %>%
      filter(participant_id == 201) %>%
      pull(tau)
    
    # Calculate tau_aic_mean
    tau_aic_mean <- mean(df$aic)
    
    # Calculate amplitude_fund_mean, amplitude_fund_sd, amplitude_fund_min, amplitude_fund_max
    amplitude_fund_mean <- mean(df$amplitude)
    amplitude_fund_sd <- sd(df$amplitude)
    amplitude_fund_min <- min(df$amplitude)
    amplitude_fund_max <- max(df$amplitude)
    
    # Calculate phases of fundamental.
    # Phases are angles, so summarise them circularly: the arithmetic mean of
    # angles straddling a branch cut can fall outside the observed range. min/max
    # are taken after wrapping onto the branch centred on the circular mean, so
    # the reported range is not split by an arbitrary cut at 0 or +/-pi.
    phase_fund_mean <- circular_mean(df$phase)
    phase_fund_sd <- circular_sd(df$phase)
    phase_fund_range <- circular_range(df$phase)
    phase_fund_min <- phase_fund_range[["min"]]
    phase_fund_max <- phase_fund_range[["max"]]

    # Time of peak, in hours after wakeup (the time origin the models were fitted
    # on). Converted per participant with their own tau, then summarised: tau is
    # participant-specific, so a single summarised phase cannot be converted.
    peak_fund <- phase_to_decimal_time(theta = df$phase, tau = df$tau, harmonic = 1)
    peak_fund_mean <- mean(peak_fund)
    peak_fund_min <- min(peak_fund)
    peak_fund_max <- max(peak_fund)
    # An SD is a spread, not a position, so it scales without the peak's sign flip
    peak_fund_sd <- radians_to_hours(phase_fund_sd, tau = mean(df$tau))

    # Calculate amplitude_harm_mean, amplitude_harm_sd, amplitude_harm_min, amplitude_harm_max
    amplitude_harm_mean <- mean(df$amplitude_2)
    amplitude_harm_sd <- sd(df$amplitude_2)
    amplitude_harm_min <- min(df$amplitude_2)
    amplitude_harm_max <- max(df$amplitude_2)
    
    # Calculate phase_harm_mean, phase_harm_sd, phase_harm_min, phase_harm_max.
    # Summarised circularly: these phases straddle +/-pi, so the arithmetic mean
    # is not meaningful for them (it lands outside the observed range).
    phase_harm_mean <- circular_mean(df$phase_2)
    phase_harm_sd <- circular_sd(df$phase_2)
    phase_harm_range <- circular_range(df$phase_2)
    phase_harm_min <- phase_harm_range[["min"]]
    phase_harm_max <- phase_harm_range[["max"]]

    
    format_scientific_latex <- function(num) {
      sci <- formatC(num, format = "e", digits = 3)
      parts <- strsplit(sci, "e")[[1]]
      coef <- as.numeric(parts[1])
      exp <- as.numeric(parts[2])
      return(sprintf("%.2f \\times 10^{%d}", round(coef,2), exp))  # LaTeX format
    }
    fund_freq_201 = 1/(tau_201*60*60) #round(1/(tau_201*60*60),2), 
    harm_freq_201 = 2/(tau_201*60*60) #round(2/(tau_201*60*60),2), 
    
    
    raw_text <- "
\\subsubsection{{First-stage model fitting of melatonin data}}

% Overview
There is between-participant variability in maximum levels and overall volume of salivary melatonin and, 
to some extent, also timing of salivary melatonin secretion across the day, suggesting that dynamics can 
be described by a circular process with participant-specific amplitude and phase.
Due to the zero-inflated distribution of the concentration values, we refitted a multi-harmonic model with 
the different fundamental frequencies and the respective second harmonic as described 
in section~\\nameref{{sec:statistical_analysis}}. 

\\paragraph{{Melatonin derived circadian period}}
Optimal fundamental frequency $1/\\tau$ was determined by a grid search across different fundamental frequencies, 
maximizing model fit as indicated by the Akaike Information Criterion ($AIC$). 
The mean $AIC$ for all identified participant-specific models is ${tau_aic_mean}$.
For visualisation, Figure~\\ref{{si:fig_melatonin_tau_gof}} plots the coefficient 
of determination (R$^2$) as a function of $\\tau$, with the optimal participant-specific $\\tau$ indicated. 
Resulting model fits for each individual is visualised above their raw data in 
Figures~\\ref{{si:fig_melatonin_scatter-fun}}.
% Example
For example, salivary melatonin concentration of participant 201 are best 
described by the bi-harmonic signal of the sum of a $1/{tau201} = {fund_freq_201}$~Hz, 
and $2/{tau201} = {harm_freq_201}$~Hz signal.
% Tau stats
The mean optimal $\\tau$ of the sample is ${tau_mean}\\pm{tau_sd}$ hours, 
revealing a near 24-hour rhythm for all participants. The participant-specific 
$\\tau$ values range from ${tau_min}$ hours as the shortest period for participant 
${pid_tau_min}$ to ${tau_max}$ hours as the longest period for participant ${pid_tau_max}$. 

\\paragraph{{Oscillatory parameters of melatonin rhythm}}
% Mesor
Mesor, as well as amplitudes and phase of the fundamental frequency and second 
harmonic describing the participant-wise melatonin concentration are 
listed in Table~\\ref{{tab:tbl_tau_harmonics}}.
% Hormones - report tau and variation
From the final model, both, amplitude and phase, of the first (fundamental) and 
second harmonic were derived from the first and second set of sine-cosine 
parameter sets, respectively.
% Fundamental
Circular statistics as derived from the fundamental components are visualised in 
polar plot in Figure~\\ref{{fig:img_melatonin_overview_figure}}B. 
The amplitudes of the fundamental melatonin rhythms measures on average 
${amplitude_fund_mean}\\pm{amplitude_fund_sd}$ \\ac{{pgml}}, ranging from ${amplitude_fund_min}$ 
to ${amplitude_fund_max}$ \\ac{{pgml}}.
Average phase for the fundamental is ${phase_fund_mean}\\pm{phase_fund_sd}$ radians,
ranging from ${phase_fund_min}$ to ${phase_fund_max}$.
The corresponding melatonin peak falls on average ${peak_fund_mean}\\pm{peak_fund_sd}$ hours
after wakeup, ranging from ${peak_fund_min}$ to ${peak_fund_max}$ hours.
Peak times were derived per participant from their own phase and period $\\tau$, and
phases were summarised using circular statistics.
% Second harmonics
Amplitudes of the second harmonic were at ${amplitude_harm_mean}\\pm{amplitude_harm_sd}$ \\ac{{pgml}}, 
ranging from ${amplitude_harm_min}$ to ${amplitude_harm_max}$ \\ac{{pgml}}. 
% Amplitude and phase for second harmonic
The distribution of the different phases is quite narrow. The average phase of 
the second harmonic is ${phase_harm_mean}\\pm{phase_harm_sd}$,
ranging from ${phase_harm_min}$ to ${phase_harm_max}$ radians.
With a lower peak amplitude than the fundamental, the second harmonic may not 
drastically the dynamic of melatonin concentration, but slightly change the timing 
of the peak of the melatonin rhythm, as can be seen in Figure~\\ref{{fig:img_melatonin_overview_figure}}C.

    "

    formatted_text <- glue::glue(
      raw_text,
      tau_mean = roundsci(tau_mean),
      tau_sd = roundsci(tau_sd),
      tau_min = roundsci(tau_min),
      tau_max = roundsci(tau_max),
      tau201 = roundsci(tau_201),
      tau_aic_mean = roundsci(tau_aic_mean),
      amplitude_fund_mean = roundsci(amplitude_fund_mean),
      amplitude_fund_sd = roundsci(amplitude_fund_sd),
      amplitude_fund_min = roundsci(amplitude_fund_min),
      amplitude_fund_max = roundsci(amplitude_fund_max),
      amplitude_harm_mean = roundsci(amplitude_harm_mean),
      amplitude_harm_sd = roundsci(amplitude_harm_sd),
      amplitude_harm_min = roundsci(amplitude_harm_min),
      amplitude_harm_max = roundsci(amplitude_harm_max),
      phase_harm_mean = roundsci(phase_harm_mean),
      phase_harm_sd = roundsci(phase_harm_sd),
      phase_harm_min = roundsci(phase_harm_min),
      phase_harm_max = roundsci(phase_harm_max),
      phase_fund_mean = roundsci(phase_fund_mean),
      phase_fund_sd = roundsci(phase_fund_sd),
      phase_fund_min = roundsci(phase_fund_min),
      phase_fund_max = roundsci(phase_fund_max),
      peak_fund_mean = roundsci(peak_fund_mean),
      peak_fund_sd = roundsci(peak_fund_sd),
      peak_fund_min = roundsci(peak_fund_min),
      peak_fund_max = roundsci(peak_fund_max),
      fund_freq_201 = roundsci(fund_freq_201), #round(1/(tau_201*60*60),2), 
      harm_freq_201 = roundsci(harm_freq_201), #round(2/(tau_201*60*60),2),
      pid_tau_min = pid_tau_min,
      pid_tau_max = pid_tau_max
    )
    
    
    # Export the text to a .tex file
    if (dir.exists(tex_dir)) {
      #tex_dir <- "./reports/log_tcs/multilevel/reports/tex"
      out_path <-
        file.path(tex_dir, "tex_inference_melatonin.tex")
      
      dir.exists(dirname(out_path))
      cat(formatted_text, file = out_path)
      cat(paste("File saved in: ", out_path))
    } else {
      cat(formatted_text)
    }
    
    return(formatted_text)
  }

