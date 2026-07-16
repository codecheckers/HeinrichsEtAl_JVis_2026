import re
from pathlib import Path
from typing import List, Literal

import pandas as pd

# constants
_CONDITION_COL: str = "condition"
_PID_COL: str = "participant_id"
_DATETIME_COL: str = "datetime"
_MEAN_THRES_COL: str = "thres"
_SD_THRES_COL: str = "thres_sd"
_POSSIBLE_MODALITIES: list = ["spatialfreq", "tf"]
_BLOCK_COL: str = "block"
_TEST_COL: str = "test"
_CONTRSENS_COL: str = "contrast_sensitivity"
_FREQ_COL: str = "freq"
_PID_REGEX: str = r"(\d{3})"

tscn_yellow = "#FFD19A"
tscn_blue = "#42C6FD"
tscn_purple = "#55A2F1"
tscn_orange = "#F4B48D"
tscn_black = "#000000"

# functions
def load_raw(filepath: str) -> pd.DataFrame:
    """Load files with raw data saved from Metropsis.

    Args:
        filepath (str): filepath to CSV file

    Returns:
        pd.DataFrame: Raw metropsis data frame
    """
    # load data
    data = pd.read_excel(filepath)
    #data.columns = data.columns.str.lower()
    return data


def filter_patient_by_study(
    data: pd.DataFrame, patient_col: str, study_id: str
) -> pd.DataFrame:
    """Filter raw metropsis data frame by study ID in patient ID

    Args:
        data (pd.DataFrame): Data frame from raw metropsis data
        patient_col (str): Column name of patient ID
        study_id (str): study ID

    Returns:
        pd.DataFrame: Filtered data frame
    """
    # filter participants
    assert (
        data[patient_col].str.contains(study_id).any()
    ), f'Patient name in file does not contain Study ID "{study_id}"'
    is_from_study = (data[patient_col].str.contains(study_id)) & (
        data[patient_col].notna()
    )
    return data[is_from_study]


def filter_string_conditions(
    data: pd.DataFrame, condition_col: str, condition_list: list
) -> pd.DataFrame:
    """Filter conditions in metropsis data frame

    Args:
        data (pd.DataFrame): Data frame
        condition_names (list): Labels of metropsis conditions

    Returns:
        pd.DataFrame: Filtered data frame
    """
    is_valid_condition = data[condition_col].str.contains("|".join(condition_list))
    return data[is_valid_condition]


def filter_conditions(
    data: pd.DataFrame, condition_col: str, condition_list: list
) -> pd.DataFrame:
    """Filter conditions in metropsis data frame

    Args:
        data (pd.DataFrame): Data frame
        condition_col (str): Column name to filter by
        condition_names (list): Strings or integers to match

    Returns:
        pd.DataFrame: Filtered data frame
    """
    is_valid_condition = data[condition_col].isin(condition_list)
    return data[is_valid_condition]


def get_modality_from_cols(data: pd.DataFrame) -> str:
    """Extract modality from data frame columns

    Args:
        data (pd.DataFrame): Metropsis dataframe at any processing stage

    Returns:
        str: string for modality
    """
    modality_list = [
        re.sub(r".* \( (.*) = .* \)", r"\1", s)
        for s in data.columns
        if "threshold" in s
    ]
    if modality_list == []:
        modality_list = [col for col in data.columns if col in _POSSIBLE_MODALITIES]
    return modality_list[0]


def filter_columns_by_substr(data: pd.DataFrame, substr: str) -> list:
    """Filter data frame by column name

    Args:
        data (pd.DataFrame): Data frame
        substr (str): Substring that must be contained in the dataframe columns

    Returns:
        list: List of column names
    """
    which_cols = pd.Series(data.columns).str.contains(substr)
    return data.columns[which_cols].to_list()


def metropsis_thres_to_long(data: pd.DataFrame, id_vars: list) -> pd.DataFrame:
    """Takes metropsis raw columns and converts threshold columns into long format.

    Args:
        data (pd.DataFrame): Data frame in wide format, containing columns with substring threshold
        id_vars (list): fixed variables to keep

    Returns:
        pd.DataFrame: Data frame in long format, containing columns "thres" and "thres_sd".
    """

    # modality = get_modality_from_cols(data)
    data.columns = [
        re.sub(r"(.*) Threshold \( .* = (.*) \)", r"\1\2", i) for i in data.columns
    ]
    data = pd.wide_to_long(
        data, stubnames=["Mean", "SD"], i=id_vars, j=_FREQ_COL, suffix=".*"
    )
    data.reset_index(inplace=True)
    data.rename(columns={"Mean": _MEAN_THRES_COL, "SD": _SD_THRES_COL}, inplace=True)

    # filter unavailable stats
    data = data[data[_MEAN_THRES_COL].notna() & data[_SD_THRES_COL].notna()]
    return data


