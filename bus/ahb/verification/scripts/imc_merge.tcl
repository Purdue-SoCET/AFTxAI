merge -out merged -overwrite *
load -run merged
report_metrics -detail -out cov_report -overwrite
exit
