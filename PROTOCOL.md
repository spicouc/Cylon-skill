# Cylon Protocol v0.1

## 1. Scope

Cylon Protocol defines a backend-neutral coordination contract for independent AI agents. It specifies authority, identity, project membership, task lifecycle, review, delegation, idempotency, leases/fencing, recovery, and terminal states.

The protocol does not require direct agent-to-agent communication. The shared backend is canonical state.

## 2. Canonical entities

Minimum v0.1 entities:

- `PROJECT`
- `AGENT`
- `MEMBERSHIP`
- `DIRECTIVE`
- `TASK`
- `TASK_ATTEMPT`
- `REVIEW`
- `EVENT`
- `JOIN_INVITE`
- `PROJECT_LEASE` or coordinator epoch equivalent

All project-scoped entities must include `project_id`, server timestamps, and a protocol version. Mutating operations require an idempotency identity.

## 3. Identity

Authenticated backend identity is authoritative. `AGENT_ID` is mapped to authenticated identity and must not be trusted solely because a client supplies it.

`HOST_ID` identifies a local execution environment but does not grant authority.

## 4. Project discovery and membership

Projects may be `hidden` or `discoverable`.

Join policies:

- `closed`
- `invite_only`
- `approval_required`
- `auto_join`

Discovery, read access, task access, and join authority are separate permissions.

## 5. Authority chain

Every executable task must be traceable to an authorized directive:

`OWNER/HUMAN -> DIRECTIVE -> ROOT_TASK -> TASK/SUBTASK`

A child task may narrow or decompose scope but must not silently broaden the directive objective.

## 6. Roles

Required roles for v0.1:

- `OWNER`
- `COORDINATOR`
- `WORKER`
- `REVIEWER`
- `OBSERVER`

Backend authorization remains authoritative even if a role claims broader rights.

## 7. Task state machine

Allowed normal path:

`READY -> CLAIMED -> RUNNING -> RESULT_READY -> REVIEW -> COMPLETE`

Recovery/error states:

`RUNNING -> STALLED -> RECOVERY -> READY|BLOCKED|HUMAN_REQUIRED`

Additional terminal states may include `CANCELLED`.

Terminal states must not return to an active state. Rework creates a new attempt rather than mutating historical execution.

## 8. Attempts, leases and fencing

Each execution attempt must have a server-authorized identity and lease/fencing value. A stale attempt cannot publish authoritative progress or results after a newer attempt has replaced it.

Coordinator authority should use the same principle through a coordinator lease or monotonically advancing epoch.

## 9. Idempotency

Every mutating logical operation must be idempotent. Retrying the same operation after uncertain network failure must reuse the same idempotency identity and must not duplicate the logical effect.

Examples include project join, task claim, start, heartbeat, result submission, review submission, completion, and recovery.

## 10. Review binding

A review must bind to an exact execution result: task ID + attempt ID + result version or artifact digest. A later result invalidates approval of the earlier result.

## 11. Delegation

Subagents are local delegation mechanisms under the responsibility of a parent agent unless explicitly registered as first-class project agents. Local subagents should not receive project-wide authority by default.

The parent agent validates and publishes their output.

## 12. Recovery

Retries are bounded. Recovery may create a fresh attempt, reassign to a compatible agent, or escalate to `HUMAN_REQUIRED`.

Repeated identical failure must trigger a circuit breaker rather than an infinite retry loop.

## 13. Events and wake signals

Notifications, webhooks and realtime events are advisory wake signals only. An awakened agent must re-read canonical backend state before acting.

The protocol must remain correct if events are duplicated, reordered, delayed, or lost.

## 14. Time

Security- and concurrency-critical timestamps must be server-derived. Agent local clocks are informational only.

## 15. Protocol compatibility

Entities and agents advertise `protocol_version`. An incompatible major version is fail-closed.

## 16. Required invariants

1. No executable task without valid directive ancestry.
2. No client-asserted identity may override authenticated identity.
3. At most one authoritative active lease/attempt for a task.
4. Stale attempts cannot publish authoritative results.
5. At most one authoritative coordinator epoch/lease at a time.
6. Every mutation is idempotent.
7. Duplicate delivery never causes duplicate logical effects.
8. Realtime/event delivery is not canonical state.
9. Critical time comes from the server.
10. Retries are bounded.
11. `HUMAN_REQUIRED` is a hard stop.
12. Reviews bind to an exact result version.
13. Terminal states are terminal.
14. Shared backend data never contains agent secrets.
15. Project isolation is enforced by backend authorization.
16. Subagents cannot silently expand project scope.
17. Scope expansion requires authorized approval.
18. No task may be owned indefinitely without renewable lease semantics.
