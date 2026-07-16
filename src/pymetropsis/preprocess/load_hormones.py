import os
import argparse
import re

import numpy as np
import pandas as pd

# Repo root, resolved relative to this file's location.
PROJ_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..")) + os.sep

# function
def get_salivette_log(file_path: str):
    raw_data = pd.read_excel(file_path)
    raw_data = raw_data.rename(
        columns={"Saliva sample ID": "sample_id", "Timestamp": "timestamp"}
    )

    raw_data = raw_data.dropna(subset=["sample_id"])
    raw_data.head()

    # mutate columns into multiple different columns (change structure)
    data = raw_data.assign(
        sample_id=raw_data["sample_id"],
        study_id=raw_data["sample_id"].str.extract("(CiViBe)", expand=False),
        participant_id=raw_data["sample_id"].str.extract(
            "(?<=CiViBe_)(\d+)", expand=False
        ),
        session_id=raw_data["sample_id"].str.extract(
            "(?<=_)(DL|FD|LE|DE|CR)(?=_)", expand=False
        ),
        sample_number=raw_data["sample_id"]
        .str.extract("(\d+)$", expand=False)
        .astype(int),
        source=os.path.basename(file_path),
    )
    
    # Change session_id from pilot into naming from main study (CR -> FD, and DE -> DL)
    data.loc[data["session_id"] == "CR", "session_id"] = "FD"
    data.loc[data["session_id"] == "DE", "session_id"] = "DL"

    data["timestamp"] = pd.to_datetime(data["timestamp"], format="%Y-%m-%d %H:%M:%S.%f")
    # Sort data by timestamp
    data["timestamp_number"] = data.sort_values(["participant_id", "session_id", "timestamp"], ascending=True).groupby(["participant_id", "session_id"]).cumcount()
    return data


def create_time_lookups(standard_wakeup: str = "2024-01-01 07:00:00") -> dict:
    """Create lookup tables for FD, DL, and LE sample times based on ID number, e.g. 0 = 7:00, 1 = 7:35, etc.

    Args:
        standard_wakeup (str, optional): UNUSED. Defaults to None; internal default is 2024-01-01 23:00:00.

    Returns:
        dict: Dictionary to match ID index with standard time (standardized to 7:00 am wake up) depending on attended session
    """
    standard_evening_start = pd.to_datetime(standard_wakeup) + pd.Timedelta(
        12, unit="h"
    )
    # "2024-01-01 19:00:00"

    # FD times
    # First create the main pattern (11 repetitions of 4 samples each = 44 samples)
    main_pattern = [0]
    current_time = 0

    # Create 11 repetitions
    for _ in range(11):
        # Add 3 steps of 45 minutes
        for _ in range(3):
            current_time += 45
            main_pattern.append(current_time)

        # Add 1 step of 90 minutes
        current_time += 90
        main_pattern.append(current_time)

    # Starting 1h:15 (45 min + 30 min) after wake up
    main_pattern = np.add(75, main_pattern)[:-1]

    # Create DataFrame with all samples
    # Add 2 for the preliminary samples
    fd_times = pd.DataFrame({"timestamp_number": range(len(main_pattern) + 2)})

    # Add preliminary samples after wake up / before experiment start
    fd_times.loc[0, "minutes_after_wakeup"] = 0  # Sample 00 at +0:00
    fd_times.loc[1, "minutes_after_wakeup"] = 35  # Sample 01 at +0:35

    # Add main pattern starting at index 2
    for i, minutes in enumerate(main_pattern):
        fd_times.loc[i + 2, "minutes_after_wakeup"] = minutes

    # Convert to hours and add clock time
    fd_times["hours_after_wakeup"] = fd_times["minutes_after_wakeup"] / 60
    fd_times["standard_datetime"] = pd.to_datetime(standard_wakeup) + pd.to_timedelta(
        fd_times["minutes_after_wakeup"], unit="m"
    )
    fd_times["standard_clocktime"] = fd_times["standard_datetime"].dt.strftime("%H:%M")

    # DL/LE times (30-minute intervals starting at 19:00)
    evening_samples = 11
    dl_le_times = pd.DataFrame(
        {"timestamp_number": range(evening_samples)}
    )  # Covers both DL (9 samples) and LE (11 samples)
    dl_le_times["minutes_after_wakeup"] = dl_le_times["timestamp_number"] * 30
    dl_le_times["hours_after_wakeup"] = (
        evening_samples + dl_le_times["minutes_after_wakeup"] / 60
    )
    dl_le_times["standard_datetime"] = pd.to_datetime(
        standard_evening_start
    ) + pd.to_timedelta(
        dl_le_times["minutes_after_wakeup"], unit="m"
    )  # .dt.total_seconds().astype(int).apply(pd.Timestamp.fromtimestamp)
    dl_le_times["standard_clocktime"] = dl_le_times["standard_datetime"].dt.strftime(
        "%H:%M"
    )

    return {"fd": fd_times, "dl_le": dl_le_times}


