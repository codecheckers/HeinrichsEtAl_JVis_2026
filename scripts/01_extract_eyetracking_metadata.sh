#!/bin/bash
# extract_eyetracking_metadata.sh
#
# Extracts metadata from eyetracking files for one participant and saves it as a CSV.
# Usage: 
#   ./extract_eyetracking_metadata.sh <input_directory>
#
# Example: 
#   ./extract_eyetracking_metadata.sh /Volumes/tscn-projects/civibe/data/raw/202/04_expsession
#   ./extract_eyetracking_metadata.sh /Users/hheinrichs/Documents/projects/civibe_psychophysics/data/raw/202/04_expsession
# 
# The script looks for eyetracking data in the specified input directory, extracts metadata such as file modification dates and video duration from individual files saved during the run, and saves it to a CSV file named "eyetracking_metadata.csv" in the same directory.
# Timestamps were generated during manuel video recording by the experimenters and are used to approximate start and stop time of the experiment.


# Check if the user provided an input directory
if [ -z "$1" ]; then
    echo "Usage: $0 <input_directory>"
    echo "Provide directory to participant-specific eyetracking folders. Example: $0 /Volumes/tscn-projects/civibe/data/raw/202/04_expsession"
    exit 1
fi


# Use the provided input directory
ROOT_DIR="$1"
# print the provided directory for confirmation
echo "Using input directory: $ROOT_DIR"
#ROOT_DIR="/Volumes/tscn-projects/civibe/data/raw/113/04_expsession"

cd "$ROOT_DIR"

# Path to the base folder
BASE_DIR="$ROOT_DIR/eyetracking"

# CSV output file inside eyetracking folder
OUTPUT_FILE="$BASE_DIR/eyetracking_metadata.csv"


# Add column headers to the output file
echo "FolderPath,AnnotationFileModificationDate,WorldFileModificationDate,VideoDuration,ExportDateTime" > "$OUTPUT_FILE"

if [ -f "$OUTPUT_FILE" ]; then
    echo "Output file initialized: $OUTPUT_FILE"
else
    echo "Could not create output file: $OUTPUT_FILE"
fi

# Loop through second-level subfolders
processed=0
for dir in "$BASE_DIR"/*/*; do
    # print the current directory being processed
    echo "Processing directory: $dir"
    if [ -d "$dir" ]; then
        processed=$((processed + 1))
        # Get FileModifyDate for annotation.pldata with formatted date
        annodate=$(exiftool -s -s -s -d "%d.%m.%Y %H:%M:%S" -FileModifyDate "$dir/annotation.pldata" 2>/dev/null)
        

        # Get FileModifyDate for world.mp4 with formatted date
        worlddate=$(exiftool -s -s -s -d "%d.%m.%Y %H:%M:%S" -FileModifyDate "$dir/world.mp4" 2>/dev/null)

        # Get Duration for world.mp4 (unchanged)
        duration=$(exiftool -s -s -s -Duration "$dir/world.mp4" 2>/dev/null)

        # Get export date and time from export_info.csv (rows 4 and 5, second column)
        export_info="$dir/exports/000/export_info.csv"
        if [ -f "$export_info" ]; then
            export_date=$(awk -F',' 'NR==4 {print $2}' "$export_info" | tr -d '\r\n')
            export_time=$(awk -F',' 'NR==5 {print $2}' "$export_info" | tr -d '\r\n')
            export_datetime="${export_date} ${export_time}"
        else
            export_datetime=""
        fi 

        echo "$dir,$annodate,$worlddate,$duration,$export_datetime" >> "$OUTPUT_FILE"
        #echo "$dir,$annodate,$worlddate,$duration" >> "$OUTPUT_FILE"
        echo "  Added metadata for $dir"
    fi
done

echo "Metadata CSV created at: $OUTPUT_FILE"
echo "Folders processed by loop: $processed"