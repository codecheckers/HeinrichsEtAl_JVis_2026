#!/usr/bin/env bash
# copy_eyetracking_pupil.sh
#
# Copies eyetracking files for one or more participants from the external drive
# to the local project, preserving the folder structure.
#
# Files copied per participant:
#   <pid>/04_expsession/eyetracking/eyetracking_metadata.csv
#   <pid>/04_expsession/eyetracking/<rec>/<n>/info.player.json
#   <pid>/04_expsession/eyetracking/<rec>/<n>/exports/000/pupil_positions.csv
#   <pid>/04_expsession/eyetracking/<rec>/<n>/exports/000/export_info.csv
#
# Usage:
#   ./copy_eyetracking_pupil.sh [--dry-run] <pid> [<pid> ...]
#   ./copy_eyetracking_pupil.sh [--dry-run]          # copies all participants

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
SRC_BASE="/Volumes/tscn-projects/civibe/data/raw"
DST_BASE="/Users/hheinrichs/Documents/projects/civibe_psychophysics/data/raw"
METADATA_SCRIPT="./scripts/extract_eyetracking_metadata.sh"

# ── Parse arguments ────────────────────────────────────────────────────────────
DRY_RUN=false
PIDS=()
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" || "$arg" == "-n" ]]; then
        DRY_RUN=true
    else
        PIDS+=("$arg")
    fi
done

$DRY_RUN && echo "*** DRY RUN — no files will be copied ***" && echo ""

# If no PIDs given, collect all participant directories from the source
if [[ "${#PIDS[@]}" -eq 0 ]]; then
    echo "No participant IDs given — processing all participants under $SRC_BASE"
    for pid_dir in "$SRC_BASE"/*/; do
        PIDS+=("$(basename "$pid_dir")")
    done
else
    echo "Participant(s): ${PIDS[*]}"
fi

# ── Helper: copy one file ──────────────────────────────────────────────────────
# Skips if the destination already has an identical copy.
copy_count=0
skip_count=0

copy_file() {
    local src="$1"
    local rel="${src#"$SRC_BASE"/}"   # path relative to SRC_BASE
    local dst="$DST_BASE/$rel"

    # Checks whether the source file exists
    # If it doesn't, logs a missing-file message to stderr and exits the function early
    if [[ ! -f "$src" ]]; then
        echo "  MISSING : $rel" >&2
        return
    fi

    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        echo "  SKIP    : $rel (identical)"
        (( skip_count++ )) || true
        return
    fi

    if $DRY_RUN; then
        echo "  WOULD COPY: $rel"
    else
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        echo "  COPY    : $rel"
    fi
    (( copy_count++ )) || true
}

# ── Main loop: iterate over participants ───────────────────────────────────────
for pid in "${PIDS[@]}"; do
    echo ""
    echo "=== Participant $pid ==="

    eyetrack_dir="$SRC_BASE/$pid/04_expsession/eyetracking"

    # 1. eyetracking_metadata.csv (flat, directly under eyetracking/)
    if [[ ! -f "$eyetrack_dir/eyetracking_metadata.csv" ]]; then
        echo "  WARNING: eyetracking_metadata.csv missing in $eyetrack_dir — run first:"
        echo "    $METADATA_SCRIPT $SRC_BASE/$pid/04_expsession"
    else
        copy_file "$eyetrack_dir/eyetracking_metadata.csv"
    fi

    # 2. pupil_positions.csv, export_info.csv, and info.player.json
    # Structure is fixed: <rec>/<n>/exports/.../ — iterate via glob
    found=false
    for exports_dir in "$eyetrack_dir"/*/*/exports/*; do
        [[ -d "$exports_dir" ]] || continue   # skip if glob found no match
        found=true
        recording_dir="${exports_dir%/exports/000}"   # strip suffix, no dirname needed
        #copy_file "$exports_dir/pupil_positions.csv"
        #copy_file "$exports_dir/export_info.csv"
        copy_file "$recording_dir/info.player.json"
    done
    $found || echo "  WARNING: no exports/ found under $eyetrack_dir"
done

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
    echo "Dry run complete. Would copy: $copy_count, would skip: $skip_count"
else
    echo "Done. Copied: $copy_count, skipped (identical): $skip_count"
fi