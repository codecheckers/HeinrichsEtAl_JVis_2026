#!/usr/bin/env bash
# Copy figures from img/ into the manuscript root under sequential names, and
# update the \includegraphics paths in the .tex. \label commands are left as-is.
# Run from anywhere; it operates relative to manuscript/.
set -euo pipefail
cd "$(dirname "$0")/../manuscript"

TEX=main_PROOF.tex
cp "$TEX" "$TEX.bak"   # backup before editing

# rename <source-in-img> <new-name-in-manuscript>
rename() {
  cp "img/$1" "$2"
  sed -i '' "s|{img/$1}|{$2}|g" "$TEX"   # macOS sed; on Linux use: sed -i "..."
  echo "  $1  ->  $2"
}

# rename_supp <source-in-supplement> <new-name-in-manuscript>
# For appendix figures that were moved in from the supplement.
rename_supp() {
  cp "supplement/$1" "$2"
  sed -i '' "s|{supplement/$1}|{$2}|g" "$TEX"   # macOS sed; on Linux use: sed -i "..."
  echo "  supplement/$1  ->  $2"
}

# rename_from <source-dir-relative-to-manuscript> <source-file> <new-name-in-manuscript>
# For figures whose source of truth now lives outside supplement/ (e.g. generated
# straight into results/figures/), but which the .tex still references as
# {supplement/<file>}.
rename_from() {
  cp "$1/$2" "$3"
  sed -i '' "s|{supplement/$2}|{$3}|g" "$TEX"   # macOS sed; on Linux use: sed -i "..."
  echo "  $1/$2  ->  $3"
}

echo "Renaming figures in $TEX (backup: $TEX.bak):"
rename fig_methods_summary.pdf                     Figure1.pdf
rename img_melatonin_overview_figure.pdf           Figure2.pdf
rename fig_psychophysics_test_timeseries_212-2.pdf Figure3.pdf
rename fig_average_tcs_melatonin.pdf               Figure4.pdf
rename fig_individual_tcs_melatonin.pdf            Figure5.pdf

echo "Appendix figures (from supplement):"
rename_from ../results/figures/hormones/tau_harmonics fig_melatonin_scatter-func.pdf Figure6.pdf
rename_from ../results/figures/hormones/tau_harmonics fig_melatonin_tau_gof.pdf      Figure7.pdf
rename_from ../results/figures/postcontrol fig_diurnal_timecourses_metropsis.pdf Figure8.pdf
rename_supp fig_pupil_diameter.pdf                 Figure9.pdf
echo "Done."
