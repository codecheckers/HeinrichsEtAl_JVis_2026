import os
from datetime import datetime, timedelta

import numpy as np
import pandas as pd
import pymetropsis.preprocess.utils_metropsis as utils_metropsis

# ----- Script -----
print(os.getcwd())


def add_datetime_block(
    data,
    start_datetime="2024-01-01 08:45",
    new_col="datetime_block",
    block_interval=timedelta(hours=3, minutes=45),
) -> pd.DataFrame:
    """Add a 'hours_since_start' column to the dataframe based on the 'block' column.

    Args:
        data (pd.DataFrame): The input dataframe containing a 'block' column.
        start_datetime (str or datetime): The start datetime corresponding to block 0. Defaults to "2024-01-01 08:45".
        new_col (str): The name of the new column to store calculated datetime values. Defaults to "datetime_block".

    Returns:
        pd.DataFrame: The updated dataframe with approximate or average datetime values a block.
    """
    if isinstance(start_datetime, str):
        start_datetime = pd.to_datetime(start_datetime) 

    # Calculate 'hours_since_start' for each row
    data[new_col] = data["block"].apply(
        lambda block: start_datetime + block * block_interval
    )

    return data


def add_standardized_start_time(
    data,
    datetime_col="datetime",
    new_datetime_col="datetime_standard",
    start_datetime="2024-01-01 08:00",
) -> pd.DataFrame:
    """Standardize the start time for each participant so that their earliest timestamp
    aligns with the specified start datetime.

    Args:
        data (pd.DataFrame): The input dataframe containing a datetime column.
        datetime_col (str): The column name containing the datetime values provided in the dataframe to be used as reference. Defaults to "datetime".
        new_datetime_col (str): The column name for the new column standardized datetime values. Defaults to "datetime_standard".
        start_datetime (str or datetime): The standardized start datetime for all participants. Defaults to "2024-01-01 08:00".

    Returns:
        pd.DataFrame: The updated dataframe with adjusted datetime values in the new column.
    """
    if isinstance(start_datetime, str):
        start_datetime = pd.to_datetime(start_datetime)  # Convert to datetime if string

    # Convert the datetime column to pandas datetime if not already
    data[datetime_col] = pd.to_datetime(data[datetime_col])

    # Find the earliest time for each participant and compute the offset
    offsets = data.groupby("participant_id")[datetime_col].transform("min")
    data[new_datetime_col] = data[datetime_col] - offsets + start_datetime

    return data


def calculate_time_since_start(
    data_series: pd.Series, start_datetime: pd.Timestamp
) -> pd.Series:
    """Calculates hours since start as decimal.

    Args:
        data_series (pd.Series): Column in data frame with pd.Timestamp
        start_datetime (pd.Timestamp): Start time.

    Returns:
        pd.Series: Column with floats.
    """
    if isinstance(start_datetime, str):
        start_datetime = pd.to_datetime(start_datetime)  # Convert to datetime if string

    return (data_series - start_datetime).dt.total_seconds() / 3600


