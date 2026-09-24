# Cylon Skill Recovery v0.1

## Goal

A project must not remain permanently stuck because an agent, subagent, host, process, scheduler, or network path disappears.

Recovery must be bounded, idempotent, auditable, and protected against stale workers.

## Recovery signals

An agent/coordinator may consider work recoverable when canonical backend state shows one or more of:

- lease expired
- heartbeat stale beyond policy
- task in `STALLED`
- execution attempt failed with retryable classification
- reviewer decision requires correction
- coordinator lease/epoch expired
- prior mutation outcome is uncertain after transport failure

Local suspicion alone is insufficient; re-read backend state first.

## Recovery sequence

1. Re-read canonical task/project state.
2. Verify the current attempt/lease/epoch and whether another agent has already recovered it.
3. Classify the failure.
4. If retryable and budget remains, create or acquire a fresh authoritative attempt/lease.
5. Prefer a fresh subagent for substantive correction after review failure when supported.
6. Preserve usable checkpoints/artifacts but never inherit stale mutation authority.
7. Record recovery reason, previous attempt/agent, new attempt/agent, and retry count.
8. If retry budget is exhausted or authority is ambiguous, move to `BLOCKED` or `HUMAN_REQUIRED` according to policy.

## Failure classes

Suggested v0.1 classes:

- `NETWORK_TRANSIENT`: retry with backoff and same idempotency key for uncertain mutations.
- `BACKEND_UNAVAILABLE`: bounded retry/backoff; no local authoritative state changes.
- `RATE_LIMITED`: backoff with jitter.
- `AGENT_UNREACHABLE`: wait for lease expiry, then reassign with a new attempt.
- `SUBAGENT_FAILURE`: validate partial output; retry via fresh subagent if policy permits.
- `TEST_FAILURE`: correction attempt, normally fresh subagent/context.
- `AUTH_FAILED`: non-retryable without changed credentials; `HUMAN_REQUIRED`.
- `PERMISSION_DENIED`: fail closed; coordinator/owner review required.
- `SCOPE_AMBIGUOUS`: `HUMAN_REQUIRED` or authorized coordinator clarification.
- `PROTOCOL_INCOMPATIBLE`: stop; no automatic downgrade.
- `REPEATED_IDENTICAL_FAILURE`: circuit breaker.

## Retry budget

Default v0.1 policy:

- maximum automatic task attempts: 3
- maximum identical failure repetitions before circuit break: 2
- no infinite retry loops

Project policy may tighten these limits but must not silently remove boundedness.

## Zombie-worker protection

A worker whose lease/attempt has expired or been superseded loses mutation authority immediately. Any late progress/result from that stale attempt must be rejected by the backend contract.

## Coordinator recovery

Coordinator authority should use a renewable lease or monotonically increasing epoch. If the coordinator disappears:

1. verify expiry using server time
2. eligible agent attempts atomic takeover
3. backend issues a new lease/epoch
4. all mutations from the old epoch become stale and are rejected

No two coordinators may be authoritative for the same epoch.

## Checkpoints

Long-running work should publish safe, non-secret checkpoints where useful. A checkpoint may describe artifacts, tests, progress, and next step, but it does not grant ownership. A recovering attempt must acquire its own fresh lease/fencing authority.

## Wake scan order

On wake, a coordinator-capable agent should generally check:

1. its own active work
2. pending decisions/reviews
3. new authorized directives
4. claimable tasks
5. expired task leases
6. stalled/recoverable tasks
7. coordinator lease state
8. blocked work that may now be recoverable

This ordering is advisory; backend atomicity and authorization are authoritative.
