-- ============================================================================
-- TASK 3 : Parent / Child Transaction Reconciliation        (database: recon)
-- Setup  : mysql -u root -p -e "CREATE DATABASE recon;"
--          mysql -u root -p recon < data/task3_reconciliation_dataset.sql
-- Run    : mysql -u root -p recon -t < sql/task3_reconciliation.sql
--
-- Parent = financial_transaction         (transaction_id must be unique)
-- Child  = financial_transaction_detail  (may repeat per admission_no)
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 3.1  Row counts
--      Expected from the dataset file: 41 parent INSERTs, 76 child INSERTs
-- ---------------------------------------------------------------------------
SELECT 'financial_transaction'        AS table_name, COUNT(*) AS row_count FROM financial_transaction
UNION ALL
SELECT 'financial_transaction_detail',               COUNT(*)              FROM financial_transaction_detail;

-- ---------------------------------------------------------------------------
-- 3.2  Verify the data loaded WITHOUT LOSS
--      (a) row counts + distinct keys + NULL check + amount checksums.
--          Compare the numbers with the checksum taken straight from the .sql
--          file by scripts/verify_load.sh  (see results/task3_load_check.txt)
--      (b) the parent rule: transaction_id unique -> rows = distinct ids
-- ---------------------------------------------------------------------------
SELECT 'parent'  AS tbl, COUNT(*) AS `rows`, COUNT(DISTINCT transaction_id) AS distinct_ids,
       SUM(total_amount) AS amount_checksum, MIN(transaction_id) AS min_id, MAX(transaction_id) AS max_id,
       SUM(admission_no IS NULL OR total_amount IS NULL) AS null_rows
FROM   financial_transaction
UNION ALL
SELECT 'child',  COUNT(*), COUNT(DISTINCT detail_id),
       SUM(amount), MIN(detail_id), MAX(detail_id),
       SUM(admission_no IS NULL OR amount IS NULL)
FROM   financial_transaction_detail;

-- 3.2b  Parent uniqueness rule: same admission + date + amount repeated? (expect 0 rows)
SELECT admission_no, transaction_date, total_amount, COUNT(*) AS occurrences
FROM   financial_transaction
GROUP  BY admission_no, transaction_date, total_amount
HAVING COUNT(*) > 1;

-- ---------------------------------------------------------------------------
-- 3.3  Reconcile parent vs child amount, PER TRANSACTION (all 41 parents + orphans)
--      Status: MATCH / AMOUNT_MISMATCH / NO_CHILD
-- ---------------------------------------------------------------------------
SELECT p.transaction_id, p.admission_no,
       p.total_amount                                   AS parent_amount,
       COALESCE(SUM(d.amount), 0)                       AS child_amount,
       p.total_amount - COALESCE(SUM(d.amount), 0)      AS difference,
       COUNT(d.detail_id)                               AS child_rows,
       CASE WHEN COUNT(d.detail_id) = 0                        THEN 'NO_CHILD'
            WHEN p.total_amount = SUM(d.amount)                THEN 'MATCH'
            ELSE 'AMOUNT_MISMATCH' END                  AS status
FROM   financial_transaction p
LEFT   JOIN financial_transaction_detail d ON d.transaction_id = p.transaction_id
GROUP  BY p.transaction_id, p.admission_no, p.total_amount
ORDER  BY p.transaction_id;

-- ---------------------------------------------------------------------------
-- 3.4  Reconcile transaction COUNTS per admission number
--      parent count  vs  DISTINCT child transaction_id count
--      (child rows legitimately repeat, so COUNT(*) on child would be wrong)
-- ---------------------------------------------------------------------------
SELECT a.admission_no,
       COALESCE(p.parent_cnt, 0) AS parent_txn_count,
       COALESCE(c.child_cnt, 0)  AS child_distinct_txn_count,
       COALESCE(p.parent_cnt, 0) - COALESCE(c.child_cnt, 0) AS count_difference,
       IF(COALESCE(p.parent_cnt, 0) = COALESCE(c.child_cnt, 0), 'MATCH', 'MISMATCH') AS count_status
FROM  (SELECT admission_no FROM financial_transaction UNION SELECT admission_no FROM financial_transaction_detail) a
LEFT  JOIN (SELECT admission_no, COUNT(*) parent_cnt FROM financial_transaction GROUP BY admission_no) p
       ON p.admission_no = a.admission_no
LEFT  JOIN (SELECT admission_no, COUNT(DISTINCT transaction_id) child_cnt FROM financial_transaction_detail GROUP BY admission_no) c
       ON c.admission_no = a.admission_no
ORDER BY a.admission_no;

