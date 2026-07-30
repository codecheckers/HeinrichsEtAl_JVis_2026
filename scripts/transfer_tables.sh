#!/usr/bin/env bash
# Transfer generated LaTeX tables from results/tables/ into manuscript/tbl/.
#
# Only files listed in TABLES below are touched. Anything in manuscript/tbl/ without a
# generated counterpart (hand-written tables, the tbl_fitted_tcs_* family) is left alone
# and reported, so nothing is silently overwritten or silently missed.
#
# Overwritten files are backed up to manuscript/tbl/.bak/<timestamp>/ first.
#
#   ./scripts/transfer_tables.sh              copy (with backups)
#   ./scripts/transfer_tables.sh --dry-run    report what would change, copy nothing
#   ./scripts/transfer_tables.sh --no-backup  copy without backups
#
# NOTE: no compiled manuscript \inputs manuscript/tbl/ — the accepted source has its tables
# inlined (see manuscript/tbl/README.md). Running this refreshes the generated fragments but
# does NOT update the paper; the inlined tables in main_PROOF.tex still need editing.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=results/tables/log_tcs
DEST=manuscript/tbl

# Tables to transfer, one per line: "<source-name> <dest-name>"
# Source is relative to $SRC, dest to $DEST. Same name on both sides unless renamed.
TABLES=(
  "tbl_descriptives_ntcstests.tex        tbl_descriptives_ntcstests.tex"
  "tbl_descriptives_tcs.tex             tbl_descriptives_tcs.tex"
  "tbl_hormone_stats.tex                tbl_hormone_stats.tex"
  "tbl_fitted_all_parameters_body.tex   tbl_fitted_all_parameters_body.tex"
  "tbl_fitted_all_parameters_meta.tex   tbl_fitted_all_parameters_meta.tex"
  "tbl_model_summary__achromatic_2.tex  tbl_model_summary__achromatic_2.tex"
  "tbl_model_summary__achromatic_8.tex  tbl_model_summary__achromatic_8.tex"
  "tbl_model_summary__blue-yellow_2.tex tbl_model_summary__blue-yellow_2.tex"
  "tbl_model_summary__blue-yellow_8.tex tbl_model_summary__blue-yellow_8.tex"
  "tbl_model_summary__red-green_2.tex   tbl_model_summary__red-green_2.tex"
  "tbl_model_summary__red-green_8.tex   tbl_model_summary__red-green_8.tex"
)

# Deliberately NOT mapped, because the correspondence is ambiguous and the manuscript
# versions are hand-edited. results/ has tbl_fitted_all_parameters{,_body,_meta}.tex while
# manuscript/ additionally carries a tbl_fitted_tcs_all_parameters{,_body,_environment,_meta}
# family whose content differs. Add entries to TABLES above once the intended pairing is
# settled -- see TODO.md.

dry_run=0
backup=1
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    --no-backup) backup=0 ;;
    -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

[ -d "$SRC" ]  || { echo "missing source dir: $SRC (run the R reporting stage first)" >&2; exit 1; }
[ -d "$DEST" ] || { echo "missing dest dir: $DEST" >&2; exit 1; }

# Extract table body from a generated table and combine with environment template.
# This handles tables where the source uses a different environment (e.g., table/tabular)
# but the destination uses longtable with a custom header structure.
combine_table_with_environment() {
  local src_table="$1"      # source table (e.g., results/tables/log_tcs/tbl_fitted_all_parameters.tex)
  local env_template="$2"   # environment template with >>> INSERT-HERE <<<
  local dest_body="$3"      # destination for body file
  local dest_table="$4"     # destination for final combined table
  local dry_run="$5"
  local backup_dir="$6"
  local body_file

  # Extract body from source table: content between \midrule and \bottomrule
  if ! grep -q "\\\\midrule" "$src_table" || ! grep -q "\\\\bottomrule" "$src_table"; then
    echo "    ERROR: source table missing \\midrule or \\bottomrule markers"
    return 1
  fi

  # Use temp file for extracted body
  body_file=$(mktemp)
  trap "rm -f '$body_file'" RETURN
  sed -n '/\\midrule/,/\\bottomrule/p' "$src_table" | sed '1d;$d' > "$body_file"

  # Write body to destination body file
  if [ "$dry_run" -eq 0 ]; then
    mkdir -p "$(dirname "$dest_body")"
    if [ -f "$dest_body" ] && [ -n "$backup_dir" ]; then
      mkdir -p "$backup_dir"
      cp -p "$dest_body" "$backup_dir/$(basename "$dest_body")"
    fi
    cp "$body_file" "$dest_body"
  fi

  # Combine environment template with extracted body using awk
  if [ "$dry_run" -eq 0 ]; then
    mkdir -p "$(dirname "$dest_table")"
    if [ -f "$dest_table" ] && [ -n "$backup_dir" ]; then
      mkdir -p "$backup_dir"
      cp -p "$dest_table" "$backup_dir/$(basename "$dest_table")"
    fi
    awk -v body_file="$body_file" '
      />>> INSERT-HERE <<</ {
        while ((getline line < body_file) > 0) {
          print line
        }
        close(body_file)
        next
      }
      { print }
    ' "$env_template" > "$dest_table"
  fi

  echo "  combined   $src_table"
  echo "           → $dest_body (body)"
  echo "           → $dest_table (final)"
}

