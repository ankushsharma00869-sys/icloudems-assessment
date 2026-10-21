# Task 5 — AI Technical Troubleshooting

**Question asked:** "What is the outstanding fee for admission number ADM10501?"
**Live DB:** ₹8,500  **AI answered:** ₹12,500  **Context the model was given:** snapshot generated 2025‑09‑15 23:00 IST — Outstanding ₹12,500, last payment ₹5,000 on 2025‑09‑10.

The key observation: **the AI's answer is exactly what the retrieved context said.** The model did not invent a number — it faithfully repeated stale input.

## 1. Possible reasons the AI gave an incorrect answer
1. **Stale snapshot in the retrieval layer** — data was exported at 23:00 the previous night (or a batch/cron ETL) and not refreshed; a payment (₹4,000, since 12,500 → 8,500) happened after the snapshot.
2. **Cache / vector-store staleness** — embedded fee records in a vector DB or a Redis/API cache with no TTL or no invalidation on payment events.
3. **Retrieval pulled the wrong/old version** — several versions of the same student record are indexed and the retriever returned the oldest/highest-similarity one instead of the latest.
4. **Read-replica lag or reporting DB** — the AI reads from a replica / data warehouse that is behind the primary.
5. **API/tool returns cached or aggregated values** — the "student fee" API itself serves a precomputed `outstanding` column that is only refreshed by a nightly job.
6. **Wrong data joined** (different admission number, wrong academic year/term) — less likely here because admission no. and amount history are consistent with the same student.
7. **Prompt/context design** — no "as of" timestamp shown to the model or the user, no instruction to prefer fresh data or to flag old data, so a stale value is presented as current fact.
8. **LLM hallucination / mis-reading** — possible in general, but not supported by the evidence here (see §2).
9. **DB itself wrong** — ruled out as the cause: the live DB holds ₹8,500, the *source of truth*.

## 2. Most likely category — **RAG‑retrieval / stale context** (data-freshness issue in the retrieval layer)
Justification from the evidence:
- The answer **₹12,500 = the retrieved snapshot value**, character for character. A hallucination would not coincide with the context; so it is **not an LLM hallucination**.
- The snapshot is **timestamped 2025‑09‑15 23:00**, i.e. it is a point-in-time copy, while the live value is different (₹8,500). The gap (₹4,000) means a payment/concession was posted after 23:00 and never propagated → classic stale-data problem.
- The **Database is correct** (8,500) → not a DB fault.
- The retrieval layer chose to answer a *volatile, transactional* question from a *snapshot* instead of calling the live system → the design flaw is in **data retrieval / RAG**, with a secondary **context/prompt** weakness: the "Snapshot generated" time was in the context but the model neither surfaced it to the user ("as of 15 Sep 23:00") nor refused to present old data as current.
- Minor wording defect: the reply says "**Your** outstanding fee" although an administrator asked about a third party's admission number.

## 3. How I would investigate the complete flow
User Query → AI App → Data Retrieval/API → Database → Context/RAG → LLM → Final Response. Work **back-to-front with evidence at each hop**, using one `trace_id`/request id:

| # | Hop | What I check | Evidence |
|---|---|---|---|
| 1 | **User query** | Exact text, user's role/permissions, session, language. Did the intent classifier route it to "fee lookup"? | App logs, request body |
| 2 | **AI application / orchestrator** | Which tool/retriever was selected? Was a live API call possible but skipped? Any caching in the orchestrator? | Orchestrator trace, tool-call log |
| 3 | **Retrieval / API layer** | Query sent, source used (vector store vs. live API), returned doc ids, **document timestamp**, cache hit/miss, TTL, top‑k scores | Retriever logs, cache keys (`GET`/`TTL` in Redis) |
| 4 | **Database** | Actual value now, last transactions, replica vs. primary, when the snapshot job last ran / failed | SQL in §4, job scheduler logs |
| 5 | **Context / RAG construction** | The final prompt the model saw: is the stale snapshot there, were there multiple conflicting versions, is "as of" kept? | Prompt dump (redacted) |
| 6 | **LLM** | Re-run the *same* prompt with temperature 0 → does it reproduce ₹12,500? Does it ignore/obey context? | Replay |
| 7 | **Final response** | Post-processing/formatting that changes numbers? Citation/as-of shown? | Response log |

Then bisect: if the live API call returns 8,500 but the AI says 12,500 → fault is in retrieval/caching; if the prompt contains 8,500 and the model still says 12,500 → LLM/prompt issue. Here the prompt contained 12,500, so the fault is upstream of the LLM.

## 4. Verifying the actual database value independently
Bypass the AI, cache and API completely and query the **primary** database directly, read-only:
```sql
-- Outstanding from the authoritative ledger
SELECT admission_no,
       SUM(CASE transaction_type WHEN 'DUE' THEN total_amount ELSE -total_amount END) AS outstanding
FROM   fee_transactions
WHERE  admission_no = 'ADM10501'
GROUP  BY admission_no;

-- Evidence for WHY it differs from the snapshot: what happened after 15-Sep 23:00?
SELECT transaction_id, transaction_date, transaction_type, total_amount, status
FROM   fee_transactions
WHERE  admission_no = 'ADM10501' AND transaction_date >= '2025-09-10'
ORDER  BY transaction_date, transaction_id;
```
Cross-check: (a) run it on the primary, not a replica (`SELECT @@read_only, @@hostname;`), (b) compare with what the ERP UI shows for the same student, (c) check the snapshot table/job (`SELECT MAX(snapshot_time) …`) to confirm it is the older copy. Expected: ₹8,500 on live; a ₹4,000 PAID/CONCESSION row after the snapshot time.

## 5. Technical solution to prevent this class of error
1. **Do not answer transactional facts from snapshots/embeddings.** Give the AI a **live tool** (function-calling) such as `get_outstanding_fee(admission_no)` that queries the primary DB / a fresh read-API with the caller's permissions. Use RAG only for static knowledge (policies, FAQs).
2. **Freshness metadata + TTL:** every retrieved record carries `fetched_at`/`source`; the orchestrator rejects data older than a threshold (e.g. 5 min for balances) and refetches; show **"as of <timestamp>"** in the answer.
3. **Event-driven invalidation:** on each payment/concession/due event, invalidate or update the cache/index entry (CDC or outbox → cache), rather than relying on a nightly batch.
4. **Prompt/guardrails:** instruct the model to quote the as-of time, never present a value older than the threshold as current, and say "unable to confirm the live value" if the tool fails — instead of guessing. Refer to the student by admission number, not "your".
5. **Verification layer:** for numeric answers, a post-check compares the number in the reply with a fresh DB lookup; mismatch → block/auto-correct and log.
6. **Observability:** log trace_id → retrieved doc id/timestamp → final answer; alert when (answer ≠ live DB) or when the snapshot job fails or lags.

## 6. Testing the AI's response after the fix
- **Golden-answer test:** for a set of admission numbers (including ADM10501), compute the expected value by SQL and assert the AI's reply contains exactly that amount.
- **Staleness test (the regression for this bug):** change the DB value (post a ₹1,000 payment) and **immediately** ask again, without waiting for any batch → answer must change to the new value and show a fresh "as of" time.
- **Fault-injection:** make the live tool time out → the assistant must say it cannot confirm the live value, not quote an old snapshot.
- **Cache test:** warm the cache, update the DB, confirm invalidation/TTL works.
- **Automated comparison + monitoring:** run the SQL-vs-AI check as a scheduled test on a sample of students; alert on any mismatch.
- **Edge cases:** unknown admission number, student with zero balance, overpaid (negative) balance, user without permission.