-- ---------------------------------------------------------------------------
-- 3.5  ALL mismatches (amount and/or count) - one row per problem transaction
--      Type 1: amount differs   Type 2: parent without child   Type 3: orphan child
-- ---------------------------------------------------------------------------
SELECT 'AMOUNT_MISMATCH'  AS issue_type, p.transaction_id, p.admission_no,
       p.total_amount AS parent_amount, SUM(d.amount) AS child_amount, p.total_amount - SUM(d.amount) AS difference
FROM   financial_transaction p JOIN financial_transaction_detail d ON d.transaction_id = p.transaction_id
GROUP  BY p.transaction_id, p.admission_no, p.total_amount
HAVING p.total_amount <> SUM(d.amount)
UNION ALL
SELECT 'PARENT_WITHOUT_CHILD', p.transaction_id, p.admission_no, p.total_amount, 0, p.total_amount
FROM   financial_transaction p
WHERE  NOT EXISTS (SELECT 1 FROM financial_transaction_detail d WHERE d.transaction_id = p.transaction_id)
UNION ALL
SELECT 'ORPHAN_CHILD', d.transaction_id, d.admission_no, 0, d.amount, -d.amount
FROM   financial_transaction_detail d
WHERE  NOT EXISTS (SELECT 1 FROM financial_transaction p WHERE p.transaction_id = d.transaction_id)
ORDER  BY issue_type, transaction_id;

-- ---------------------------------------------------------------------------
-- 3.6a Parent transactions with NO child records
-- ---------------------------------------------------------------------------
SELECT p.*
FROM   financial_transaction p
LEFT   JOIN financial_transaction_detail d ON d.transaction_id = p.transaction_id
WHERE  d.detail_id IS NULL
ORDER  BY p.transaction_id;

-- 3.6b Child records whose parent transaction does NOT exist
SELECT d.*
FROM   financial_transaction_detail d
LEFT   JOIN financial_transaction p ON p.transaction_id = d.transaction_id
WHERE  p.transaction_id IS NULL
ORDER  BY d.detail_id;

-- ---------------------------------------------------------------------------
-- 3.7  FINAL REPORT
--      Admission No | Parent Amount | Child Amount | Difference | Parent Count | Child Count | Status
--      MATCH only when BOTH the amount and the transaction count agree.
--      Aggregating parent and child separately avoids the join fan-out problem.
-- ---------------------------------------------------------------------------
SELECT a.admission_no                                   AS `Admission No`,
       COALESCE(p.parent_amount, 0)                     AS `Parent Amount`,
       COALESCE(c.child_amount, 0)                      AS `Child Amount`,
       COALESCE(p.parent_amount, 0) - COALESCE(c.child_amount, 0) AS `Difference`,
       COALESCE(p.parent_count, 0)                      AS `Parent Count`,
       COALESCE(c.child_count, 0)                       AS `Child Count`,
       CASE WHEN COALESCE(p.parent_amount, 0) = COALESCE(c.child_amount, 0)
             AND COALESCE(p.parent_count, 0)  = COALESCE(c.child_count, 0)
            THEN 'MATCH' ELSE 'MISMATCH' END            AS `Status`
FROM  (SELECT admission_no FROM financial_transaction
       UNION
       SELECT admission_no FROM financial_transaction_detail) a
LEFT  JOIN (SELECT admission_no, SUM(total_amount) parent_amount, COUNT(*) parent_count
            FROM financial_transaction GROUP BY admission_no) p ON p.admission_no = a.admission_no
LEFT  JOIN (SELECT admission_no, SUM(amount) child_amount, COUNT(DISTINCT transaction_id) child_count
            FROM financial_transaction_detail GROUP BY admission_no) c ON c.admission_no = a.admission_no
ORDER BY a.admission_no;

-- 3.7b Summary of the final report
SELECT Status, COUNT(*) AS admissions
FROM (
  SELECT CASE WHEN COALESCE(p.pa,0) = COALESCE(c.ca,0) AND COALESCE(p.pc,0) = COALESCE(c.cc,0) THEN 'MATCH' ELSE 'MISMATCH' END AS Status
  FROM (SELECT admission_no FROM financial_transaction UNION SELECT admission_no FROM financial_transaction_detail) a
  LEFT JOIN (SELECT admission_no, SUM(total_amount) pa, COUNT(*) pc FROM financial_transaction GROUP BY admission_no) p ON p.admission_no = a.admission_no
  LEFT JOIN (SELECT admission_no, SUM(amount) ca, COUNT(DISTINCT transaction_id) cc FROM financial_transaction_detail GROUP BY admission_no) c ON c.admission_no = a.admission_no
) z GROUP BY Status;