def series_to_iso_datetime(ts: pd.Series) -> pd.Series:
    """Turn pandas series into datetime series in iso format.

    Args:
        ts (pd.Series): Times series

    Returns:
        pd.Series: ISO formatted time series.
    """
    ts = pd.to_datetime(ts, format="ISO8601")  # "%Y-%m-%dT%H:%M:%S"
    ts = ts.map(lambda x: x.isoformat())
    ts = pd.to_datetime(ts)
    return ts


def extract_pids_from_list(patient_list: list) -> list:
    """Extract participant id list from other list

    Args:
        patient_list (list): List of strings that contain partiticpand ID

    Returns:
        list: List of participant IDs
    """
    pid_list = [int(re.search(_PID_REGEX, patient).group()) for patient in patient_list]
    return pid_list


def process_raw(data: pd.DataFrame, study_id: str = "civibe") -> pd.DataFrame:
    """Processes raw data frame from Metropsis.

    Args:
        data (pd.DataFrame): Data Frame
        study_id (str, optional): Study ID that is used as last name of participant. Defaults to "civibe".

    Returns:
        pd.DataFrame: _description_
    """
    # additional arguments (raw and new variable names)
    patient_col: str = "Patient Name"  # data.columns[0]
    date_col: str = "Date"  # data.columns[1]
    condition_col: str = "Condition"
    condition_list: list = ["achromatic", "red-green", "blue-yellow"]
    block_manual_col: str = "Block" # manually added columns to encode Block of experiment

    id_vars = [patient_col, date_col, condition_col]
    if "Block" in data.columns:
        id_vars.append(block_manual_col)
        print("Manually added column 'Block' exists.")

    data = filter_patient_by_study(data, patient_col, study_id)
    data = filter_conditions(data, condition_col, condition_list)

    # delete empty columns
    data = data.dropna(axis=1, how='all')

    # filter only relevant columns
    thres_vars = filter_columns_by_substr(data, substr="Threshold")
    select_vars = id_vars + thres_vars
    keep_cols = data.columns.intersection(select_vars)
    data = data[keep_cols]

    if thres_vars:
        # delete empty rows in list of columns
        data = data.dropna(subset=thres_vars, how="all")

        # wide to long
        data = metropsis_thres_to_long(data, id_vars)

        # calculate contrast sensitivity
        data[_CONTRSENS_COL] = 1 / data[_MEAN_THRES_COL]

    # format columns
    data[date_col] = series_to_iso_datetime(ts=data[date_col])
    patient_list = data[patient_col].values.tolist()
    data[patient_col] = extract_pids_from_list(patient_list)

    # rename columns
    data = data.rename(columns={patient_col: _PID_COL, date_col: _DATETIME_COL, condition_col: _CONDITION_COL})
    data.columns = data.columns.str.lower()
    data.columns = data.columns.str.replace(" ", "_")

    return data


def depr_add_blocks_from_timestamps(
    data: pd.DataFrame,
    block_delta_min: int = 70,
    block_col: str = _BLOCK_COL,
    start_idx: int = 1,
) -> pd.DataFrame:
    """Add column with block number from time series.

    Args:
        data (pd.DataFrame): DataFrame
        block_delta_min (int, optional): _description_. Defaults to 60.

    Returns:
        pd.DataFrame: DataFrame
    """
    pid_col = _PID_COL
    datetime_col = _DATETIME_COL

    data = data.sort_values(by=datetime_col, axis=0)
    data[block_col] = None
    for pid in data[pid_col].unique():
        # filter data by participant
        df = data.loc[data[pid_col] == pid, :]

        # build groups with > 60 min distance
        idx = start_idx
        dt = df[datetime_col].unique()
        for d0, d1 in zip(dt, dt[1:]):
            df.loc[df[datetime_col] == d0, block_col] = idx
            time_difference = pd.Timestamp(d1) - pd.Timestamp(d0)
            if time_difference >= pd.Timedelta(block_delta_min, "min"):
                idx += 1
            if d1 == dt[-1]:
                df.loc[data[datetime_col] == d1, block_col] = idx
        data.loc[data[pid_col] == pid, :] = df

    return data


