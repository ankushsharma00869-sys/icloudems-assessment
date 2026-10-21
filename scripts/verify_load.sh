#!/bin/sh
# Task 3.2 - independent "no data loss" check: count INSERTs and add up amounts
# directly from the .sql file, then compare with what is in the database.
F=${1:-data/task3_reconciliation_dataset.sql}
python3 - "$F" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
par = re.findall(r"INSERT INTO financial_transaction VALUES \((\d+), '([^']*)', '([^']*)', ([\d.]+), '([^']*)'\);", txt)
chi = re.findall(r"INSERT INTO financial_transaction_detail VALUES \((\d+), (\d+), '([^']*)', '([^']*)', ([\d.]+), '([^']*)'\);", txt)
print("FROM FILE  parent rows:", len(par), "| parent amount sum:", sum(float(r[3]) for r in par))
print("FROM FILE  child  rows:", len(chi), "| child  amount sum:", sum(float(r[4]) for r in chi))
PY
echo "FROM DB:"
mysql -u${MYSQL_USER:-root} recon -N -e "SELECT 'parent', COUNT(*), SUM(total_amount) FROM financial_transaction UNION ALL SELECT 'child', COUNT(*), SUM(amount) FROM financial_transaction_detail;"