# MANUAL ACTION REQUIRED: default paths below point to the internal network
# drive (mount kfs/tscn-projects at /Volumes/tscn-projects before running).
# They cannot be made relative since the raw data is not distributed with
# this repository.
def get_data(
    data_filepath="/Volumes/tscn-projects/civibe/data/raw/group/metropsis/fd_civibe/fd_civibe_TCS-2e.xls",
    meta_filepath="/Volumes/tscn-projects/civibe/data/raw/group/metropsis/fd_civibe/20241106_fd_civibe_TCS-2e_blocks.xls",
    output_filepath="/Volumes/tscn-projects/civibe/data/derivatives/group/metropsis/fd_civibe/20241204_fd_civibe_TCS-2e.csv",
    standardized_wake_datetime=pd.to_datetime("2024-01-01 07:00"),
    standardized_start_datetime=pd.to_datetime("2024-01-01 08:00"),
    block_duration = pd.Timedelta(timedelta(hours=3, minutes=45))
):
    """Clean and preprocess data for analysis and plotting.

    Args:
        data_filepath (str, optional): Path to the raw data file. Defaults to the provided example path.
        meta_filepath (str, optional): Path to the metadata file with manually added blocks. Defaults to the provided example path.
        output_filepath (str, optional): Path to save the processed file as a CSV. Defaults to the provided example path.
        standardized_wake_datetime (pd.Timestamp, optional): Standardized wake-up time for participants. Defaults to "2024-01-01 07:00".
        standardized_start_datetime (pd.Timestamp, optional): Standardized start time for the experiment. Defaults to "2024-01-01 08:00".
        block_duration (pd.Timedelta, optional): Duration of each block. Defaults to 3 hours and 45 minutes.
    """
    derivatives_filepath = output_filepath

    # Standardized start time for the first block is the midpoint of the first block
    # Calculate from standardized_start_datetime plus third of the block duration (1 hour 15 minutes is the first half of the wake period for 2:1 wake-sleep schedule)
    start_datetime_block = (
        pd.to_datetime(standardized_start_datetime) + (block_duration / 3)
    )

    # Load data
    data = utils_metropsis.full_data_preparation(
        filepath=data_filepath,
        study_id="civibe",
    )

    # Get manually assigned blocks (exact same file, but with block and without data)
    meta = utils_metropsis.full_data_preparation(
        filepath=meta_filepath,
        study_id="civibe",
    )

    # Add manual block to data
    common_columns = list(meta.columns.intersection(data.columns))
    data = pd.merge(data, meta, on = common_columns, how = "left")

    # In fd_civibe, some participant IDs were wrongly selected, and need to be replaced.
    filepath_tree_parts = os.path.normpath(data_filepath).split(os.sep)
    if "fd_civibe" in filepath_tree_parts:
        # Manually replacing wrongly selected IDs
        data.loc[data.participant_id == 106, "participant_id"] = 201
        data.loc[data.participant_id == 104, "participant_id"] = 204
        data.loc[
            (data.participant_id == 203) & (data["datetime"].dt.year == 2024), "participant_id"
        ] = 202
        data.loc[(data.participant_id == 204) & (data["datetime"].dt.month == 5),"participant_id"] = 206
        data.loc[(data.participant_id == 204) & (data["datetime"].dt.month == 7),"participant_id"] = 211
        data.loc[(data.participant_id == 211) & (data["datetime"].dt.month == 8),"participant_id"] = 210
        print(
            "Replacing wrongly selected participant IDs (identified upon visual inspection of the raw data frame, and protocol notes) with correct ones."
        )

        # Exclude invalid data
        data = data.loc[data.participant_id != 200]
        print(
            "Excluding participant 200 due to inaccurate stimuli (Night mode selected during experiement)."
        )

    # Count missing values in 'block' column
    # print(data["block"].isna().sum())
    # Exclude data with missing block
    data = data.loc[data["block"].notna()]
    # Add test numbers
    data = utils_metropsis.add_tests_per_block(
        data=data, group_vars=["participant_id", "block", "condition", "freq"]
    )

    data = add_datetime_block(
        data=data, start_datetime=start_datetime_block, block_interval=block_duration
    )  # "2024-01-01 09:15"
    data = add_standardized_start_time(data=data, start_datetime=start_datetime_block)
    data["hours_since_start"] = calculate_time_since_start(
        data["datetime_standard"], start_datetime=standardized_start_datetime
    )
    data["hours_since_wakeup"] = calculate_time_since_start(
        data["datetime_standard"], start_datetime=standardized_wake_datetime
    )
    data["hours_since_start_block"] = calculate_time_since_start(
        data["datetime_block"], start_datetime=standardized_start_datetime
    )
    data["hours_since_wakeup_block"] = calculate_time_since_start(
        data["datetime_block"], start_datetime=standardized_wake_datetime
    )
    data["tcs"] = data["contrast_sensitivity"]
    data["ln_tcs"] = np.log(data["contrast_sensitivity"])
    data["log_tcs"] = np.log10(data["contrast_sensitivity"])

    os.makedirs(os.path.dirname(derivatives_filepath), exist_ok=True)
    data.to_csv(path_or_buf=derivatives_filepath)
    print(f"Processed file saved in: {derivatives_filepath}")


def main(out_path=None):
    """Main function to run the cleaning process. Includes loading data, cleaning, and saving the
    processed file from pilot and main experimental periods.
    Args:
        out_path (str, optional): Path to save the processed data. Defaults to None."""
    # MANUAL ACTION REQUIRED: paths below point to the internal network
    # drive (mount kfs/tscn-projects at /Volumes/tscn-projects before
    # running); they cannot be made relative.
    # Process valid data from last pilot
    get_data(
        data_filepath="/Volumes/tscn-projects/civibe/data/pilot-40/group/metropsis/Pilot_TCS-2e.xls",
        meta_filepath="/Volumes/tscn-projects/civibe/data/pilot-40/group/metropsis/Pilot_TCS-2e_blocks.xls",
        output_filepath="/Volumes/tscn-projects/civibe/data/derivatives/group/metropsis/fd_civibe/20250729_Pilot_TCS-2e.csv",
    )

    # Process data from main experimental period
    get_data(         
        data_filepath="/Volumes/tscn-projects/civibe/data/raw/group/metropsis/fd_civibe/fd_civibe_TCS-2e.xls",
        meta_filepath="/Volumes/tscn-projects/civibe/data/raw/group/metropsis/fd_civibe/20241106_fd_civibe_TCS-2e_blocks.xls",
        output_filepath="/Volumes/tscn-projects/civibe/data/derivatives/group/metropsis/fd_civibe/20250327_fd_civibe_TCS-2e.csv",
    )

    # Merge both dataframes
    pilot_data = pd.read_csv(
        "/Volumes/tscn-projects/civibe/data/derivatives/group/metropsis/fd_civibe/20250729_Pilot_TCS-2e.csv"

    )
    main_data = pd.read_csv(
        "/Volumes/tscn-projects/civibe/data/derivatives/group/metropsis/fd_civibe/20250327_fd_civibe_TCS-2e.csv"
    )
    merged_data = pd.concat([pilot_data, main_data], ignore_index=True)
    merged_data.to_csv(
        out_path if out_path else "/Volumes/tscn-projects/civibe/data/derivatives/group/metropsis/fd_civibe/20250327_fd_civibe_TCS-2e_merged.csv",
        index=False,
    )
    print(f"Processed file saved in: {out_path}")

if __name__=="__main__":
    main()
