# Turn architecture claims into bounded failure tests

Use isolated data and fixtures. A skill is not authorization to crash production,
probe another tenant's real data, send external messages or replay real payments.
Read actual runtime entrypoints and legacy paths; UI controls alone are not evidence.

| Claim | Cheapest discriminating attacks |
|---|---|
| Guaranteed event delivery | Crash after DB commit, before publication; after consumer A before B; duplicate delivery; competing workers; stale lock; dead-letter replay |
| Tenant isolation | Guessed ID, missing tenant, background job lacking context, cross-tenant AI tool, export/search/cache path |
| Idempotency | Same key/same payload, same key/different payload, concurrent duplicates, partial external effect then retry |
| Safe AI writes | Unknown tool, bypass via legacy endpoint/direct ORM, missing authorization, stale approval, injected instruction in retrieved data |
| Atomic state change | Failure between writes, rollback, retry after timeout, inconsistent audit/event record |
| Recoverability | Restore a backup into an isolated environment; verify state/invariants and replay semantics |
| Performance improvement | Strong simple baseline, warm/cold cache, same workload and concurrency, tail latency, throughput, failures and resource cost |

For each claim identify the exact boundary: request accepted, committed, published,
delivered, acknowledged, applied, or externally settled. Do not infer exactly-once
semantics from a single component's deduplication. Include partial failure and
concurrency where relevant, not just sequential happy-path tests.

Distinguish a test finding a real bypass from a hypothetical checklist concern.
Record fixture, command, observable outcome, violating path and minimal repair.
An unavailable production test is a scope limitation, not permission to guess.

Prefer the existing deterministic/domain path over proposing another framework.
After a decisive failure, preserve the witness and stop the release claim; don't
quietly implement a redesign during the falsification pass. Ordinary bounded
reproduction fixes are allowed when needed, but disclose them and avoid altering
the frozen object whose claim is being assessed.