backup_dir="$DEST/.bak/$(date +%Y%m%dT%H%M%S)"
copied=0; unchanged=0; missing=0; created=0

echo "Transferring tables: $SRC -> $DEST"
[ "$dry_run" -eq 1 ] && echo "(dry run -- nothing will be written)"

for entry in "${TABLES[@]}"; do
  # shellcheck disable=SC2086
  set -- $entry
  src="$SRC/$1"
  dst="$DEST/$2"

  if [ ! -f "$src" ]; then
    echo "  MISSING   $1 (not in $SRC)"
    missing=$((missing + 1))
    continue
  fi

  if [ ! -f "$dst" ]; then
    echo "  new       $1 -> $2"
    created=$((created + 1))
    [ "$dry_run" -eq 0 ] && cp -p "$src" "$dst"
    continue
  fi

  if cmp -s "$src" "$dst"; then
    unchanged=$((unchanged + 1))
    continue
  fi

  echo "  updated   $1 -> $2"
  copied=$((copied + 1))
  if [ "$dry_run" -eq 0 ]; then
    if [ "$backup" -eq 1 ]; then
      mkdir -p "$backup_dir"
      cp -p "$dst" "$backup_dir/$2"
    fi
    cp -p "$src" "$dst"
  fi
done

echo "Summary: $copied updated, $created new, $unchanged unchanged, $missing missing"
if [ "$copied" -gt 0 ] && [ "$dry_run" -eq 0 ] && [ "$backup" -eq 1 ]; then
  echo "Backups of overwritten files: $backup_dir"
fi

# Handle combined tables: extract body from source and merge with environment template
echo ""
echo "Combining generated tables with environment templates..."
src_fitted="$SRC/tbl_fitted_all_parameters.tex"
env_fitted="$DEST/tbl_fitted_tcs_all_parameters_environment.tex"
body_fitted="$DEST/tbl_fitted_tcs_all_parameters_body.tex"
table_fitted="$DEST/tbl_fitted_tcs_all_parameters.tex"

if [ -f "$src_fitted" ] && [ -f "$env_fitted" ]; then
  backup_dir_arg=""
  if [ "$backup" -eq 1 ]; then
    backup_dir_arg="$backup_dir"
  fi
  combine_table_with_environment "$src_fitted" "$env_fitted" "$body_fitted" "$table_fitted" "$dry_run" "$backup_dir_arg"
else
  if [ ! -f "$src_fitted" ]; then
    echo "  SKIP      source table not found: $src_fitted"
  fi
  if [ ! -f "$env_fitted" ]; then
    echo "  SKIP      environment template not found: $env_fitted"
  fi
fi

# Report both directions so divergence stays visible rather than accumulating silently.
mapped_src=""; mapped_dst=""
for entry in "${TABLES[@]}"; do
  # shellcheck disable=SC2086
  set -- $entry
  mapped_src="$mapped_src $1"
  mapped_dst="$mapped_dst $2"
done

unmapped_dest=""
for f in "$DEST"/*.tex; do
  b=$(basename "$f")
  case " $mapped_dst " in *" $b "*) ;; *) unmapped_dest="$unmapped_dest $b" ;; esac
done
if [ -n "$unmapped_dest" ]; then
  echo "Left untouched in $DEST (no generated counterpart):"
  for b in $unmapped_dest; do echo "  $b"; done
fi

unmapped_src=""
for f in "$SRC"/*.tex; do
  b=$(basename "$f")
  case " $mapped_src " in *" $b "*) ;; *) unmapped_src="$unmapped_src $b" ;; esac
done
if [ -n "$unmapped_src" ]; then
  echo "Generated but not transferred (add to TABLES if wanted):"
  for b in $unmapped_src; do echo "  $b"; done
fi

# results/tex/log_tcs/ holds prose fragments (tex_*.tex), not tables, and manuscript/tbl/
# carries none of them. They are out of scope here by design.