def load_all_novolytix_files(in_dir, file_pattern:re.Pattern[str]=r"\d+_results_civibe\.xlsx$"):
    """Gather all data files from Novolytix. Specific format required, with the
    same columns, and 

    Args:
        in_path (_type_): directory with files

    Returns:
        pd.Dataframe: dataframe with all hormone data
    """
    # Load files
    files = [
        os.path.join(in_dir, f)
        for f in os.listdir(in_dir)
        if re.match(file_pattern, f)
    ]
    files.sort()
    print("Found files:")
    print(" - " + "\n - ".join(files))

    combined_data = pd.concat([get_noxolytix_file(file) for file in files])

    return combined_data


# MANUAL ACTION REQUIRED: default paths below point to the internal network
# drive (mount kfs/tscn-projects at /Volumes/tscn-projects before running).
# They cannot be made relative since the raw data is not distributed with
# this repository.
def get_data(novolytix_dir="/Volumes/tscn-projects/civibe/data/raw/group/saliva", log_path="/Volumes/tscn-projects/civibe/data/raw/group/saliva/20240930_civibe_saliva-log.xlsm"):
    combined_data = load_all_novolytix_files(
        in_dir=novolytix_dir,
        file_pattern=r"\d+_results_civibe\.xlsx$",
    )
    log_data = get_salivette_log(log_path)

    merged = pd.merge(combined_data, log_data, on="sample_id", suffixes=("", "_dup"))
    # keep all data except overlap between analysized and logged files
    data = merged[
        combined_data.columns.tolist()
        + list(set(log_data.columns) - set(combined_data.columns))
    ].sort_values(["timestamp"])

    time_lookups = create_time_lookups()
    fd_data = data[data["session_id"] == "FD"].merge(
        time_lookups["fd"][["timestamp_number", "hours_after_wakeup", "standard_clocktime", "standard_datetime"]],
        on="timestamp_number",
        suffixes=("_other", "_fd"),
    )
    nonfd_data = data[data["session_id"] != "FD"].merge(
        time_lookups["dl_le"][
            ["timestamp_number", "hours_after_wakeup", "standard_clocktime", "standard_datetime"]
        ],
        on="timestamp_number",
        suffixes=("_fd", "_other"),
    )
    data = pd.concat([fd_data, nonfd_data])

    return data


def get_noxolytix_file(file_path: str) -> pd.DataFrame:
    """Load and process data from an Excel file."""
    if not os.path.exists(file_path):
        raise FileNotFoundError(f"Cannot find file: {file_path}")

    print(f"Loading file: {file_path}")
    raw_data = pd.read_excel(file_path)
    # print("Raw data first few rows:")
    # print(raw_data.head())

    data = raw_data.dropna(
        subset=["sample_id"]
    )  # Remove rows with missing sample_id
    data = data.assign(
        sample_id=data["sample_id"],
        melatonin_concentration=pd.to_numeric(
            data["melatonin_concentration"], errors="coerce"
        ),
        cortisol_concentration=pd.to_numeric(
            data["cortisol_concentration"], errors="coerce"
        ),
        study_id=data["sample_id"].str.extract("(CiViBe)", expand=False),
        participant_id=data["sample_id"].str.extract("(?<=CiViBe_)(\d+)", expand=False),
        session_id=data["sample_id"].str.extract(
            "(?<=_)(DL|FD|LE|DE|CR)(?=_)", expand=False
        ),
        sample_number=data["sample_id"].str.extract("(\d+)$", expand=False).astype(int),
        source=os.path.basename(file_path),
    )
    # Change session_id from pilot into naming from main study (CR -> FD, and DE -> DL)
    data.loc[data["session_id"] == "CR", "session_id"] = "FD"
    data.loc[data["session_id"] == "DE", "session_id"] = "DL"

    empty_rows = data[data["melatonin_concentration"].isna()]
    if len(empty_rows) >= 1:
        print("Rows with non-numeric melatonin values:")
        print(empty_rows)
    data = data[~data["melatonin_concentration"].isna()]

    # time_lookups = create_time_lookups()
    # fd_data = data[data["session_id"] == "FD"].merge(
    #     time_lookups["fd"][["sample_number", "hours_after_wakeup", "standard_clocktime"]],
    #     on="sample_number",
    #     suffixes=("_other", "_fd"),
    # )
    # nonfd_data = data[data["session_id"] != "FD"].merge(
    #     time_lookups["dl_le"][["sample_number", "hours_after_wakeup", "standard_clocktime"]],
    #     on="sample_number",
    #     suffixes=("_fd", "_other"),
    # )
    # data = pd.concat([fd_data, nonfd_data])

    data = data[
        [
            "sample_id",
            "study_id",
            "participant_id",
            "session_id",
            "sample_number",
            "melatonin_concentration",
            "cortisol_concentration",
            "source",
        ]
    ]
    # data = data[~data["melatonin_concentration"].isna()]
    # print("Processed data summary:")
    # print(data.describe())

    return data


