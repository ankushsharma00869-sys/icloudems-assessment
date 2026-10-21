#!/bin/sh
# Rebuilds both databases from the supplied datasets and re-runs every SQL file,
# saving the real query output into results/.
# Usage:  MYSQL_USER=root MYSQL_PWD=yourpassword ./run_all.sh
set -e
U=${MYSQL_USER:-root}
M="mysql -u$U -t"
mysql -u$U -e "DROP DATABASE IF EXISTS erp; DROP DATABASE IF EXISTS recon; CREATE DATABASE erp; CREATE DATABASE recon;"
mysql -u$U erp   < data/task1_university_erp_dataset.sql
mysql -u$U recon < data/task3_reconciliation_dataset.sql
$M erp   < sql/task1_university_erp.sql      > results/task1_output.txt
$M erp   < sql/task2_adm10025_bug.sql        > results/task2_output.txt
$M recon < sql/task3_reconciliation.sql      > results/task3_output.txt
sh scripts/verify_load.sh                    > results/task3_load_check.txt
echo "Done. See results/"
