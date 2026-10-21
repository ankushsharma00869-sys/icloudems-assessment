-- ============================================================================
-- TASK 2 : Real-World Support Bug - ADM10025            (database: erp)
-- Ticket : "Student ADM10025 paid 15,000, payment successful, ERP still shows
--           5,000 as due."
-- Run    : mysql -u root -p erp -t < sql/task2_adm10025_bug.sql
-- NOTE   : run AFTER task1 (Task 1 report 1.8 should show the broken state).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 2.1  INVESTIGATION
-- ---------------------------------------------------------------------------
-- Step 1: what does the parent ledger say?
SELECT transaction_id, transaction_date, transaction_type, total_amount, status
FROM   fee_transactions
WHERE  admission_no = 'ADM10025'
ORDER  BY transaction_id;

-- Step 2: what do the child (fee-head) lines say?
SELECT detail_id, transaction_id, fee_head, amount, status
FROM   fee_transaction_details
WHERE  admission_no = 'ADM10025'
ORDER  BY transaction_id, detail_id;

-- Step 3: balance computed FROM THE PARENT ledger  (DUE - PAID)
SELECT SUM(CASE transaction_type WHEN 'DUE' THEN total_amount ELSE -total_amount END) AS due_from_parent_ledger
FROM   fee_transactions
WHERE  admission_no = 'ADM10025';

-- Step 4: balance computed FROM THE CHILD lines (this is what DueCalculationJob does)
SELECT SUM(CASE t.transaction_type WHEN 'DUE' THEN d.amount ELSE -d.amount END) AS due_from_child_details
FROM   fee_transaction_details d
JOIN   fee_transactions t ON t.transaction_id = d.transaction_id
WHERE  t.admission_no = 'ADM10025';

-- ---------------------------------------------------------------------------
-- 2.3  PROOF QUERY - parent vs child per transaction (shows the discrepancy)
-- ---------------------------------------------------------------------------
SELECT t.transaction_id, t.transaction_type, t.total_amount AS parent_amount,
       COALESCE(SUM(d.amount), 0)                       AS child_amount,
       t.total_amount - COALESCE(SUM(d.amount), 0)      AS missing_amount,
       GROUP_CONCAT(d.fee_head ORDER BY d.detail_id)    AS fee_heads_present
FROM   fee_transactions t
LEFT   JOIN fee_transaction_details d ON d.transaction_id = t.transaction_id
WHERE  t.admission_no = 'ADM10025'
GROUP  BY t.transaction_id, t.transaction_type, t.total_amount
ORDER  BY t.transaction_id;

-- Same proof, side by side: the DUE (517) has Tuition+Exam, the PAID (518) only Tuition
SELECT d17.fee_head,
       d17.amount                      AS due_line_517,
       COALESCE(d18.amount, 0)         AS paid_line_518,
       d17.amount - COALESCE(d18.amount, 0) AS still_shown_as_due
FROM   fee_transaction_details d17
LEFT   JOIN fee_transaction_details d18 ON d18.transaction_id = 518 AND d18.fee_head = d17.fee_head
WHERE  d17.transaction_id = 517;

-- ---------------------------------------------------------------------------
-- 2.5  CORRECTION
--      The Exam Fee (5,000) line of PAID transaction 518 was never written.
--      Insert exactly that missing line, inside a transaction, with guards so
--      the script is safe to run twice (idempotent).
--      detail_id: use MAX+1 (906). The original insert failed because the app's
--      id generator handed out an id that already existed.
-- ---------------------------------------------------------------------------
START TRANSACTION;

INSERT INTO fee_transaction_details (detail_id, transaction_id, admission_no, fee_head, amount, status)
SELECT (SELECT MAX(detail_id) + 1 FROM fee_transaction_details), 518, 'ADM10025', 'Exam Fee', 5000.00, 'Success'
FROM   DUAL
WHERE  EXISTS     (SELECT 1 FROM fee_transactions WHERE transaction_id = 518 AND admission_no = 'ADM10025')
AND    NOT EXISTS (SELECT 1 FROM fee_transaction_details WHERE transaction_id = 518 AND fee_head = 'Exam Fee');

-- Safety check BEFORE commit: parent must now equal sum of children (expect 0 rows differing)
SELECT t.transaction_id, t.total_amount, SUM(d.amount) AS child_sum,
       IF(t.total_amount = SUM(d.amount), 'OK - matches', 'STILL BROKEN') AS check_result
FROM   fee_transactions t JOIN fee_transaction_details d ON d.transaction_id = t.transaction_id
WHERE  t.transaction_id = 518
GROUP  BY t.transaction_id, t.total_amount;

COMMIT;

-- ---------------------------------------------------------------------------
-- 2.5b  VERIFY AFTER FIX
-- ---------------------------------------------------------------------------
SELECT d.detail_id, d.transaction_id, d.fee_head, d.amount
FROM   fee_transaction_details d WHERE d.admission_no = 'ADM10025' ORDER BY d.transaction_id, d.detail_id;

SELECT SUM(CASE t.transaction_type WHEN 'DUE' THEN d.amount ELSE -d.amount END) AS due_from_child_details_after_fix
FROM   fee_transaction_details d JOIN fee_transactions t ON t.transaction_id = d.transaction_id
WHERE  t.admission_no = 'ADM10025';          -- expected 0.00

-- ---------------------------------------------------------------------------
-- 2.6  PREVENTION (database-level guard-rails; shown for the write-up, not
--      executed here because they change the schema of a live system)
-- ---------------------------------------------------------------------------
-- (a) Real foreign key so orphan children can never exist:
--     ALTER TABLE fee_transaction_details
--       ADD CONSTRAINT fk_ftd_txn FOREIGN KEY (transaction_id) REFERENCES fee_transactions(transaction_id);
-- (b) Let the DB generate ids so two writers can never collide on detail_id:
--     ALTER TABLE fee_transaction_details MODIFY detail_id INT NOT NULL AUTO_INCREMENT;
-- (c) A nightly integrity check - must return ZERO rows, otherwise alert:
--     SELECT t.transaction_id, t.total_amount, COALESCE(SUM(d.amount),0) AS child_sum
--     FROM fee_transactions t LEFT JOIN fee_transaction_details d ON d.transaction_id = t.transaction_id
--     GROUP BY t.transaction_id, t.total_amount
--     HAVING t.total_amount <> COALESCE(SUM(d.amount),0);
