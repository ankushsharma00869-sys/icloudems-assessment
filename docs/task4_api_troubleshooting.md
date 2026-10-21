# Task 4 — API Troubleshooting

## Scenario A — ADM10025: HTTP 200 "Payment successful", but due still shows ₹5,000

### Timeline reconstructed from the logs

| Time | Component | What happened | OK? |
|---|---|---|---|
| 14:32:07 | PaymentGateway | Razorpay returned SUCCESS for `PAY45872` (₹15,000) | ✅ money was collected |
| 14:32:08 | FeeService | `fee_transactions` row 518 (PAID, ₹15,000) inserted | ✅ |
| 14:32:08 | FeeService | `fee_transaction_details` — Tuition Fee ₹10,000 inserted | ✅ |
| 14:32:08 | FeeService | `fee_transaction_details` — Exam Fee ₹5,000 **failed**: `Duplicate entry '3024' for key 'detail_id_seq'` | ❌ |
| 14:32:08 | FeeService | Error was **caught by a generic exception handler, transaction NOT rolled back** | ❌ |
| 14:32:08 | PaymentController | Returned HTTP 200 `status:true` anyway | ❌ misleading |
| 14:32:09 | DueCalculationJob | Recomputed due from `fee_transaction_details` → ₹15,000 − ₹10,000 = **₹5,000** | ❌ |

### 1. Probable root cause
Parent and child rows are written as separate, non-atomic steps. The parent row (₹15,000) and the first child line were saved, the second child insert collided on a duplicate `detail_id` (the key generator produced an id that already exists), and a catch-all `catch (Exception)` swallowed the error without rolling back or surfacing it. The API then trusted only the gateway result and reported success. The due calculation sums **child** rows, so it sees only ₹10,000 of the ₹15,000 payment → ₹5,000 "due".

So there are three stacked defects: (1) non-atomic multi-table write, (2) swallowed exception / no rollback, (3) unsafe `detail_id` generation (app-side sequence out of sync with the table, instead of `AUTO_INCREMENT`). A fourth design smell: the due job derives the balance from child rows rather than the authoritative parent ledger, so it cannot notice that a child is missing.

*(The dataset I was given has detail ids up to 905, not 3024 — the log is from a different environment — but the mechanism is identical, and I reproduced the resulting data state for ADM10025 in Task 2.)*

### 2. Classification
**Application issue** (primary) — transaction management and exception handling in `FeeService`/`PaymentController`.
Contributing: **Database/Data** (duplicate `detail_id`; no FK/constraint enforcing parent = Σ children). It is **not** an API-contract, network or configuration problem: the request was valid and the gateway worked.

### 3. SQL to verify from the database side
```sql
-- (a) Parent exists but children don't add up to it?
SELECT t.transaction_id, t.total_amount AS parent_amount,
       COALESCE(SUM(d.amount),0) AS child_amount,
       t.total_amount - COALESCE(SUM(d.amount),0) AS missing
FROM fee_transactions t
LEFT JOIN fee_transaction_details d ON d.transaction_id = t.transaction_id
WHERE t.admission_no = 'ADM10025'
GROUP BY t.transaction_id, t.total_amount;

-- (b) Which fee heads are on the DUE but absent on the PAID?
SELECT d.fee_head, d.amount
FROM fee_transaction_details d
WHERE d.transaction_id = 517
  AND d.fee_head NOT IN (SELECT fee_head FROM fee_transaction_details WHERE transaction_id = 518);

-- (c) Is the id generator behind the table? (the duplicate-key cause)
SELECT MAX(detail_id) AS max_in_table FROM fee_transaction_details;
SELECT * FROM fee_transaction_details WHERE detail_id = 3024;       -- the colliding id from the log
SHOW CREATE TABLE fee_transaction_details;                          -- is detail_id AUTO_INCREMENT?
SHOW INDEX FROM fee_transaction_details WHERE Key_name = 'detail_id_seq';

-- (d) Is this a one-off or systemic? every broken parent in the system:
SELECT t.transaction_id, t.admission_no, t.total_amount, SUM(d.amount) child_sum
FROM fee_transactions t JOIN fee_transaction_details d ON d.transaction_id = t.transaction_id
GROUP BY t.transaction_id, t.admission_no, t.total_amount
HAVING t.total_amount <> SUM(d.amount);
```
Result on our data: 518 → parent 15,000 vs child 10,000, missing 5,000 (Task 2 output); query (d) also finds 15 other broken parents, so the problem is systemic, not just one student.

### 4. Fix and how to test it
**Immediate data fix:** insert the missing Exam Fee ₹5,000 child for transaction 518 (done in Task 2), then re-run the due job.

**Code fix**
1. Wrap parent insert + **all** child inserts in **one DB transaction**; commit only when every row succeeded; `ROLLBACK` on any failure.
2. Remove the generic catch-all. Catch specific exceptions, log with `payment_id`, re-throw so the transaction rolls back.
3. If persistence fails *after* the gateway captured money, do **not** return 200 "success". Return a clear "payment received, confirmation pending" state and queue a retry/reconciliation (see Scenario B).
4. Make `detail_id` `AUTO_INCREMENT` (DB-generated); drop the app-side sequence.
5. Make the endpoint idempotent: unique key on `payment_id` / `gateway_ref` so retries cannot double-post.
6. Add a FK `fee_transaction_details.transaction_id → fee_transactions` and a post-commit assertion `parent.total_amount = Σ children`.
7. Compute the due from the parent ledger, and alert when parent ≠ Σ children.

