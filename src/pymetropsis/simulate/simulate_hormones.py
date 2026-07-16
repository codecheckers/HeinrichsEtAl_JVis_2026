import argparse
from pathlib import Path

import numpy as np
import pandas as pd

from pymetropsis.preprocess.load_hormones import create_time_lookups

# --- Constants ---
# # Base project directory = one level above "src"
PROJECT_ROOT = Path(__file__).resolve().parents[3]
DATA_DIR = PROJECT_ROOT / "data"

# --- Functions ---
def create_melatonin_parameters(n_cases:int=24, tau=None, harmonics:bool=False):
    """
    Create melatonin parameters for simulated cases with varying amplitude and phase.
    This function generates a DataFrame containing simulated melatonin parameters for a given 
    number of cases. The parameters include participant IDs, session IDs, circadian period (tau), 
    mesor, amplitude, phase, and their second harmonic counterparts. The values are generated 
    based on specified rules and patterns to simulate realistic variations.
    Args:
        n_cases (int, optional): 
            The number of simulated cases to generate. Defaults to 24.
        tau (Union[tuple, int, float], optional): 
            The circadian period (tau) for the simulated cases. If a tuple is provided, 
            tau values are sampled uniformly between the tuple's min and max values. 
            If an integer or float is provided, the same tau value is used for all cases. 
            Defaults to (23, 25).
    Returns:
        pd.DataFrame: 
            A DataFrame containing the following columns:
            - participant_id: Unique identifier for each participant.
            - session_id: Session identifier, fixed as "FD" for all cases.
            - tau: Circadian period for each case.
            - mesor: Constant baseline level of melatonin, fixed at 2 for all cases.
            - amplitude: Fundamental amplitude, increasing every 4 cases.
            - phase_deg: Fundamental phase in degrees, cycling through 0, 90, 180, 270 every 2 cases.
            - phase: Fundamental phase in radians.
            - amplitude_2: Second harmonic amplitude, alternating every 2 cases with a +/-1 adjustment.
            - phase_deg2: Second harmonic phase in degrees, alternating between 0 and 45 degrees.
            - phase_2: Second harmonic phase in radians.
    Raises:
        ValueError: 
            If `tau` is not a tuple, integer, or float.
    Example:
        >>> params = create_melatonin_parameters(n_cases=10, tau=(24, 25))
        >>> print(params.head())
    """

    participant_id_list = [i_pid for i_pid in range(201, 201 + n_cases)]

    # if tau is integer, then repeat for all cases
    if isinstance(tau, tuple):
        tau = list(np.random.uniform(tau[0], tau[1], n_cases))
    elif isinstance(tau, (int, float)):
        tau = np.repeat(tau, n_cases)
    else:
        raise ValueError("tau must be an integer, float, or tuple of (min, max).")
    

    #  mesor - constant for all cases
    mesor = [2 for i_case in range(n_cases)]

    # fundamental amplitude - change every 4 cases
    amplitude = [8 + (i_case // 4) for i_case in range(n_cases)]

    # 2nd harmonic amplitude - change every 2 case and alternate +1/-1
    if harmonics is False:
        # repeat 0 for the length of n_cases
        amplitude_2 = np.repeat(0, n_cases)
    else:
        amplitude_2 = [
            (amplitude[i_case] / 3) - ((i_case // 2) % 2) for i_case in range(n_cases)
        ]

    # fundamental phase - iterate over 0, 90, 180, 270 every 2 cases
    phase_deg = [((i_case // 2) % 4) * 90 for i_case in range(n_cases)] 
    # replace 90 with 35
    phase_deg = [35 if phase == 90 else phase for phase in phase_deg]   
    phase = [np.deg2rad(phase_deg[i_case]) for i_case in range(n_cases)]

    # end harmonic phase - iterate between 0 and 45 degree angles for all cases
    if harmonics:
        phase_deg2 = [(i_case % 2) * 45 for i_case in range(n_cases)]
        phase_2 = [np.deg2rad(phase_deg2[i_case]) for i_case in range(n_cases)]
    else:
        phase_deg2 = [0 for i_case in range(n_cases)]
        phase_2 = [0 for i_case in range(n_cases)]

    # Create data frame from variables
    params = pd.DataFrame(
        {
            "participant_id": participant_id_list,
            "session_id": np.repeat("FD", n_cases),
            "tau": tau,
            "mesor": mesor,
            "amplitude": amplitude,
            "phase_deg": phase_deg,
            "phase": phase,
            "amplitude_2": amplitude_2,
            "phase_deg2": phase_deg2,
            "phase_2": phase_2,
        }
    )
    return params


def create_melatonin_profiles(params, standard_wakeup="2024-01-01 07:00:00"):
    """Create melatonin profiles based on provided parameters."""

    # Get protocol consistent time dataframe
    fd = create_time_lookups(standard_wakeup=standard_wakeup)["fd"]
    fd.drop(columns=["minutes_after_wakeup", "standard_clocktime"], inplace=True)

    # Group by participant_id and iterate through all rows of paramas and create a cosine column for each participant
    new_df = pd.DataFrame()
    for _, (pid, prow) in enumerate(params.groupby("participant_id")):
        mesor = prow["mesor"].values[0]
        amplitude = prow["amplitude"].values[0]
        phase = prow["phase"].values[0]
        amplitude_2 = prow["amplitude_2"].values[0]
        phase_2 = prow["phase_2"].values[0]
        tau = prow["tau"].values[0]
        t = fd["hours_after_wakeup"]

        # Create cosine wave based on harmonics flag
        if amplitude_2 > 0:
            mel_cosine = (
            mesor
            + amplitude * np.cos((2 * np.pi / tau) * t + phase)
            + amplitude_2 * np.cos((4 * np.pi / tau) * t + phase_2)
            )
        else:
            mel_cosine = (
            mesor
            + amplitude * np.cos((2 * np.pi / tau) * t + phase)
            )

        # Create temporary dataframe for current participant and their melatonin profile
        tmp_df = fd.copy()
        tmp_df["participant_id"] = pid
        tmp_df["melatonin_concentration"] = mel_cosine

        # Concatenate to new_df
        new_df = pd.concat([new_df, tmp_df], ignore_index=True)
        
        new_df["session_id"] = "FD"

    return new_df


def main(tau=None, harmonics=False, n_participants: int=20):
    """Create melatonin parameters and profiles.

    Returns:
        tuple: (DataFrame, DataFrame) containing melatonin profiles and parameters.
    """
    # # Parse arguments from command line ncases, tau and tau if each is None
    # # Instantiate the parser
    # parser = argparse.ArgumentParser(description='Optional app description')
    # parser.add_argument('--nparticipants', type=int, help='Number of participants')
    # parser.add_argument('--tau', type=float, nargs=2, help='Tau values as min and max')
    # parser.add_argument('--harmonics', type=bool, help='Enable harmonics')
    # args = parser.parse_args()

    n_participants = int(n_participants) if n_participants is not None else 20
    tau = 24 if tau is None else tau
    harmonics = False if harmonics is None else harmonics

    # Determine output folder based on harmonics and tau values
    if harmonics in [1, 'True', 'true', 'TRUE']:
        harmonics = True
        if isinstance(tau, (int, float)):
            parent_folder = "hormones_24_harmonics"  # reset tau to default
        elif isinstance(tau, tuple):
            parent_folder = "hormones_tau_harmonics"  # reset tau to default
        else:
            raise ValueError("tau must be an integer, float, or tuple of (min, max).")
    elif harmonics in [0, 'False', 'false', 'FALSE']:
        harmonics = False
        if tau is None or isinstance(tau, (int, float)):
            parent_folder = "hormones_24_fundamental"  # reset tau to default
        elif isinstance(tau, tuple):
            parent_folder = "hormones_tau_fundamental"  # reset tau to default
        else:
            raise ValueError("tau must be an integer, float, or tuple of (min, max).")
    else: 
        raise ValueError("harmonics must be a boolean value (True or False).")

    # Create directory if it doesn't exist
    out_folder = DATA_DIR / "simulation" / parent_folder
    out_folder.mkdir(parents=True, exist_ok=True) 
    out_path = out_folder / "simulated_melatonin_input.csv"
    # Create melatonin parameters for specified number of cases
    params = create_melatonin_parameters(n_cases=n_participants, tau=tau, harmonics=harmonics)
    params.to_csv(out_path)
    print("Saved file with simulated parameters to:", out_path)

    # Create melatonin profiles based on parameters
    out_path = out_folder / "simulated_melatonin_data.csv"
    new_df = create_melatonin_profiles(params, standard_wakeup="2024-01-01 07:00:00")
    new_df.to_csv(out_path)
    print("Saved file with simulated dataset to:", out_path)

    return new_df, params


if __name__ == "__main__":
    main(n_participants=24, tau=24, harmonics=False)
    main(n_participants=24, tau=(23, 25), harmonics=False)
    main(n_participants=24, tau=24, harmonics=True)
    main(n_participants=24, tau=(23, 25), harmonics=True)
