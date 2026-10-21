-- ============================================================================
-- TASK 1 : MySQL Database & Data Processing          (database: erp)
-- Setup  : mysql -u root -p -e "CREATE DATABASE erp;"
--          mysql -u root -p erp < data/task1_university_erp_dataset.sql
-- Run    : mysql -u root -p erp -t < sql/task1_university_erp.sql
--
-- Business rule used for "outstanding":
--   outstanding = SUM(DUE) - SUM(PAID) - SUM(CONCESSION)   per admission_no
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1.1  Row counts of all six tables
-- ---------------------------------------------------------------------------
SELECT 'departments'             AS table_name, COUNT(*) AS row_count FROM departments
UNION ALL SELECT 'programs',                 COUNT(*) FROM programs
UNION ALL SELECT 'students',                 COUNT(*) FROM students
UNION ALL SELECT 'admissions',               COUNT(*) FROM admissions
UNION ALL SELECT 'fee_transactions',         COUNT(*) FROM fee_transactions
UNION ALL SELECT 'fee_transaction_details',  COUNT(*) FROM fee_transaction_details;

-- ---------------------------------------------------------------------------
-- 1.2  Duplicate admission numbers in students
-- ---------------------------------------------------------------------------
SELECT admission_no,
       COUNT(*)                          AS occurrences,
       GROUP_CONCAT(student_id)          AS student_ids,
       GROUP_CONCAT(full_name SEPARATOR ' | ') AS student_names
FROM   students
GROUP  BY admission_no
HAVING COUNT(*) > 1
ORDER  BY admission_no;

-- ---------------------------------------------------------------------------
-- 1.3  Duplicate fee transactions
--      Same admission_no + type + amount + DATE, appearing more than once.
--      Why date matters: a student can legitimately pay the same amount twice
--      (e.g. two instalments of 8,000) on DIFFERENT days. Same amount on the
--      SAME day is the signature of a double-posted / double-submitted entry.
-- ---------------------------------------------------------------------------
SELECT admission_no, transaction_type, total_amount, transaction_date,
       COUNT(*)                 AS occurrences,
       GROUP_CONCAT(transaction_id ORDER BY transaction_id) AS transaction_ids
FROM   fee_transactions
GROUP  BY admission_no, transaction_type, total_amount, transaction_date
HAVING COUNT(*) > 1
ORDER  BY admission_no;

-- ---------------------------------------------------------------------------
-- 1.4  Students who currently have an outstanding / due amount
--      (students table has 5 duplicate admission_no rows -> pick the original
--       record = lowest student_id, so nobody is listed twice)
-- ---------------------------------------------------------------------------
SELECT s.student_id, s.admission_no, s.full_name, p.program_name, b.outstanding_amount
FROM  (SELECT admission_no,
              SUM(CASE transaction_type WHEN 'DUE' THEN total_amount ELSE -total_amount END) AS outstanding_amount
       FROM   fee_transactions
       GROUP  BY admission_no
       HAVING outstanding_amount > 0) b
JOIN  students s ON s.student_id = (SELECT MIN(s2.student_id) FROM students s2 WHERE s2.admission_no = b.admission_no)
JOIN  programs p ON p.program_id = s.program_id
ORDER BY b.outstanding_amount DESC, s.admission_no
LIMIT 20;   -- first 20 rows shown; remove LIMIT for the full list

-- 1.4b  How many students have a balance, and the total outstanding
SELECT COUNT(*) AS students_with_due, SUM(outstanding_amount) AS total_outstanding
FROM  (SELECT admission_no,
              SUM(CASE transaction_type WHEN 'DUE' THEN total_amount ELSE -total_amount END) AS outstanding_amount
       FROM   fee_transactions
       GROUP  BY admission_no
       HAVING outstanding_amount > 0) x;

-- ---------------------------------------------------------------------------
-- 1.5  Total due amount, admission-number-wise (students with a balance)
--      with a breakdown of DUE / PAID / CONCESSION
-- ---------------------------------------------------------------------------
SELECT admission_no,
       SUM(CASE WHEN transaction_type = 'DUE'        THEN total_amount ELSE 0 END) AS total_due_raised,
       SUM(CASE WHEN transaction_type = 'PAID'       THEN total_amount ELSE 0 END) AS total_paid,
       SUM(CASE WHEN transaction_type = 'CONCESSION' THEN total_amount ELSE 0 END) AS total_concession,
       SUM(CASE transaction_type WHEN 'DUE' THEN total_amount ELSE -total_amount END) AS outstanding_due
FROM   fee_transactions
GROUP  BY admission_no
HAVING outstanding_due > 0
ORDER  BY outstanding_due DESC, admission_no
LIMIT 20;   -- first 20 rows shown; remove LIMIT for the full list

-- 1.5b  Same balance AFTER ignoring the duplicate rows found in 1.3
--       (keeps the lowest transaction_id of every duplicate group). Shows only
--       the admissions whose balance is affected by the duplicates.
SELECT r.admission_no, r.raw_outstanding, d.deduped_outstanding,
       r.raw_outstanding - d.deduped_outstanding AS inflated_by
FROM  (SELECT admission_no,
              SUM(CASE transaction_type WHEN 'DUE' THEN total_amount ELSE -total_amount END) AS raw_outstanding
       FROM fee_transactions GROUP BY admission_no) r