**Testing**
- Unit/integration test: mock the 2nd child insert to throw a duplicate-key error → assert **no** `fee_transactions` row remains (full rollback), the API returns non-200 / pending state, and an error is logged with `payment_id`.
- Happy-path test: pay ₹15,000 with 2 fee heads → parent = Σ children, due = 0.
- Concurrency test: 50 parallel payments → no duplicate `detail_id`.
- Idempotency test: send `PAY45872` twice → exactly one parent row.
- Data regression: ADM10025 due = 0 after the fix; nightly integrity query returns 0 rows.

---

## Scenario B — ADM10089: HTTP 500, gateway shows SUCCESS, no DB record

### Timeline
| Time | What happened |
|---|---|
| 10:14:02 | Request received; **gateway captured ₹12,000 → SUCCESS** (`RZP_7QW2XZ9`) |
| 10:14:02 → 10:14:32 | `INSERT INTO fee_transactions` **waited ~30 s** for a row/table lock |
| 10:14:32 | `Lock wait timeout exceeded` → insert failed → unhandled → HTTP 500 |
| 10:14:32 | ReconciliationJob: gateway SUCCESS but **no matching fee_transactions record** |

### 5. Probable root cause
**Database lock contention.** Another session was holding a lock on `fee_transactions` (long-running transaction, a batch/report/due-calculation job, an un-committed transaction left open by another request, or a missing index causing wide range/table locks) for longer than the lock-wait timeout (~30 s as logged; MySQL's default `innodb_lock_wait_timeout` is 50 s). The insert timed out.
The deeper design flaw: the system **charges the card first and writes to the DB second**, with no retry, no compensation and no pending-state record. So a transient DB problem turned into "money taken, nothing recorded, user told it failed" — the worst combination, because the student may pay again.

### 6. Classification
**Database issue** (locking / concurrency) as the trigger, with an **Application** design defect (non-resilient payment flow, unhandled exception → 500) as the reason it became a financial inconsistency.

### 7. Fix, testing, and reconciling the orphan payment

**Find the blocker (live or right after):**
```sql
SHOW FULL PROCESSLIST;
SELECT * FROM information_schema.INNODB_TRX ORDER BY trx_started;          -- long-open transactions
SELECT * FROM sys.innodb_lock_waits;                                        -- who blocks whom
SHOW ENGINE INNODB STATUS;                                                  -- LATEST DETECTED DEADLOCK section
```

**Fix**
1. Keep transactions short; never hold a transaction open across a gateway call or user think-time; move heavy jobs (due calc, reports) off peak and batch them in small commits.
2. Add the missing indexes on the columns used in `WHERE`/`JOIN` of the locking statements (e.g. `fee_transactions(admission_no, transaction_date)`), so InnoDB locks few rows, not a range.
3. Retry the insert with exponential back-off on error 1205 (lock wait) / 1213 (deadlock) — safe because the write is idempotent (unique `payment_id`).
4. **Reorder / harden the flow:** write a `payment_intent` row with status `PENDING` (keyed by `payment_id`) *before* calling the gateway; mark it `SUCCESS` after; use the gateway **webhook** as a second, independent path that finalises any intent the browser flow failed to finish (outbox/saga pattern).
5. Never return a bare 500 after a successful capture: return "payment received — confirmation in progress" so the student does not pay twice.
6. Monitoring: alert on lock waits, on `innodb_row_lock_time`, and on any gateway SUCCESS without a matching ledger row.

**Testing**
- Lock test: open a transaction that `SELECT … FOR UPDATE`s the target rows in session 1, fire the payment in session 2 → assert retry kicks in, and after session 1 commits the payment is recorded exactly once.
- Chaos test: force the DB insert to fail after gateway success → assert a `PENDING` intent exists and the webhook/reconciler later completes it.
- Idempotency test: replay the same webhook 3× → one ledger row.
- Load test with the due-calculation job running concurrently.

**Reconciling a payment the gateway shows as successful but that never reached the DB**
1. **Detect:** daily job compares the gateway settlement/payment report (payment_id, gateway_ref, amount, time) with the ledger.
   ```sql
   -- gateway_payments = imported gateway export (staging table)
   SELECT g.payment_id, g.gateway_ref, g.admission_no, g.amount, g.paid_at
   FROM   gateway_payments g
   LEFT   JOIN fee_transactions t ON t.gateway_ref = g.gateway_ref   -- or payment_id
   WHERE  g.status = 'SUCCESS' AND t.transaction_id IS NULL;
   ```
2. **Verify** it is genuinely missing (not just delayed) and that the student did not already pay again (check for a later successful payment of the same amount).
3. **Repair** by posting the missing ledger entry, idempotently, in one transaction (parent + all fee-head children), tagged with `gateway_ref`/`payment_id` and a note "recovered by reconciliation":
   ```sql
   START TRANSACTION;
   INSERT INTO fee_transactions (transaction_id, admission_no, transaction_date, transaction_type, total_amount, status)
   SELECT <new_id>, 'ADM10089', '2025-09-16', 'PAID', 12000.00, 'Success'
   WHERE NOT EXISTS (SELECT 1 FROM fee_transactions WHERE gateway_ref = 'RZP_7QW2XZ9');
   -- + child rows per fee head, summing to 12,000
   COMMIT;
   ```
4. **Re-run** the due calculation for ADM10089, confirm parent = Σ children and the balance dropped by ₹12,000; tell the student/administrator.
5. If the student paid twice, **refund** the duplicate through the gateway.
6. Keep an audit trail (who/when/why) and review the incident to fix the root cause above.
