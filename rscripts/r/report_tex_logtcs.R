# Canonical paths (DERIVATIVES_DIR, TEX_DIR, ...). See ../STRUCTURE.md.
source("./r/paths.R")

check_files <- function(files, in_dir) {
  path_list <- file.path(in_dir, files)
  missing <- path_list[!file.exists(path_list)]
  
  if (length(missing) > 0) {
    stop(sprintf(
      "The following file(s) were not found in directory '%s':\n- %s",
      dir,
      paste(basename(missing), collapse = "\n- ")
    ))
  }
  
  return(path_list)
}

#' Create LaTeX report with descriptive statistics 
#'
#' @param data_path Path to the input data CSV file.
#' @param tex_dir Directory where the LaTeX file will be saved.
#'
#' @returns
#' @export
#'
#' @examples
create_tex_descriptive_tcs <-
  function(data_path = file.path(DERIVATIVES_DIR, "log_tcs/multilevel/input_data.csv"),
           tex_dir = file.path(TEX_DIR, "log_tcs/multilevel")) {
    df <- readr::read_csv(data_path, show_col_types = FALSE) %>%
      as.data.frame %>%
      dplyr::filter(participant_id != 200)
    
    # Calculate variables
    # Calculate the total number of tests (n_test_total)
    n_thres_total <- nrow(df)
    n_test_total <- nrow(df[df$freq == 2,])
    
    # Calculate the number of participants (n_participants)
    n_participants <- n_distinct(df$participant_id)
    
    # Calculate the number of tests per condition per participant
    tests_per_colour_per_pid <- df %>%
      filter(freq == 2)  %>%
      group_by(participant_id, condition) %>%
      summarize(n_tests = n())
    #summarize(min_tests = min(n_tests), max_tests = max(n_tests)) %>% unlist()
    
    min_tests_per_colour_per_pid <- min(tests_per_colour_per_pid["n_tests"])
    max_tests_per_colour_per_pid <- max(tests_per_colour_per_pid["n_tests"])
    
    # Calculate the number of tests per wake period per participant
    tests_per_block_per_colour_per_pid <- df %>%
      filter(freq == 2)  %>%
      group_by(participant_id, block, condition) %>%
      summarize(n_tests = n()) 
    # summarize(min_tests = min(n_tests), max_tests = max(n_tests)) %>% unlist()
    
    min_tests_per_block_per_colour_per_pid <-
      min(tests_per_block_per_colour_per_pid["n_tests"])
    max_tests_per_block_per_colour_per_pid <-
      max(tests_per_block_per_colour_per_pid["n_tests"])
    
    # Calculate the number of tests per participant
    tests_per_participant <- df %>%
      filter(freq == 2)  %>%
      group_by(participant_id) %>%
      summarize(n_tests = n()) # %>% unlist()
    
    min_test_per_pid <- min(tests_per_participant["n_tests"])
    max_test_per_pid <- max(tests_per_participant["n_tests"])
    
    # TODO
    # Calculate the failure rate
    # Assuming failure is defined as the number of tests not being saved
    # i.e. the number of tests not being saved is the difference between expected and actual tests
    # Expected tests per participant: 11 blocks with 3 repetitions per 3 conditions (red-green, blue-yellow, achromatic)
    expected_tests_per_participant <- 11 * 3 * 3
    # Calculate the number of failed tests per participant
    failed_tests_per_participant <-
      (tests_per_participant["n_tests"] - expected_tests_per_participant)
    # Calculate the total number of failed tests
    failure_rate_total <- 999
    undershoot_test_n <- sum(failed_tests_per_participant$n_tests[failed_tests_per_participant < 0])
    overshoot_test_n <- sum(failed_tests_per_participant$n_tests[failed_tests_per_participant > 0])
    # Calculate the minimum and maximum failure rate per participant
    failure_rate_pid_min <- min(failed_tests_per_participant)
    failure_rate_pid_max <- max(failed_tests_per_participant)
    # Calculate the participant ID with the maximum number of failed tests
    pid_failure_max <- df %>%
      group_by(participant_id) %>%
      summarize(n_tests = n()) %>%
      filter((n_tests - expected_tests_per_participant) == failure_rate_pid_max) %>%
      pull(participant_id) %>%
      unique()
    # Calculate the number of tests beyond the expected number for the participant with the maximum failures
    failure_n_pid_max <-
      failure_rate_pid_max + expected_tests_per_participant
    
    # Calculate the mean and standard deviation of contrast thresholds for each condition and frequency
    contrast_threshold_block_stats <- df %>%
      group_by(participant_id, condition, freq, block) %>%
      summarize(estimate = mean(tcs))
    
    # contrast_threshold_stats <- df %>%
    #   group_by(participant_id, condition, freq) %>%
    #   summarize(tcs = mean(thres)) %>%
    #   ungroup() %>%
    #   group_by(freq, condition) %>%
    #   summarize(estimate = mean(thres),
    #             sd = sd(thres)) 
    
    # Participant 212, Block 2
    contrast_sensitivity_stats_212 <- df %>%
      filter(participant_id == 212, block == 2) 
    
    test_212_2_rg_2hz_estimate  <- contrast_sensitivity_stats_212 %>% filter(condition == "red-green", freq == 2, test == 3)   %>% pull(thres) %>% roundsci()
    test_212_2_rg_2hz_sd        <- contrast_sensitivity_stats_212 %>% filter(condition == "red-green", freq == 2, test == 3)   %>% pull(thres_sd) %>%  roundsci()
    test_212_2_rg_8hz_estimate  <- contrast_sensitivity_stats_212 %>% filter(condition == "red-green", freq == 8, test == 3)   %>% pull(thres) %>% roundsci()
    test_212_2_rg_8hz_sd        <- contrast_sensitivity_stats_212 %>% filter(condition == "red-green", freq == 8, test == 3)   %>% pull(thres_sd) %>%  roundsci()
    test_212_2_by_2hz_estimate  <- contrast_sensitivity_stats_212 %>% filter(condition == "blue-yellow", freq == 2, test == 1) %>% pull(thres) %>% roundsci()
    test_212_2_by_2hz_sd        <- contrast_sensitivity_stats_212 %>% filter(condition == "blue-yellow", freq == 2, test == 1) %>% pull(thres_sd) %>%  roundsci()
    test_212_2_by_8hz_estimate  <- contrast_sensitivity_stats_212 %>% filter(condition == "blue-yellow", freq == 8, test == 1) %>% pull(thres) %>% roundsci()
    test_212_2_by_8hz_sd        <- contrast_sensitivity_stats_212 %>% filter(condition == "blue-yellow", freq == 8, test == 1) %>% pull(thres_sd) %>%  roundsci()
    test_212_2_ach_2hz_estimate <- contrast_sensitivity_stats_212 %>% filter(condition == "achromatic", freq == 2, test == 2)  %>% pull(thres) %>% roundsci()
    test_212_2_ach_2hz_sd       <- contrast_sensitivity_stats_212 %>% filter(condition == "achromatic", freq == 2, test == 2)  %>% pull(thres_sd) %>%  roundsci()
    test_212_2_ach_8hz_estimate <- contrast_sensitivity_stats_212 %>% filter(condition == "achromatic", freq == 8, test == 2)  %>% pull(thres) %>% roundsci()
    test_212_2_ach_8hz_sd       <- contrast_sensitivity_stats_212 %>% filter(condition == "achromatic", freq == 8, test == 2)  %>% pull(thres_sd) %>%  roundsci()
    
    pid_dir <- ""
    test212_ach <- "212 civibe/212 civibe_Left_achromatic_2024-09-28 16:46:18.xls"
    test212_by <- "212 civibe/212 civibe_Left_blue-yellow_2024-09-28 16:05:15.xls"
    test212_rg <- "212 civibe/212 civibe_Left_red-green_2024-09-28 17:25:26.xls"
    # confirmed
    # test_212_2_ach2_estimate = 5.18
    # test_212_2_ach2_sd = 0.72
    # test_212_2_ach8_estimate = 2.84
    # test_212_2_ach8_sd = 0.44
    # test_212_2hz_rg2_estimate = 1.02
    # test_212_2_rg2_sd = 0.17
    # test_212_2_rg8_estimate = 1.12
    # test_212_2_rg8_sd = 0.19
    # test_212_2_by2_estimate = test_212_2_by_2hz_estimate
    # test_212_2_by2_sd = 0.18
    # test_212_2_by8_estimate = 8.51
    # test_212_2_by8_sd = 2.17
    
    
    
    # Calculate the grand average of contrast sensitivity (tcs) for each condition and frequency
    contrast_sensitivity_stats <- df %>%
      group_by(condition, freq) %>%
      summarize(
        mean_tcs = mean(tcs),
        sd_tcs = sd(tcs)
      ) 
    
    cs_rg2_global_mean <- contrast_sensitivity_stats %>% filter(condition == "red-green", freq == 2) %>% pull(mean_tcs)
    cs_rg2_global_sd   <- contrast_sensitivity_stats %>% filter(condition == "red-green", freq == 2) %>% pull(sd_tcs)
    cs_rg8_global_mean <- contrast_sensitivity_stats %>% filter(condition == "red-green", freq == 8) %>% pull(mean_tcs)
    cs_rg8_global_sd   <- contrast_sensitivity_stats %>% filter(condition == "red-green", freq == 8) %>% pull(sd_tcs)
    cs_by2_global_mean <- contrast_sensitivity_stats %>% filter(condition == "blue-yellow", freq == 2) %>% pull(mean_tcs)
    cs_by2_global_sd   <- contrast_sensitivity_stats %>% filter(condition == "blue-yellow", freq == 2) %>% pull(sd_tcs)
    cs_by8_global_mean <- contrast_sensitivity_stats %>% filter(condition == "blue-yellow", freq == 8) %>% pull(mean_tcs)
    cs_by8_global_sd   <- contrast_sensitivity_stats %>% filter(condition == "blue-yellow", freq == 8) %>% pull(sd_tcs)
    cs_ach2_global_mean <- contrast_sensitivity_stats %>% filter(condition == "achromatic", freq == 2) %>% pull(mean_tcs)
    cs_ach2_global_sd   <- contrast_sensitivity_stats %>% filter(condition == "achromatic", freq == 2) %>% pull(sd_tcs)
    cs_ach8_global_mean <- contrast_sensitivity_stats %>% filter(condition == "achromatic", freq == 8) %>% pull(mean_tcs)
    cs_ach8_global_sd   <- contrast_sensitivity_stats %>% filter(condition == "achromatic", freq == 8) %>% pull(sd_tcs)
    
    
    raw_1 <- "\\subsubsection{{Temporal contrast sensitivity}}
  
% Introduction
Temporal contrast threshold were determined adaptively with a staircase procedure. 
One test targetted one colour direction (i.e. a retinal mechanism) and was comprised 
of two staircase procedures, one for each frequency, 2 Hz and 8 Hz contrast modulation.  
Originally, three repetitions of each direction per participant during each wake 
period were planned, aiming for 33 test per direction and participant (66 staircases) 
across the 11 wake periods and a total of 99 test per participant. 
% Device failure
% However, due to this unexpected behaviour of the device, experimenters sometimes performed additional repetitions of specific tests.
Data collection was occasionally interrupted by a software failure of the device 
during data transfer from the tablet needed to control the experiments to the 
computer that stored the data which caused the device to not save the data 
after the test was completed. 
In this case, the experimenter would repeat the test comprised of two staircases 
for the affected colour direction. Human error on the experimenter sides, 
e.g. incorrect test selection, or failure to repeat an experiment, caused a small 
number of superfluous test repetitions or test omissions (cf. Table \\ref{{tab:tbl_descriptives_ntcstests}}).
% Amount of data
From $N= {n_participants}$ participant, a total of ${n_test_total}$ experiments where completed, 
amounting to a ${n_thres_total}$ staircases and contrast thresholds estimates across both frequency conditions.
Between ${min_tests_per_block_per_colour_per_pid}$ 
to ${max_tests_per_block_per_colour_per_pid}$ tests were performed per colour 
direction and per wake period, amounting to ${min_tests_per_colour_per_pid}$ 
to ${max_tests_per_colour_per_pid}$ tests per colour direction across all wake periods, 
Each participant completed between a total of ${min_test_per_pid}$ and ${max_test_per_pid}$ tests.

"
    
    formatted_1 <- glue::glue(
      raw_1,
      n_test_total = n_test_total,
      n_thres_total = n_thres_total,
      n_participants = n_participants,
      min_tests_per_colour_per_pid = min_tests_per_colour_per_pid,
      max_tests_per_colour_per_pid = max_tests_per_colour_per_pid,
      min_tests_per_block_per_colour_per_pid = min_tests_per_block_per_colour_per_pid,
      max_tests_per_block_per_colour_per_pid = max_tests_per_block_per_colour_per_pid,
      min_test_per_pid = min_test_per_pid,
      max_test_per_pid = max_test_per_pid
    )
    
    
    raw_2 <- "
\\paragraph{{Exemplary staircase trajectory of contrast thresholds}}
% Threshold staircase 
In Figure \\ref{{fig:fig_psychophysics_timeseries}}, the staircase method is 
visualised for three exemplary different tests; frequency-specific staircases are 
visually separated into subplots.
During each test, participants would start from an initial colour contrast 
(90\\% for the \\ach{{all}} task, 35\\% for the \\enquote{{S}} task, and 6\\% 
for the \\enquote{{L-M}} task); contrast would then adapt to performance and converge around a threshold. 
At each step, the contrast level would decrease in case of two previous correct 
responses or increase in case of an incorrect response in logarithmic steps (two-up-one-down staircase). 
Due to colour gamut, the contrast could only increase to a maximum level that 
depends on the retinal mechanism tested (100\\% for the \\ach{{all}} task, 51\\% for the \\enquote{{S}}  task, 
and 6\\% for the \\rg{{all}} task).
In the visualised \\rg{{all}} test, the contrast threshold drops rapidly below 
$1\\%$ for the low-frequency 2-Hz condition and almost as fast in the high-frequency 8-Hz condition, 
and converges for both conditions around $1\\%$, with small standard deviation 
(2 Hz: ${test_212_2_rg_2hz_estimate}\\%\\pm{test_212_2_rg_2hz_sd}\\%$; 
8 Hz: ${test_212_2_rg_8hz_estimate}\\%\\pm{test_212_2_rg_8hz_sd}\\%$).
For the other colour directions (\\ach{{all}} and \\by{{all}}) threshold 
estimates are all notably higher for both frequency conditions. 
For the \\by{{all}} test, the contrast threshold drops close to $1\\%$ for the 
2-Hz condition, and close to $4$\\% for the 8-Hz condition, but then rises due 
to multiple subsequent mistakes accumulating after around 10 trials. 
The sensitivity trajectories in the 2-Hz staircase converges at 
${test_212_2_by_2hz_estimate}\\%$ (${test_212_2_by_2hz_sd}\\%$.
There is wider fluctuation in the 8-Hz staircase before threshold identification, 
which is reflected in a high standard deviation for the threshold estimate at 
${test_212_2_by_8hz_estimate}\\%$ (${test_212_2_by_8hz_sd}\\%$). 
The overall final estimate of the temporal contrast threshold is higher in the 
high-frequency than in the low-frequency procedure for this colour direction. 
The \\ach{{low}} staircase yields the second highest estimate in this selection, 
second to the \\by{{high}} threshold. Both estimates are similar or even higher 
than the initial starting contrast of the \\rg{{all}} task. Finally, the contrast 
thresholds of the \\ach{{low}} (${test_212_2_ach_2hz_estimate}\\%\\pm{test_212_2_ach_2hz_sd}$) 
is lower than the \\ach{{high}} condition (${test_212_2_ach_8hz_estimate}\\%\\pm{test_212_2_ach_8hz_sd}\\%$). 
In summary, the threshold of the different frequency conditions within the 
\\ach{{all}} colour direction are in reverse order compared to the thresholds 
from the frequency conditions in the \\by{{all}} task, and both yield considerably 
higher estimates than both \\rg{{all}} staircases.
% In the \\ach{{all}} tests, it is the lower temporal modulation frequency whose 
detection threshold barely drops compared to the starting contrast, producing a 
threshold estimate of ${test_212_2_ach_2hz_estimate}\\%\\pm{test_212_2_ach_2hz_sd}\\%$.

"
    formatted_2 <- glue::glue(
      raw_2,
      test_212_2_rg_2hz_estimate = roundsci(test_212_2_rg_2hz_estimate),
      test_212_2_rg_2hz_sd = roundsci(test_212_2_rg_2hz_sd),
      test_212_2_rg_8hz_estimate = roundsci(test_212_2_rg_8hz_estimate),
      test_212_2_rg_8hz_sd = roundsci(test_212_2_rg_8hz_sd),
      test_212_2_by_2hz_estimate = roundsci(test_212_2_by_2hz_estimate),
      test_212_2_by_2hz_sd = roundsci(test_212_2_by_2hz_sd),
      test_212_2_by_8hz_estimate = roundsci(test_212_2_by_8hz_estimate),
      test_212_2_by_8hz_sd = roundsci(test_212_2_by_8hz_sd),
      test_212_2_ach_2hz_estimate = roundsci(test_212_2_ach_2hz_estimate),
      test_212_2_ach_2hz_sd = roundsci(test_212_2_ach_2hz_sd),
      test_212_2_ach8_estimate = roundsci(test_212_2_ach_8hz_estimate),
      test_212_2_ach8_sd = roundsci(test_212_2_ach_8hz_sd)
    )
    
    raw_3 <- "
\\paragraph{{Group averages in contrast sensitivity}}
% CS grand average
The order between threshold levels of different retinal mechanisms and frequency 
conditions seen in the exemplary participant's single tests described above 
is replicated in the grand average contrast sensitivities (across participants 
and time) listed in Table~\\ref{{tab:tbl_descriptives_tcs}}.
The contrast sensitivity is the inverse of the contrast thresholds. 
Numerical order effects even persist across most experimental blocks, as can be 
seen in Figure~\\ref{{fig:fig_average_tcs_melatonin}} which shows group averages 
over time.
Due to inconsistent sampling across time, and unequal number of tests per block, 
here the block average per participant was calculated first, and then the 
group-level average was derived from the participant-values.
The group-level means therefore reflect the average of the participant-specific 
block means, giving equal weight to each participant regardless of the number of tests contributed. 
In detail, contrast sensitivity levels for \\rg{{all}} are consistently higher 
than of the other conditions. The \\rg{{low}} condition has a grand average of 
${cs_rg2_global_mean}\\pm{cs_rg2_global_sd}$; 
the grand average in the \\rg{{high}} condition is slightly lower compared to the 
\\rg{{low}} condition with a contrast sensitivity of ${cs_rg8_global_mean}\\pm{cs_rg8_global_sd}$. 
The contrast sensitivity levels of the two other retinal mechanisms are 
consistently lower, irrespective of the tested temporal frequency. 
Results of both conditions of the other chromatic retinal mechanism suggest 
low contrast sensitivity, but similar to the \\rg{{all}} mechanism, 
the grand average of ${cs_by2_global_mean}\\pm{cs_by2_global_sd}$ in the low-frequency 
staircase of \\by{{all}} is still numerically slightly lower than the grand average 
of ${cs_by8_global_mean}\\pm{cs_by8_global_sd}$ in the high-frequency condition \\by{{high}}.
Again, the \\ach{{all}} mechanism exhibits the largest numerical difference between 
frequency conditions. The group-level mean of \\ach{{low}} is on a similar level 
as the \\by{{low}}, amounting to ${cs_ach2_global_mean}\\pm{cs_ach2_global_sd}$. 
The contrast sensitivity of the higher frequency is much higher at 
${cs_ach8_global_mean}\\pm{cs_ach8_global_sd}$.
To summarise, reflecting trends in from single tests, the between-directions 
difference of the group averages are not just numerically higher, but also points 
in the opposite direction compared to the other retinal mechanisms tests.

\\paragraph{{Group-level time course in temporal contrast sensitivity}}
% Rhythmicity of CS group average over time
According to our hypothesis, we would have expected a sinusoidal dynamic in each 
of colour directions and frequency conditions.
An identifiable sinusoidal dynamic would, for example, be a rise in contrast 
sensitivity during the day (or habitual wake time) and a low during the night 
(or habitual bed time), with an inflection point after approximately 12 hours.  
Or alternatively, a decline during the hours of subjective daytime followed by 
a rise in contrast sensitivity during the night. 
As we had separate and independent hypothesis of circadian rhythmicity set up, 
we considered the possibility of different patterns between retinal mechanisms 
(colour directions) and frequencies, or rhythmicity in specific conditions but not in others.
When averaging the timeseries of the contrast sensitvity estimates across participants, 
the averaged timeseries shows little variation across time, as can be seen in 
Figure~\\ref{{fig:fig_average_tcs_melatonin}}. 
In the contrast sensitivity dynamics across 40 hours, visual inspection of 
Figure~\\ref{{fig:fig_average_tcs_melatonin}} does not reveal any 24-hour rhythmicity. 
Variation in block-wise group means is quite small. There seems to be a slight 
downward trend when approaching the first habitual bedtime. 
But it may be negligible when considering the standard mean error. Is is possible 
that participant-specific dynamics average out in the group-average timeseries.
Thus, the original hypotheses are evaluated using inferential statistics on mixed models.

"
    
    formatted_3 <- glue::glue(
      raw_3,
      cs_rg2_global_mean = roundsci(cs_rg2_global_mean),
      cs_rg2_global_sd = roundsci(cs_rg2_global_sd),
      cs_rg8_global_mean = roundsci(cs_rg8_global_mean),
      cs_rg8_global_sd = roundsci(cs_rg8_global_sd),
      cs_by2_global_mean = roundsci(cs_by2_global_mean),
      cs_by2_global_sd = roundsci(cs_by2_global_sd),
      cs_by8_global_mean = roundsci(cs_by8_global_mean),
      cs_by8_global_sd = roundsci(cs_by8_global_sd),
      cs_ach2_global_mean = roundsci(cs_ach2_global_mean),
      cs_ach2_global_sd = roundsci(cs_ach2_global_sd),
      cs_ach8_global_mean = roundsci(cs_ach8_global_mean),
      cs_ach8_global_sd = roundsci(cs_ach8_global_sd)
    )
    
    raw_4 <- "
\\paragraph{{Participant-level time course in temporal contrast sensitivity}}
% Individual CS dynamics
Visually, individual dynamics in the contrast sensitivity resemble the average 
group-level dynamics.
In Figure~\\ref{{fig:fig_psychophysics_individual}} we visualised participant-wise 
contrast sensitivity timeseries across experimental blocks on equivalent y-axes. 
The order effects between the retinal mechanisms seen in the in the group-level 
differences and exemplary staircases even, respectively, 
also exist in the participant-specific contrast estimates, particularly for 
the results from high-frequency contrast modulation: the contrast sensitivity in 
\\rg{{high}} is highest, followed by the \\ach{{high}}, and low levels in the 
\\by{{high}} condition. 
There are only single blocks of single participants, where the \\ach{{high}} 
briefly rises nominally above the \\rg{{high}} contrast sensitivity such as in 
third experimental block in participant 206. 
In the low-frequency conditions with 2-Hz temporal modulation, the contrast sensitivity 
levels of the \\ach{{low}} and \\by{{low}} staircases often are at a similar level, 
as is the case in the group-level dynamics, but vary in their nominal dominance 
between participants, or within single participants across time.
For example, in participant 201, in the \\by{{low}} mechanisms there seems to be 
a slightly but consistenly higher contrast sensitivity across time, while it is 
the other way around in participant 202 and 205. 
For yet other participants, the nominal dominance switches from block to block 
or across the time, which is especially the case for \\by{{low}} of participants 206 and 209.
% Single participants as example
%In the participant-wise plots, there are clearly stronger dynamics than in the group-averaged timeseries, that seem to average out when summarising data across participants. %suggesting that a random slope model for the circadian rhyhtm hypothesis may be appropriate.
%We suspected a circadian rhythmicity in the individual contrast sensitivity, and propose person-specific slopes for the circadian components. 
%A biological process as proposed would show in most participants contrast sensitivity dynamics - even if present at different degrees.
% The presence of circadian pattern in different individuals and tests cannot be identified based on. 
There is no clear linear, circadian or other trend in all timeseries, 
but various dynamics in different participant, colour and frequency condition. 
For example, the contrast sensitivity of participant 209 is quite stable in all 
retinal mechanisms and frequency conditions. 
In contrast, there is quite a bit of variability of time in the contrast 
sensitivity of participant 201 for all high frequency conditions across retinal mechanisms. 
%And one may argue even for a circadian pattern in all low frequency conditions of participant 205. 
Participant 210 seems to show a slight linear downward trend in all retinal 
mechanisms and conditions in \\rg{{high}}.
% Possibly outlier in blocks
Excursions at particular blocks (e.g. in participant 206) seem to be associated 
with high standard deviation suggesting outlier presence. 
Single outliers may be particularly influential on block averages as there are 
only few tests per block, retinal mechanism and frequency condition. 
For statistical inference, single data points are used instead of block means to 
fit a circadian rhythm.

"
    formatted_4 <- glue::glue(
      raw_4
    )
    
    
    formatted_text <- paste(formatted_1,
                            formatted_2,
                            formatted_3,
                            formatted_4,
                            sep = "\n")
    
    # Format string
    formatted_text <- sub("= $<", "$ <", formatted_text)
    formatted_text <- sub("=$<", "$<", formatted_text)
    
    # Export the text to a .tex file
    save_tex(out_string = formatted_text,
             out_path = file.path(tex_dir, "tex_descriptives_tcs.tex"))
    
    return(formatted_text)
  }

#' Create LaTeX text for inference statistics 
#'
#' @param data_path Input path to the CSV file containing the fitted TCS parameters. Default is "./data/derivatives/log_tcs/multilevel/fitted_tcs_all_parameters.csv".
#' @param tex_dir Output directory for the LaTeX file. Default is "./reports/log_tcs/multilevel/reports/tex".
#'
#' @returns
#' @export
#'
create_tex_inference_tcs <-
  function(data_dir = file.path(DERIVATIVES_DIR, "log_tcs/multilevel"),
           tex_dir = file.path(TEX_DIR, "log_tcs/multilevel")) {
    filename <- "fitted_all_parameters.csv"
    #check_files(files="fitted_all_parameters.csv", in_dir=data_dir)
    data_path <- file.path(data_dir, filename)
    df <- readr::read_csv(data_path, show_col_types = FALSE) %>%
      as.data.frame()
    
    # Red-Green, Frequency = 2
    rg2_a_fixed <-
      df %>% filter(condition == "red-green", freq == 2) %>% summarize(a_fixed = mean(sine_estimate)) %>% pull(a_fixed)
    rg2_b_fixed <-
      df %>% filter(condition == "red-green", freq == 2) %>% summarize(b_fixed = mean(cosine_estimate)) %>% pull(b_fixed)
    rg2_amplitude_fixed <-
      df %>% filter(condition == "red-green", freq == 2) %>% summarize(amplitude_fixed = mean(amplitude)) %>% pull(amplitude_fixed)
    rg2_phase_fixed <-
      df %>% filter(condition == "red-green", freq == 2) %>% summarize(phase_fixed = mean(phase)) %>% pull(phase_fixed)
    # Personal amplitudes for red-green
    # Bayes Factor
    rg2_logbf <-
      df %>% filter(condition == "red-green", freq == 2) %>% pull(log_bf) %>% unique()  
    
    filename <- "model_summary__red-green_2.csv"
    data_path <- file.path(data_dir, filename)
    model_df <- readr::read_csv(data_path, show_col_types = FALSE) %>% as.data.frame()
    rg2_cosine_sd = model_df$Estimate[model_df$Predictor == "sd_participant_id__cosine_component"]
    # df %>% filter(condition == "red-green", freq == 2) %>% pull(re_cosine_estimate) %>% sd()
    rg2_sine_sd = model_df$Estimate[model_df$Predictor == "sd_participant_id__sine_component"]
    # df %>% filter(condition == "red-green", freq == 2) %>% pull(re_sine_estimate) %>% sd()
    
    # Blue-Yellow, Frequency = 2
    by2_a_fixed <-
      df %>% filter(condition == "blue-yellow", freq == 2) %>% summarize(a_fixed = mean(sine_estimate)) %>% pull(a_fixed)
    by2_b_fixed <-
      df %>% filter(condition == "blue-yellow", freq == 2) %>% summarize(b_fixed = mean(cosine_estimate)) %>% pull(b_fixed)
    by2_amplitude_fixed <-
      df %>% filter(condition == "blue-yellow", freq == 2) %>% summarize(amplitude_fixed = mean(amplitude)) %>% pull(amplitude_fixed)
    by2_phase_fixed <-
      df %>% filter(condition == "blue-yellow", freq == 2) %>% summarize(phase_fixed = mean(phase)) %>% pull(phase_fixed)
    # Personal amplitudes
    by2_amplitude_p <-
      df %>% filter(condition == "blue-yellow", freq == 2) %>% summarize(amplitudes_p = list(amplitude_p)) %>% pull(amplitudes_p)
    # Bayes Factor
    by2_logbf <-
      df %>% filter(condition == "blue-yellow", freq == 2) %>% pull(log_bf) %>% unique()
    
    # Achromatic, Frequency = 2
    ach2_a_fixed <-
      df %>% filter(condition == "achromatic", freq == 2) %>% summarize(a_fixed = mean(sine_estimate)) %>% pull(a_fixed)
    ach2_b_fixed <-
      df %>% filter(condition == "achromatic", freq == 2) %>% summarize(b_fixed = mean(cosine_estimate)) %>% pull(b_fixed)
    ach2_amplitude_fixed <-
      df %>% filter(condition == "achromatic", freq == 2) %>% summarize(amplitude_fixed = mean(amplitude)) %>% pull(amplitude_fixed)
    ach2_phase_fixed <-
      df %>% filter(condition == "achromatic", freq == 2) %>% summarize(phase_fixed = mean(phase)) %>% pull(phase_fixed)
    # Personal amplitudes
    ach2_amplitude_p <-
      df %>% filter(condition == "achromatic", freq == 2) %>% summarize(amplitudes_p = list(amplitude_p)) %>% pull(amplitudes_p)
    # Bayes Factor
    ach2_logbf <-
      df %>% filter(condition == "achromatic", freq == 2) %>% pull(log_bf) %>% unique()
    
    # Repeat similarly for frequency = 8 and according conditions
    # Red-Green, Frequency = 8
    rg8_a_fixed <-
      df %>% filter(condition == "red-green", freq == 8) %>% summarize(a_fixed = mean(sine_estimate)) %>% pull(a_fixed)
    rg8_b_fixed <-
      df %>% filter(condition == "red-green", freq == 8) %>% summarize(b_fixed = mean(cosine_estimate)) %>% pull(b_fixed)
    rg8_amplitude_fixed <-
      df %>% filter(condition == "red-green", freq == 8) %>% summarize(amplitude_fixed = mean(amplitude)) %>% pull(amplitude_fixed)
    rg8_phase_fixed <-
      df %>% filter(condition == "red-green", freq == 8) %>% summarize(phase_fixed = mean(phase)) %>% pull(phase_fixed)
    # Personal amplitudes
    rg8_amplitude_p <-
      df %>% filter(condition == "red-green", freq == 8) %>% summarize(amplitudes_p = list(amplitude_p)) %>% pull(amplitudes_p)
    # Bayes Factor
    rg8_logbf <-
      df %>% filter(condition == "red-green", freq == 8) %>% pull(log_bf) %>% unique()
    
    
    # Blue-Yellow, Frequency = 8
    by8_a_fixed <-
      df %>% filter(condition == "blue-yellow", freq == 8) %>% summarize(a_fixed = mean(sine_estimate)) %>% pull(a_fixed)
    by8_b_fixed <-
      df %>% filter(condition == "blue-yellow", freq == 8) %>% summarize(b_fixed = mean(cosine_estimate)) %>% pull(b_fixed)
    by8_amplitude_fixed <-
      df %>% filter(condition == "blue-yellow", freq == 8) %>% summarize(amplitude_fixed = mean(amplitude)) %>% pull(amplitude_fixed)
    by8_phase_fixed <-
      df %>% filter(condition == "blue-yellow", freq == 8) %>% summarize(phase_fixed = mean(phase)) %>% pull(phase_fixed)
    # Personal amplitudes
    by8_amplitude_p <-
      df %>% filter(condition == "blue-yellow", freq == 8) %>% summarize(amplitudes_p = list(amplitude_p)) %>% pull(amplitudes_p)
    # Bayes Factor
    by8_logbf <-
      df %>% filter(condition == "blue-yellow", freq == 8) %>% pull(log_bf) %>% unique()
    
    # Achromatic, Frequency = 8
    ach8_a_fixed <-
      df %>% filter(condition == "achromatic", freq == 8) %>% summarize(a_fixed = mean(sine_estimate)) %>% pull(a_fixed)
    ach8_b_fixed <-
      df %>% filter(condition == "achromatic", freq == 8) %>% summarize(b_fixed = mean(cosine_estimate)) %>% pull(b_fixed)
    ach8_amplitude_fixed <-
      df %>% filter(condition == "achromatic", freq == 8) %>% summarize(amplitude_fixed = mean(amplitude)) %>% pull(amplitude_fixed)
    ach8_phase_fixed <-
      df %>% filter(condition == "achromatic", freq == 8) %>% summarize(phase_fixed = mean(phase)) %>% pull(phase_fixed)
    # Personal amplitudes
    ach8_amplitude_p <-
      df %>% filter(condition == "achromatic", freq == 8) %>% summarize(amplitudes_p = list(amplitude_p)) %>% pull(amplitudes_p)
    # Bayes Factor
    ach8_logbf <-
      df %>% filter(condition == "achromatic", freq == 8) %>% pull(log_bf) %>% unique()
    
    
    min_logbf <-
      df[df$log_bf == min(df$log_bf), c("condition", "freq", "log_bf")] %>%  pull(log_bf) %>%  unique()
    max_logbf <-
      df[df$log_bf == max(df$log_bf), c("condition", "freq", "log_bf")] %>%  pull(log_bf) %>% unique()
    min_bf <-
      df[df$bf == min(df$bf), c("condition", "freq", "bf")] %>%  pull(bf) %>% unique()
    max_bf <-
      df[df$bf == max(df$bf), c("condition", "freq", "bf")] %>%  pull(bf) %>% unique()
    max_odds_null <- 1 / min_bf
    min_odds_null <- 1 / max_bf
    
    # Individual phases are angles, so their spread is taken on the circle:
    # min()/max() applied to them directly are split by the branch cut at +/-pi,
    # which inflates the range of any cell whose phases straddle it (see
    # circular_range() in utils.R). Bounds may fall outside (-pi, pi].
    rg2_indiv_phase_range <-
      df %>% filter(condition == "red-green", freq == 2) %>% pull(phase_p) %>% circular_range()
    rg2_indiv_phase_min <- rg2_indiv_phase_range[["min"]]
    rg2_indiv_phase_max <- rg2_indiv_phase_range[["max"]]
    rg2_group_amplitude <-
      df %>% filter(condition == "red-green", freq == 2) %>% pull(amplitude_p)
    ach2_indiv_phase_range <-
      df %>% filter(condition == "achromatic", freq == 2) %>% pull(phase_p) %>% circular_range()
    ach2_indiv_phase_min <- ach2_indiv_phase_range[["min"]]
    ach2_indiv_phase_max <- ach2_indiv_phase_range[["max"]]
    by2_indiv_phase_range <-
      df %>% filter(condition == "blue-yellow", freq == 2) %>% pull(phase_p) %>% circular_range()
    by2_indiv_phase_min <- by2_indiv_phase_range[["min"]]
    by2_indiv_phase_max <- by2_indiv_phase_range[["max"]]
    
    
    # For all other variables that can't be computed, set them to zero as instructed
    filename_list <- c(
      "model_summary__achromatic_2.csv",
      "model_summary__achromatic_8.csv",
      "model_summary__blue-yellow_2.csv",
      "model_summary__blue-yellow_8.csv",
      "model_summary__red-green_2.csv",
      "model_summary__red-green_8.csv"
    )
    data_path_list <- file.path(data_dir, filename_list)
    check_files(files=filename_list, in_dir=data_dir)
    
    # Read the model summary CSV files into list with basenames as list names
    # Initialize list
    model_summaries <- list()
    lookup <- c("achromatic" = "ach", 
                "blue-yellow" = "by", 
                "red-green" = "rg")
    
    # Load dataframe 
    for (i_path in seq_along(data_path_list)) {
      new_df <-
        readr::read_csv(data_path_list[i_path], show_col_types = FALSE) %>% as.data.frame()
      # Convert to list, with first column as list entry names
      new_list <- lapply(split(new_df, new_df$Predictor), function(x) as.list(x))
      # Use first column of to second level list
      filename <- basename(data_path_list[i_path])
      entry_name <- gsub(".*model_summary__(.*)\\.csv.*", "\\1", filename)
      entry_name <- stringr::str_replace_all(entry_name, lookup)
      # add list to with label to model_summary
      model_summaries[[entry_name]] <- new_list
    }
    
    # rg2
    rg2_full_conditionalr2 <- model_summaries[["rg_2"]]$conditional_r2$Estimate
    rg2_null_conditionalr2 <- model_summaries[["rg_2"]]$conditional_r2$Estimate_null
    rg2_full_marginalr2 <- model_summaries[["rg_2"]]$marginal_r2$Estimate
    rg2_null_marginalr2 <- model_summaries[["rg_2"]]$marginal_r2$Estimate_null
    # rg8
    rg8_full_conditionalr2 <- model_summaries[["rg_8"]]$conditional_r2$Estimate 
    rg8_null_conditionalr2 <- model_summaries[["rg_8"]]$conditional_r2$Estimate_null 
    rg8_full_marginalr2 <- model_summaries[["rg_8"]]$marginal_r2$Estimate 
    rg8_null_marginalr2 <- model_summaries[["rg_8"]]$marginal_r2$Estimate_null 
    # by2
    by2_full_conditionalr2 <- model_summaries[["by_2"]]$conditional_r2$Estimate
    by2_null_conditionalr2 <- model_summaries[["by_2"]]$conditional_r2$Estimate_null
    by2_full_marginalr2 <- model_summaries[["by_2"]]$marginal_r2$Estimate
    by2_null_marginalr2 <- model_summaries[["by_2"]]$marginal_r2$Estimate_null
    # by8
    by8_full_conditionalr2 <- model_summaries[["by_8"]]$conditional_r2$Estimate 
    by8_null_conditionalr2 <- model_summaries[["by_8"]]$conditional_r2$Estimate_null 
    by8_full_marginalr2 <- model_summaries[["by_8"]]$marginal_r2$Estimate 
    by8_null_marginalr2 <- model_summaries[["by_8"]]$marginal_r2$Estimate_null 
    # ach2
    ach2_full_conditionalr2 <- model_summaries[["ach_2"]]$conditional_r2$Estimate
    ach2_null_conditionalr2 <- model_summaries[["ach_2"]]$conditional_r2$Estimate_null
    ach2_full_marginalr2 <- model_summaries[["ach_2"]]$marginal_r2$Estimate
    ach2_null_marginalr2 <- model_summaries[["ach_2"]]$marginal_r2$Estimate_null
    # ach8
    ach8_full_conditionalr2 <- model_summaries[["ach_8"]]$conditional_r2$Estimate 
    ach8_null_conditionalr2 <- model_summaries[["ach_8"]]$conditional_r2$Estimate_null 
    ach8_full_marginalr2 <- model_summaries[["ach_8"]]$marginal_r2$Estimate 
    ach8_null_marginalr2 <- model_summaries[["ach_8"]]$marginal_r2$Estimate_null 
    
    # Create the LaTeX text for inference statistics
    raw_1 <- "
%there was decisive evidence supporting the full model, which included the circular components
We fit a sine and a cosine component in a hierarchical model to the outcome variable, \\ac{{logtcs}}. 
The data was modelled to be clustered by participant, and the data was fit to 
results of individual test (runs) rather than of the block averages depicted in visualisations.
Our main confirmatory test compared a hierarchical full model with oscillatory 
components against a hierarchical null model containing only participant-specific 
intercepts, under the assumption that contrast sensitivity remained constant across day and night.
In the following, we report the \\ac{{logbf}} of inferential statistics on the 
contrast sensitivity levels.
Irrespective of whether the likelihood favours the full model or not, we will 
calculate and report the amplitude and phase derived from the estimates of the oscillatory component.
Amplitude and phase angle were calculated based on the oscillatory components, 
i.e. sine and cosine estimates, obtained when fitting the data with the full model 
as described in Equations \\ref{{eq:amplitude}} and \\ref{{eq:phase}}.

\\subsubsection{{Temporal contrast sensitivity data}}
In the statistical evaluation of our hypotheses, we logarithmised the contrast 
sensitivity to the base 10 so that the distribution of the outcome variable could 
be better approximated with a normal distribution. 
Due to the transformation of the outcome variable, the results for the, e.g. 
for amplitude are reported in log units.
%\\todo{{sentence about unequeal observatinos but same mnumber of clusters}}

    "
    formatted_1 <- glue::glue(
      raw_1
    )
    
    # Red-Green
    raw_2 <- "% L-M low
\\paragraph{{Confirmatory tests on \\rg{{all}} mechanism}}
Model comparisons between full and null model were done separately for the \\rg{{low}} and \\rg{{high}} condition. 
We were able to successfully fit the data. 
Results from the both conditions do not differ considerably at first glance (see Table~\\ref{{tab:tbl_red-green_2}} 
to Table~\\ref{{tab:tbl_blue-yellow_8}}), but there are some numerical differences 
in the amplitude as well as in phase estimates.
Estimates for both the fixed effects $\\alpha$ and $\\beta$ are well below 1 log 
unit. 
%
% L-M low
For model \\rg{{low}}, parameter estimates of $\\alpha = {rg2_a_fixed}$ and 
$\\beta = {rg2_b_fixed}$ yield a group-level amplitude of ${rg2_amplitude_fixed}$ 
log units change in contrast sensitivity. 
Interestingly, this is the only model, in which the 95\\% credibility interval 
for any of the fixed effects, $\\alpha$, did not not include zero. 
However, inference about the model comparison rather than single effects. % was drawn using \\ac{{logbf}} to compare two complete model specifications and their adequacy for the data. 

The estimate of the group-level phase derived from fixed effects is ${rg2_phase_fixed}$ rad. 
Considering the individual-level variance of in sine ($SD_{{\\alpha}} = {rg2_sine_sd}$) 
and the cosine component ($SD_{{\\beta}} = {rg2_cosine_sd}$) that the mixed model accommodated for, 
the phase estimates on an individual level translate to phases ranging between 
${rg2_indiv_phase_min}$ and ${rg2_indiv_phase_max}$ rad. 
Overall, the null model proposing only mean differences between participants instead of sinusoidal 
change over time is much better supported by the data as indicated by the \\ac{{logbf}} of ${rg8_logbf}$.
Consequently, numerical differences in phase and amplitude have limited interpretability.
%
% L-M high
The model estimation for the high-frequency condition \\rg{{high}} yielded similar 
results, clearly favouring the null hypothesis given the \\ac{{logbf}} = ${rg8_logbf}$. 
Estimates for the oscillatory components were small, values far below $0.1$ log 
units contrasts sensitivity. For both parameter estimates $\\alpha = {rg8_a_fixed}$ 
and $\\beta = {rg8_b_fixed}$, the 95\\% credibility intervals included zero.
Taken together, we obtain a small amplitude of ${rg8_amplitude_fixed}$ log units 
in contrast sensitivity, similar to the value of \\rg{{low}}. 
The obtained phase shift is ${rg8_phase_fixed}$ rad, averaged across participants.
% Conditional R2
For both hypotheses, \\ac{{logbf}} corresponds to \\enquote{{decisive}} evidence for the null model on Jeffreys' scale. 
Supporting this conclusion, the conditional $R^2$ differed only minimally between models; 
the full model explained little additional variance 
($R^2_{{\\mathrm{{full}}}} = {rg2_full_conditionalr2}$) relative to the null 
model ($R^2_{{\\mathrm{{null}}}} = {rg2_null_conditionalr2}$).
"
    
    formatted_2 <- glue::glue(
      raw_2,
      rg2_a_fixed = roundsci(rg2_a_fixed),
      rg2_b_fixed = roundsci(rg2_b_fixed),
      rg2_amplitude_fixed = roundsci(rg2_amplitude_fixed),
      rg2_phase_fixed = roundsci(rg2_phase_fixed),
      rg2_sine_sd = roundsci(rg2_sine_sd), 
      rg2_cosine_sd = roundsci(rg2_cosine_sd),
      rg8_a_fixed = roundsci(rg8_a_fixed),
      rg8_b_fixed = roundsci(rg8_b_fixed),
      rg8_amplitude_fixed = roundsci(rg8_amplitude_fixed),
      rg8_phase_fixed = roundsci(rg8_phase_fixed),
      rg2_indiv_phase_min = roundsci(rg2_indiv_phase_min),
      rg2_indiv_phase_max = roundsci(rg2_indiv_phase_max),
      rg8_logbf = roundsci(rg8_logbf),
      rg2_full_conditionalr2 = roundsci(rg2_full_conditionalr2),
      rg2_null_conditionalr2 = roundsci(rg2_null_conditionalr2)
    )
    
    # Blue-Yellow
    raw_3 <- "% S
\\paragraph{{Confirmatory tests on \\by{{all}} mechanism}}
Confirmatory test for both frequency conditions of the other chromatic direction, 
\\by{{all}}, were also in favour of the null model. 
Both model comparisons resulted in \\ac{{logbf}} $\\approx 13$ (with a \\ac{{logbf}} 
of ${by2_logbf}$ for \\by{{low}} and ${by8_logbf}$ for \\by{{high}}), 
strongly suggesting that the null model is much more likely than the full model.
%
% S (low)
For the low frequency condition, \\by{{low}}, the parameter estimates 
$\\alpha = {by2_a_fixed}$ and $\\beta = {by2_b_fixed}$ yield a group-level 
amplitude ${by2_amplitude_fixed}$ log units contrast sensitivity, and a phase of ${by2_phase_fixed}$ rad.
%
% S (high)
For the high frequency condition, \\by{{high}}, again circadian rhythm statistics 
were computed from the parameter estimates. $\\alpha = {by8_a_fixed}$ and 
$\\beta = {by8_b_fixed}$ yielded a group-level amplitude ${by8_amplitude_fixed}$ 
log units contrast sensitivity, and a phase of ${by8_phase_fixed}$ rad. 
The credibility intervals of the fixed effects all include zero. %which needs to be kept in mind as this.
% Explained variance
When consulting the conditional $R^2$, it can be seen that the full model does 
not explain considerably more variance than the null model despite the additional fixed and random effects. 
Similar to the other chromatic retinal mechanism, the absolute amount of explained 
variance is higher in the high-frequency condition, 
with $R^2_{{\\mathrm{{full}}}} = {by2_full_conditionalr2}$ and $R^2_{{\\mathrm{{null}}}} = {by2_null_conditionalr2}$, 
and less for the low-frequency condition, $R^2_{{\\mathrm{{full}}}} = {by8_full_conditionalr2}$ and 
$R^2_{{\\mathrm{{null}}}} = {by8_null_conditionalr2}$ for the high-frequency condition.
%
% Individual circadian parameters
When calculating and visualising amplitude and phase for each individual's 
contrast sensitivity according to the fitted full model for either of the frequency conditions, 
phase angles seem to be quite consistent between individuals. Amplitudes differ 
between individuals but variance seems to be higher in the \\by{{high}} than in \\by{{low}} 
while nominally there was no clear difference in the random slopes of the models.
"
    formatted_3 <- glue::glue(
      raw_3,
      by2_a_fixed = roundsci(by2_a_fixed),
      by2_b_fixed = roundsci(by2_b_fixed),
      by2_amplitude_fixed = roundsci(by2_amplitude_fixed),
      by2_phase_fixed = roundsci(by2_phase_fixed),
      by8_a_fixed = roundsci(by8_a_fixed),
      by8_b_fixed = roundsci(by8_b_fixed),
      by8_amplitude_fixed = roundsci(by8_amplitude_fixed),
      by8_phase_fixed = roundsci(by8_phase_fixed),
      by2_logbf = roundsci(by2_logbf),
      by8_logbf = roundsci(by8_logbf),
      by2_full_conditionalr2 = roundsci(by2_full_conditionalr2),
      by2_null_conditionalr2 = roundsci(by2_null_conditionalr2),
      by8_full_conditionalr2 = roundsci(by8_full_conditionalr2),
      by8_null_conditionalr2 = roundsci(by8_null_conditionalr2)
    )
    
    raw_4 <- "% LMS
\\paragraph{{Confirmatory tests on \\ach{{all}} mechanism}}
Finally, we also compared the full and the null models for the luminance channel, 
fitting a sinusoidal rhythm separately for the \\ach{{low}} and the \\ach{{high}} condition.
Parallel to the previous results, large \\ac{{logbf}} values again indicate that 
the data is better explained by the null than the full model. 
The absolute value of the \\ac{{logbf}} was quite similar for both \\ach{{all}} 
frequency conditions, ${ach2_logbf}$ for 2 Hz and ${ach8_logbf}$ for 8 Hz.
Amplitude and phase were again calculated from the parameter estimates of the sine 
and cosine components in each model.
%
% LMS (low)
For \\ach{{low}}, applying the formulas on the parameter estimates 
$\\alpha = {ach2_a_fixed}$ and $\\beta = {ach2_b_fixed}$ one obtains a group-level 
amplitude of ${ach2_amplitude_fixed}$ log units contrast sensitivity, and a phase 
of ${ach2_phase_fixed}$ rad.
%
% LME (high)
For \\ach{{high}}, the parameter estimates $\\alpha = {ach8_a_fixed}$ and 
$\\beta = {ach8_b_fixed}$ yield a group-level amplitude of ${ach8_amplitude_fixed}$ 
log units in contrast sensitivity, and a phase of ${ach8_phase_fixed}$ rad.
Conditional $R^2$ were higher for the full models than the null models but only by 
a few percentage points: in the low-frequency condition $R^2_{{\\mathrm{{full}}}} = {ach2_full_conditionalr2}$ 
was marginally higher than $R^2_{{\\mathrm{{null}}}} = {ach2_null_conditionalr2}$, and there was a 
positive difference for the high-frequency condition between $R^2_{{\\mathrm{{full}}}} = {ach8_full_conditionalr2}$ 
and $R^2_{{\\mathrm{{null}}}} = {ach8_null_conditionalr2}$. Interestingly, and opposite to the 
chromatic channels, in the lower-frequency condition the full and the null model 
explained more variance in the data, than the models in the high-frequency 
condition explained in the respective data. Also when calculating the amplitude 
and phase for each individual based on the fixed and the random effects, we find 
a much bigger dispersion of phase angles over a standard 24-hour day in the \\ach{{low}}.
"
    formatted_4 <- glue::glue(
      raw_4,
      ach2_a_fixed = roundsci(ach2_a_fixed),
      ach2_b_fixed = roundsci(ach2_b_fixed),
      ach2_amplitude_fixed = roundsci(ach2_amplitude_fixed),
      ach2_phase_fixed = roundsci(ach2_phase_fixed),
      ach8_a_fixed = roundsci(ach8_a_fixed),
      ach8_b_fixed = roundsci(ach8_b_fixed),
      ach8_amplitude_fixed = roundsci(ach8_amplitude_fixed),
      ach8_phase_fixed = roundsci(ach8_phase_fixed),
      ach2_logbf = roundsci(ach2_logbf),
      ach8_logbf = roundsci(ach8_logbf),
      ach2_full_conditionalr2 = roundsci(ach2_full_conditionalr2),
      ach2_null_conditionalr2 = roundsci(ach2_null_conditionalr2),
      ach8_full_conditionalr2 = roundsci(ach8_full_conditionalr2),
      ach8_null_conditionalr2 = roundsci(ach8_null_conditionalr2)
    )
    
    raw_5 <- "%\\paragraph{{Cosinor parameters for models}}
Table~\\ref{{tab:tbl_fitted_circadian_parameters}} again lists the group-level 
amplitudes and phases and also lists the individual. The average amplitudes are 
minimal. With values in the second decimal place (for \\ach{{all}} and \\rg{{all}} 
models) and the third decimal place (for \\by{{all}} models), the average amplitude 
magnitudes are effectively near zero.
% not applicable: Most tests and frequencies show that the standardised phase angles are inconsistent across participants, exhibiting substantial variability within the standard 24-hour rhythm. This variability is further reflected in the individual phase angles presented in Table \\ref{{tab:tbl_fitted_parameters}}.

\\paragraph{{Summary}}
In summary, the \\ac{{logbf}} values were consistently negative and large in magnitude 
(ranging from ${min_logbf}$ to ${max_logbf}$; all~$<~-4.61$), 
indicating decisive evidence in favour of the null model. 
By this criterion (\\ac{{logbf}} $<~-4.61$, equivalent to BF$_{10}~<~10^{2}$), 
the null model-comprising fixed and random intercepts without oscillatory (circular) variation was strongly preferred.
Consistent with this, the conditional R$^2$ comparison showed that the full model 
explained only slightly more variance in contrast sensitivity than the null model, 
indicating that most variance was explained by between-participant differences 
in mean contrast sensitivity.
Quantitatively, depending on the specific specification, the odds for the null 
over the full model ranged from ${min_odds_null}$ and ${max_odds_null}$, suggesting
that the absence of a circular process governing contrast sensitivity dynamics is more likely.
In the full models, fixed-effect estimates for the oscillatory components 
were small, and their $95\\%$ credible intervals generally included zero (with one exception). 
These components parameterized participant-specific rhythms with periods near 24 hours. 
Posterior uncertainty was not propagated to the derived amplitude and phase, 
but the estimated amplitudes were near zero and phases varied widely across participants, 
limiting the interpretability of amplitude and phase differences.
"
    formatted_5 <- glue::glue(
      raw_5,
      min_logbf = roundsci(min_logbf),
      #sub("e([+-]?)(\\d+)", " \\\times 10^{\\1\\2}", formatC(min_bf10, format = "e", digits = 2))
      max_logbf = roundsci(max_logbf),
      #sub("e([+-]?)(\\d+)", " \\\times 10^{\\1\\2}", formatC(max_logbf, format = "e", digits = 2))
      min_odds_null = sub(
        "e([+-]?)(\\d+)",
        " \\\\times 10^{\\1\\2}",
        formatC(min_odds_null, format = "e", digits = 2)
      ),
      max_odds_null = sub(
        "e([+-]?)(\\d+)",
        " \\\\times 10^{\\1\\2}",
        formatC(max_odds_null, format = "e", digits = 2)
      )
    )
    
    # Format string
    formatted_text <- paste(
      formatted_1,
      formatted_2,
      formatted_3,
      formatted_4,
      formatted_5,
      sep = "\n"
    )
    
    # Export the text to a .tex file
    save_tex(out_string = formatted_text,
             out_path = file.path(tex_dir, "tex_inference_tcs.tex"))
    
    return(formatted_text)
  }