def add_tests_per_block(
    data: pd.DataFrame, group_vars: List[str], test_col: str = _TEST_COL
) -> pd.DataFrame:
    """Add number of tests performed within one experimental block or times point.
    For each block, the test number is assigned sequentially starting from 1.

    Args:
        data (pd.DataFrame): Data frame.
        group_vars (list[str]): Ideally ["participant_id", "block", "condition", "spatialfreq"]

    Returns:
        pd.DataFrame: Data frame.
    """
    if test_col not in data.columns:
        data[test_col] = 0

    data[test_col] = data.groupby(group_vars).cumcount() + 1
    # grouped = data.groupby(group_vars)
    # for _, group in grouped:
    #     idx = group.index.values
    #     n_rep = len(data.loc[idx])
    #     data.loc[idx, test_col] = list(range(1, n_rep + 1))

    return data


def depr_add_experiment_specs(data: pd.DataFrame, block_delta_min = 60):
    """Add specification of block and test repecition to data frame.
    Only works if the longest period of is block_delta_min which is also the 
    period that separates the blocks

    Args:
        data (pd.DataFrame): Data frame

    Returns:
        pd.Dataframe: Data frame with added columns ("block", "test")
    """
    block_string_list = [s for s in data.columns if "block" in s.lower()]
    if len(block_string_list) == 1: 
        block_col = block_string_list[0]
    else:
        block_col = "block"
        data = depr_add_blocks_from_timestamps(
            data=data, block_col=block_col, block_delta_min=block_delta_min
        )
    # modality = get_modality_from_cols(data)
    id_cols = [_PID_COL, block_col, _CONDITION_COL, _FREQ_COL]
    data = add_tests_per_block(data, group_vars=id_cols)
    return data


def select_experimental_session(
    data: pd.DataFrame, startdate: pd.Timestamp, enddate: pd.Timestamp
) -> pd.DataFrame:
    """Select data in data frame based on starting and end datetime.

    Args:
        data (pd.DataFrame): Data frame
        experiment_startdate (pd.Timestamp): start date of experimental session
        days (int, optional): duration of experimental session in days. Defaults to 1.

    Returns:
        pd.DataFrame: Pruned data frame
    """
    select_experiment_period = (data[_DATETIME_COL] >= startdate) & (
        data[_DATETIME_COL] <= enddate
    )
    data = data[select_experiment_period]
    data = data.reset_index(drop=True)
    return data


def filter_by_experiment_specs(
    data: pd.DataFrame,
    participant_list: list[int] | None,
    start_and_end: tuple[pd.Timestamp] | None,
    freq_list: list | None,
) -> pd.DataFrame:
    """Data preprocessing for metropsis data.

    Args:
        data (pd.DataFrame): Data frame
        participant_list (list[int] | None): Participant ID list
        start_and_end (tuple): Start and end of experiment in datetime format.
        freq_list (list | None, optional): List of temporal or spatial frequencies to select. Defaults to [0.4, 4].

    Returns:
        pd.DataFrame: Data frame
    """
    if participant_list is not None:
        data = data[data[_PID_COL].isin(participant_list)]
    if start_and_end is not None:
        startdate, enddate = start_and_end
        data = select_experimental_session(data, startdate, enddate)
    if freq_list is not None:
        # modality = get_modality_from_cols(data)
        data = data[data[_FREQ_COL].isin(freq_list)]
    return data


def full_data_preparation(
    filepath: Path,
    study_id: str,
    participant_list: list = None,
    start_and_end: tuple = None,
    freq_list: list[float] = None,
):
    """Full data preparation pipeline from raw metropsis data to filtered and
    preprocessed data frame

    Args:
        filepath (Path): Filepath to raw metropsis data
        study_id (str): Study ID, e.g. "civibe"
        participant_list (list[int]): List of participants
        start_and_end (tuple): tuple with start and end datetime in datetime
        format
        freq_list (list[float]): list of frequencies, spatial or temporal
    """
    data = load_raw(filepath)
    data = process_raw(data, study_id=study_id)
    # data = filter_by_experiment_specs(
    #     data=data,
    #     participant_list=participant_list,
    #     start_and_end=start_and_end,
    #     freq_list=freq_list,
    # )
    # data = depr_add_experiment_specs(data)
    return data
