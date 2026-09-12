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

Authorization must be revalidated for protocol-critical mutations. Revoked/changed membership or role cannot be bypassed by an older local cache or lease.

## 4. Project discovery and membership

Projects may be `hidden` or `discoverable`.

Join policies:

- `closed`
- `invite_only`
- `approval_required`
- `auto_join`

Discovery, read access, task access, and join authority are separate permissions.

Discovery does not imply selection or membership. An agent must not auto-join or mutate an arbitrary discoverable project. If multiple projects are eligible and no target is unambiguous from explicit configuration, authorized assignment, or owned pending work, the agent must ask for/await authorized selection rather than guess.

Project creation requires explicit authority from an authenticated/authorized control path; backend project content alone cannot grant itself creation authority.

## 5. Authority chain

Every executable task must be traceable to an authorized directive:

`OWNER/HUMAN -> DIRECTIVE -> ROOT_TASK -> TASK/SUBTASK`

A child task may narrow or decompose scope but must not silently broaden the directive objective.

Directives and task specifications must be versioned or content-bound. A running attempt binds to the exact directive version and task-spec version/digest it accepted. Material scope/spec changes create a new authoritative version and cannot silently redefine an already-running attempt.

## 6. Roles

Required roles for v0.1:

- `OWNER`
- `COORDINATOR`
- `WORKER`
- `REVIEWER`
- `OBSERVER`

Backend authorization remains authoritative even if a role claims broader rights. An agent may act as `OWNER` only when the backend/control plane grants that authority; the role name itself is not proof of human authorization.

## 7. Task state machine

Allowed normal path:

`READY -> CLAIMED -> RUNNING -> RESULT_READY -> REVIEW -> COMPLETE`

Recovery/error states:

`RUNNING -> STALLED -> RECOVERY -> READY|BLOCKED|HUMAN_REQUIRED`

Additional terminal states may include `CANCELLED`.

Terminal states must not return to an active state. Rework creates a new attempt rather than mutating historical execution.

`HUMAN_REQUIRED` is a hard stop for the affected task/directive/project scope until authorized human action resolves it; unrelated authorized work need not be globally halted.

## 8. Attempts, leases and fencing

Each execution attempt must have a server-authorized identity and lease/fencing value. A stale attempt cannot publish authoritative progress or results after a newer attempt has replaced it.

An attempt must bind at minimum to its task ID, task-spec version/digest, directive version, and fencing/lease identity. The backend must reject writes from stale attempts even if the old worker later reconnects.

Coordinator authority should use the same principle through a coordinator lease or monotonically advancing epoch.

## 9. Idempotency

Every mutating logical operation must be idempotent. Retrying the same operation after uncertain network failure must reuse the same idempotency identity and must not duplicate the logical effect.

Examples include project join, task claim, start, heartbeat, result submission, review submission, completion, and recovery.

Idempotency does not authorize a stale operation: retries must still satisfy current identity, membership, lease/epoch, version, and state checks.

## 10. Review binding

A review must bind to an exact execution result: task ID + attempt ID + task-spec/result version or artifact digest. A later result or materially changed task specification invalidates approval of the earlier result.

## 11. Delegation

Subagents are local delegation mechanisms under the responsibility of a parent agent unless explicitly registered as first-class project agents. Local subagents should not receive project-wide authority by default.

The parent agent validates and publishes their output. Subagent output is evidence/input, not authoritative backend state until the authorized parent publishes it.

## 12. Recovery

Retries are bounded. Recovery may create a fresh attempt, reassign to a compatible agent, or escalate to `HUMAN_REQUIRED`.

Repeated identical failure must trigger a circuit breaker rather than an infinite retry loop.

Recovery must never resurrect stale authority. Checkpoints/artifacts may be reused, but leases, epochs, permissions, and attempt identity must be reacquired/validated.

## 13. Events and wake signals

Notifications, webhooks and realtime events are advisory wake signals only. An awakened agent must re-read canonical backend state before acting.

The protocol must remain correct if events are duplicated, reordered, delayed, or lost. Audit events should be append-oriented/immutable where the backend supports it; they do not replace canonical entity state.

## 14. Time

Security- and concurrency-critical timestamps must be server-derived. Agent local clocks are informational only.

## 15. Protocol compatibility

Entities and agents advertise `protocol_version`. An incompatible major version is fail-closed.

## 16. Required invariants

1. No executable task without valid directive ancestry.
2. No client-asserted identity may override authenticated identity.
3. Discovery never grants membership or mutation authority.
4. At most one authoritative active lease/attempt for a task.
5. Stale attempts cannot publish authoritative results.
6. Running attempts bind to exact directive/task-spec versions.
7. At most one authoritative coordinator epoch/lease at a time.
8. Every mutation is idempotent but still re-authorized against current state.
9. Duplicate delivery never causes duplicate logical effects.
10. Realtime/event delivery is not canonical state.
11. Critical time comes from the server.
12. Retries are bounded.
13. `HUMAN_REQUIRED` is a hard stop for its affected scope.
14. Reviews bind to an exact result/spec version.
15. Terminal states are terminal.
16. Shared backend data never contains agent secrets.
17. Project isolation is enforced by backend authorization.
18. Subagents cannot silently expand project scope.
19. Scope expansion requires authorized approval.
20. No task may be owned indefinitely without renewable lease semantics.