def average_hormones_over_time(data: pd.DataFrame, agg_over: str = "timestamp_number") -> pd.DataFrame:
    """Averages in pandas dataframe; requires time variable (from lookup). 

    Args:
        data (pd.Dataframe): data from merged / cleaned Novolytix dataframe.
        agg_over (str, optional): column name. Defaults to "timestamp_number".

    Returns:
        pd.DataFrame: aggregated / summary data
    """
    agg_data = (
        data.groupby(agg_over)
        .agg(
            # Keep informative time columns
            hours_after_wakeup=pd.NamedAgg(column="hours_after_wakeup", aggfunc="first"),
            # Calculate summary statistics
            mean_melatonin=pd.NamedAgg("melatonin_concentration", "mean"),
            mean_cortisol=pd.NamedAgg("cortisol_concentration", "mean"),
            se_melatonin=pd.NamedAgg(
                "melatonin_concentration",
                lambda x: x.std() / np.sqrt(len(x)),
            ),
            std_melatonin=pd.NamedAgg(
                "melatonin_concentration",
                lambda x: x.std(),
            ),
            se_cortisol=pd.NamedAgg(
                "cortisol_concentration", lambda x: x.std() / np.sqrt(len(x))
            ),
            std_cortisol=pd.NamedAgg(
                "cortisol_concentration",
                lambda x: x.std(),
            ),
        )
        .reset_index()
    )

    return agg_data


def find_logged_id_timestamp_mismatch(log_data) -> pd.DataFrame:
    """Check if both columns are sorted ascending and return participant / session IDs to see which are not

    Args:
        log_data (_type_): data from small lab log with columns ["participant_id", "session_id", "timestamp"]

    Returns:
        pd.DataFrame: dataframe with extracted timestamp where row is going reversed, 
        and previous row
    """
    #

    # Get row and previous row to inspect mismatch in sorting
    # Sort the DataFrame by 'timestamp'
    data_sorted = log_data.sort_values(
        ["participant_id", "session_id", "timestamp"], ascending=True
    )

    # Group by 'participant_id' and 'session_id', then apply a lambda function that checks where 'sample_number' decreases from the previous row
    incorrectly_ordered_samples = data_sorted.groupby(
        ["participant_id", "session_id"]
    ).apply(lambda group: group["sample_number"].diff().lt(0))

    # Flatten the MultiIndex result and filter out the False values
    incorrectly_ordered_samples = incorrectly_ordered_samples.droplevel([0, 1])
    incorrect_indices = incorrectly_ordered_samples[incorrectly_ordered_samples].index

    # Filter the original (sorted) DataFrame to get just the inconsistent rows
    inconsistencies = data_sorted.loc[incorrect_indices]

    def previous_and_current(index):
        new_index_list = [i - 1 for i in list(index) if i - 1 >= 0] + list(index)
        new_index_list.sort()
        return new_index_list

    # Get both current inconsistent rows and their previous rows
    inconsistency_and_predecessor_indices = previous_and_current(incorrect_indices)
    return data_sorted.loc[inconsistency_and_predecessor_indices]


def main(novolytix_dir, log_path, out_path):
    save_hormone_info_and_data = True

    data = get_data(
        novolytix_dir=novolytix_dir,
        log_path=log_path,
    )
    if save_hormone_info_and_data:
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        print("Saved file: ", out_path)
        data.to_csv(out_path)
    return data


if __name__ == "__main__":
    # Create the argument parser
    parser = argparse.ArgumentParser(description="Your script description")
    parser.add_argument("-in_dir", required=None, help="Input directory with Novolytix files")
    parser.add_argument("-log_path", default=None, help="Path of logged saliva timestamps")
    parser.add_argument(
        "-out_path", default=None, help="Output path for pre-processed file"
    )

    # Parse the command line arguments
    args = parser.parse_args()

    # If out_path is not provided, calculate the default value
    # MANUAL ACTION REQUIRED: novolytix_dir/log_path point to the internal
    # network drive (mount kfs/tscn-projects at /Volumes/tscn-projects
    # before running); they cannot be made relative.
    novolytix_dir = "/Volumes/tscn-projects/civibe/data/raw/group/saliva"
    if not args.in_dir and os.path.isdir(novolytix_dir):
        args.in_dir = novolytix_dir
        print("in_dir: ", novolytix_dir)

    log_path = "/Volumes/tscn-projects/civibe/data/raw/group/saliva/20250728_civibe_saliva-log.xlsm"
    if not args.log_path and os.path.isfile(log_path):
        args.log_path = log_path
        print("log_path: ", log_path)

    out_dir = os.path.join(PROJ_DIR, "data")
    if not args.out_path and os.path.isdir(out_dir):
        out_path = os.path.join(
            out_dir, "raw", "clean_saliva_data.csv"
        )  # "20250728_saliva_data.csv"
        args.out_path = out_path
        print("out_path: ", out_path)

    main(
        novolytix_dir=args.in_dir, log_path=args.log_path, out_path=args.out_path
    )
