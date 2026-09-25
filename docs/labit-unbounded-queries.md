# labit-ui screens backed by unbounded queries

Found 2026-09-25 while investigating slow requisition-item / sample-collection
screens. Evidence: `pg_stat_statements` deltas across a user session (14:22 to
14:30 UTC) plus the database's slow-statement log (`log_min_duration_statement =
250ms`, 101 statements, 120.7 s of database time in 16 minutes, all from the
primary labit-core on VPS2). Code traced in `labit-core` (`app/services/*.py`,
`app/routers/*.py`). Nothing here has been changed in the application.

## Why status bounds help: the data is almost all "finished"

| Table | Total | Still open |
| --- | --- | --- |
| `sample` | 4,992 | 233 (4.7%): 19 `uncollected` + 214 `collected` (4,759 are `received`) |
| `result` | 50,529 | 2,923 draft (5.8%); 47,367 `submitted`, 239 `cancelled` |
| `requisition_item` | 10,363 | 76 cancelled; the whole table is only 30 days old (about 470 items a day) |

Queues and badges that only care about open work should filter on status first.
Every day of data makes an unbounded scan more expensive; a status bound does not
grow with history.

## Flagged queries (highest priority first)

"buffers/call" is measured in the test window; rows/call is what the screen
actually receives.

| # | Screen / endpoint (labit-core) | What it computes | Bound today | Evidence | Recommended bound |
| --- | --- | --- | --- | --- | --- |
| 1 | Department pending badges, `GET /api/samples/board/pending-counts` (`sample_service.pending_counts`) | `count(DISTINCT s.id)` per department | none | 2.6 s per call, 944k buffers, returns 6 rows | `s.status IN ('uncollected','collected')` first (233 of 4,992 samples) |
| 2 | Pending-tube queue (`_PENDING_COLLECTION_SQL`, reached from `/api/dashboard/summary`, `/api/dashboard/priority-patients`, `/api/dashboard-framework/{code}/data`, `/api/mis/department-wise-worklist`) | tube counts for **every requisition**, then filters `tube_count > collected_tube_count` afterwards | none (filter applied last) | 88,790 lifetime calls, about 19,900 s cumulative; about 980k buffers per call; keeps about 74 rows | restrict to requisitions that have an open sample or uncollected item before computing tube counts; add a date safety net (e.g. last 30 days) |
| 3 | Rejected-sample queue, `GET /api/results/rejected-sample-callbacks` (`result_service.rejected_sample_callback_queue`) | `WITH item_latest AS (SELECT DISTINCT ON (ri.id) ...)` over all items, then filters `sample_status = $6` | none inside the CTE | 12,089 calls, 2.1M buffers per call, **0 rows returned** | push the status filter into the CTE (an index on `sample(status)` already exists but cannot be used) |
| 4 | Ready-to-dispatch list, `GET /api/delivery/ready` (`delivery_service.ready_requisitions`) | `MAX(COALESCE(released_at, created_at ...))` across reports and results, then `LIMIT 100` | none | 2.6 s per call, 1.84M buffers, 100 rows | only reports that are submitted and not yet dispatched, released within N days |
| 5 | Machine results (`_MACHINE_ORDER_QUEUE_*`, `/api/results/machine-inbox/{sample_id}`, `/api/results/critical/staged`, dashboards) | joins over `machine_result_inbox` (79,151 rows, 47,774 sequential scans lifetime) | none | 1.6 s per call, 307k buffers, 300 rows | only untransferred / recent rows, by status and date |
| 6 | Requisition-item worklist and its four follow-up batch lookups (item samples, latest collected_at, collected/received flags, barcodes) | worklist returns up to **5,000 rows** for a 3-day window (about 1,540 items); each follow-up then processes the whole id list | date window only (3 days observed), limit 5,000 | the four follow-ups were 78 s of the 120.7 s: item samples 28.2 s, latest collected 22.5 s, flags 18.7 s, barcodes 8.6 s; 0.4 to 2.5 s each per screen load | page the worklist (50 to 100 rows) and compute stage/barcodes only for the visible rows; skip items whose requisition is fully received and reported |

Also seen: a one-off group-by over `diagnotech.newtestresult` (19.5M rows, 127
calls) with no date or status bound; and dashboards polling heavily (9,056
statements in 4 minutes with the lab closed).

## Two things to change at the caller, not the query

- **Polling.** The heavy queries above are reached from dashboard endpoints that
  refresh continuously. Cache the badge and queue results for 30 to 60 s and pause
  refresh while the tab is hidden.
- **Fan-out.** One worklist load runs about five heavy statements in sequence.
  Batch or paginate them as in #6.

## Measured, and not yet explained

- Replaying the item follow-up query against production with the ids a 3-day
  worklist would send (1,544) takes 22 ms and 36k buffers; cost is linear at about
  24 buffers per id (414 ids: 10k buffers). Even 5,000 ids would be about 120k
  buffers. The live calls took 400 to 2,500 ms and touched 0.1 to 1.2 million
  buffers, 10 to 30 times more than any replay. The statement itself is
  therefore not the whole story, and the actual id lists sent by the screens are
  not known (the slow-query log did not record the array parameters).
- To close the gap: log the length of the id list at the call sites in labit-core,
  or run one controlled screen load with `log_statement = 'all'` on
  `labit_core_rw` for two minutes (heavy log volume) and read the parameters.
- Ruled out: missing indexes on the joined tables, memory, a generic-vs-custom
  plan problem (23 ms vs 7 ms in replay), locks (0 lock waits or deadlocks logged).

## Not changed

No index or setting was added for these. Bounding the queries in the application
is the durable fix; indexes come after, sized to the new predicates (for example a
partial index on `sample (requisition_id) WHERE status IN ('uncollected','collected')`).
