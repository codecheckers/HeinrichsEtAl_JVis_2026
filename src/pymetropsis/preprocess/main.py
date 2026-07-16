# run main of load_hormones and clean_metropsis
import os

from pymetropsis.preprocess.load_hormones import main as load_hormones
from pymetropsis.preprocess.clean_metropsis import main as clean_metropsis

# Repo root, resolved relative to this file's location.
REPO_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

# MANUAL ACTION REQUIRED: these paths point to the internal network drive
# (mount kfs/tscn-projects at /Volumes/tscn-projects before running). They
# cannot be made relative since the raw data is not distributed with this
# repository.
NOVOLYTIX_DIR = "/Volumes/tscn-projects/civibe/data/raw/group/saliva"
SALIVA_LOG_PATH = "/Volumes/tscn-projects/civibe/data/raw/group/saliva/20250728_civibe_saliva-log.xlsm"

if __name__ == "__main__":
    # Load and clean hormone data
    load_hormones(
        novolytix_dir=NOVOLYTIX_DIR,
        log_path=SALIVA_LOG_PATH,
        out_path=os.path.join(REPO_DIR, "data", "raw", "clean_saliva_data.csv"),
    )

    # Clean Metropolis data
    clean_metropsis(
        out_path=os.path.join(REPO_DIR, "data", "raw", "clean_metropsis_TCS-2e.csv")
    )
