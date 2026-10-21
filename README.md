# iCloudEMS — Support Engineer (AI / Technical Support) Technical Assignment

Hands-on solution for the 3-hour take-home assessment: SQL, bug investigation,
parent/child reconciliation, API troubleshooting and AI/RAG troubleshooting.
Every SQL file was **actually executed** (MariaDB 10.11, MySQL-compatible) and the real output is saved in `results/`.

## Repository layout
```
data/      original datasets supplied with the assignment (unchanged)
sql/       task1_university_erp.sql · task2_adm10025_bug.sql · task3_reconciliation.sql
docs/      task4_api_troubleshooting.md · task5_ai_troubleshooting.md
results/   real query output for each task (captured from the run)
scripts/   verify_load.sh  (independent "no data loss" check for Task 3)
run_all.sh rebuilds both databases and regenerates everything in results/
```

## How to run
```bash
# needs a MySQL / MariaDB server
export MYSQL_USER=root MYSQL_PWD=<your-password>
./run_all.sh
```
Or manually, task by task:
```bash
mysql -u root -p -e "CREATE DATABASE erp; CREATE DATABASE recon;"
mysql -u root -p erp   < data/task1_university_erp_dataset.sql
mysql -u root -p recon < data/task3_reconciliation_dataset.sql
mysql -u root -p erp   -t < sql/task1_university_erp.sql
mysql -u root -p erp   -t < sql/task2_adm10025_bug.sql     # run after Task 1 (it applies the fix)
mysql -u root -p recon -t < sql/task3_reconciliation.sql
```

## Key findings
| Task | Finding |
|---|---|
| 1 | Row counts: departments 5, programs 10, students 305, admissions 300, fee_transactions 516, fee_transaction_details 889 |
| 1 | 5 duplicated admission numbers in `students` (ADM10081, 10090, 10154, 10186, 10261) |
| 1 | 8 duplicate fee-transaction groups (same admission + type + amount + date) |
| 1 | 122 students have an outstanding balance, total ₹21,03,000 (DUE − PAID − CONCESSION) |
| 1 | 16 parents ≠ Σ children · 10 parents with no children · 10 orphan child rows |
| 2 | ADM10025: PAID txn 518 = ₹15,000 but only the Tuition Fee line (₹10,000) was saved; Exam Fee ₹5,000 line missing → due job (sums child rows) shows ₹5,000. Fixed by inserting the missing child line; due → ₹0 |
| 3 | 41 parent / 76 child rows loaded with no loss (counts and amount checksums match the file). 12 of 30 admissions MISMATCH; 4 parents without child, 4 orphan children |
| 4 | A: non-atomic parent/child write + swallowed exception (Application, with DB id-collision). B: DB lock-wait timeout after gateway capture (Database + payment-flow design) |
| 5 | Stale snapshot in the retrieval layer (RAG-retrieval / stale context), not an LLM hallucination |

## Assumptions
* **Outstanding = Σ DUE − Σ PAID − Σ CONCESSION** per admission number. Many students show a negative (over-paid) balance in the sample data; those are excluded from "outstanding".
* `students` contains duplicate admission numbers, so student lookups use the original (lowest `student_id`) record to avoid double counting.
* Duplicate transactions (Task 1.3) are reported, not deleted. Query 1.5b shows how much they distort balances.
* "Total fee collected" counts `PAID` transactions only.
