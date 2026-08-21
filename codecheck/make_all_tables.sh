#!/bin/sh
ROOT=/Users/sje30/proj/2020/codecheckers/2026/HeinrichsEtAl_JVis_2026/results/tables/log_tcs
TEX="tbl_descriptives_ntcstests.tex tbl_descriptives_tcs.tex tbl_fitted_all_parameters_meta.tex tbl_fitted_all_parameters.tex tbl_hormone_stats.tex tbl_model_summary__achromatic_2.tex tbl_model_summary__achromatic_8.tex tbl_model_summary__blue-yellow_2.tex tbl_model_summary__blue-yellow_8.tex tbl_model_summary__red-green_2.tex tbl_model_summary__red-green_8.tex"

for file in $TEX; do
    python3 make_table.py "$ROOT/$file"
done