JOIN  (SELECT t.admission_no,
              SUM(CASE t.transaction_type WHEN 'DUE' THEN t.total_amount ELSE -t.total_amount END) AS deduped_outstanding
       FROM fee_transactions t
       WHERE NOT EXISTS (SELECT 1 FROM fee_transactions x
                         WHERE x.admission_no = t.admission_no AND x.transaction_type = t.transaction_type
                           AND x.total_amount = t.total_amount AND x.transaction_date = t.transaction_date
                           AND x.transaction_id < t.transaction_id)
       GROUP BY t.admission_no) d ON d.admission_no = r.admission_no
WHERE r.raw_outstanding <> d.deduped_outstanding
ORDER BY r.admission_no;

-- ---------------------------------------------------------------------------
-- 1.6  Top 10 students by total fee collected (PAID)
-- ---------------------------------------------------------------------------
SELECT s.admission_no, s.full_name, p.program_name,
       SUM(t.total_amount) AS total_paid, COUNT(*) AS payments
FROM   fee_transactions t
JOIN   students s ON s.student_id = (SELECT MIN(s2.student_id) FROM students s2 WHERE s2.admission_no = t.admission_no)
JOIN   programs p ON p.program_id = s.program_id
WHERE  t.transaction_type = 'PAID'
GROUP  BY s.student_id, s.admission_no, s.full_name, p.program_name
ORDER  BY total_paid DESC, s.admission_no
LIMIT  10;

-- ---------------------------------------------------------------------------
-- 1.7  Top programs by total fee collected (PAID)
-- ---------------------------------------------------------------------------
SELECT p.program_id, p.program_name, d.department_name,
       SUM(t.total_amount)                AS total_collected,
       COUNT(DISTINCT t.admission_no)     AS paying_students
FROM   fee_transactions t
JOIN   students s ON s.student_id = (SELECT MIN(s2.student_id) FROM students s2 WHERE s2.admission_no = t.admission_no)
JOIN   programs p ON p.program_id = s.program_id
JOIN   departments d ON d.department_id = p.department_id
WHERE  t.transaction_type = 'PAID'
GROUP  BY p.program_id, p.program_name, d.department_name
ORDER  BY total_collected DESC;

-- ---------------------------------------------------------------------------
-- 1.8  Parent amount <> SUM(child detail amounts)
--      (only parents that HAVE children; parents with none are Q1.9)
-- ---------------------------------------------------------------------------
SELECT t.transaction_id, t.admission_no, t.transaction_type, t.transaction_date,
       t.total_amount                         AS parent_amount,
       SUM(d.amount)                          AS child_amount,
       t.total_amount - SUM(d.amount)         AS difference,
       COUNT(d.detail_id)                     AS detail_rows
FROM   fee_transactions t
JOIN   fee_transaction_details d ON d.transaction_id = t.transaction_id
GROUP  BY t.transaction_id, t.admission_no, t.transaction_type, t.transaction_date, t.total_amount
HAVING t.total_amount <> SUM(d.amount)
ORDER  BY t.transaction_id;

-- ---------------------------------------------------------------------------
-- 1.9  Parent transactions with NO child records
-- ---------------------------------------------------------------------------
SELECT t.*
FROM   fee_transactions t
LEFT   JOIN fee_transaction_details d ON d.transaction_id = t.transaction_id
WHERE  d.detail_id IS NULL
ORDER  BY t.transaction_id;

-- ---------------------------------------------------------------------------
-- 1.10 Child records whose parent transaction does not exist (orphans)
-- ---------------------------------------------------------------------------
SELECT d.*
FROM   fee_transaction_details d
LEFT   JOIN fee_transactions t ON t.transaction_id = d.transaction_id
WHERE  t.transaction_id IS NULL
ORDER  BY d.detail_id;

-- ---------------------------------------------------------------------------
-- 1.11 Single reconciliation report, per admission number
--      Parent and child are aggregated SEPARATELY first and then joined, so the
--      1-to-many join cannot multiply the parent amount (classic fan-out bug).
--      The admission list is the UNION of both sides so that admissions that
--      exist only as orphan child rows are not lost.
--      Only admissions with a Difference are shown (remove the WHERE for all 300).
-- ---------------------------------------------------------------------------
SELECT a.admission_no                         AS `Admission Number`,
       COALESCE(p.txn_count, 0)               AS `Transaction Count`,
       COALESCE(p.txn_amount, 0)              AS `Transaction Amount`,
       COALESCE(c.detail_count, 0)            AS `Detail Count`,
       COALESCE(c.detail_amount, 0)           AS `Detail Amount`,
       COALESCE(p.txn_amount, 0) - COALESCE(c.detail_amount, 0) AS `Difference`
FROM  (SELECT admission_no FROM fee_transactions
       UNION
       SELECT admission_no FROM fee_transaction_details) a
LEFT JOIN (SELECT admission_no, COUNT(*) AS txn_count, SUM(total_amount) AS txn_amount
           FROM fee_transactions GROUP BY admission_no) p ON p.admission_no = a.admission_no
LEFT JOIN (SELECT admission_no, COUNT(*) AS detail_count, SUM(amount) AS detail_amount
           FROM fee_transaction_details GROUP BY admission_no) c ON c.admission_no = a.admission_no
WHERE  COALESCE(p.txn_amount, 0) <> COALESCE(c.detail_amount, 0)
ORDER  BY ABS(COALESCE(p.txn_amount, 0) - COALESCE(c.detail_amount, 0)) DESC, a.admission_no;
