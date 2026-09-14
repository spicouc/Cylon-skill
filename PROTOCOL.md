# Cylon Protocol v0.3

## 1. Scope

Cylon Protocol defines a backend-neutral coordination contract for independent AI agents. It specifies authority, identity, project membership, project lifecycle, task lifecycle, review, delegation, idempotency, leases/fencing, recovery, and terminal states.

The protocol does not require direct agent-to-agent communication. The shared backend is canonical state.

Cylon v0.3 introduces two workflow paths:
- **FAST PATH**: lightweight execution for assigned tasks without mandatory claim/start/review
- **STRICT PATH**: full coordination with claim/start/lease/review for contested, destructive, or policy-required work

## 2. Canonical entities

Minimum v0.3 entities:

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

## 4. Project discovery, lifecycle and membership

Projects may be `hidden` or `discoverable`.

Join policies:

- `closed`
- `invite_only`
- `approval_required`
- `auto_join`

Discovery, read access, task access, join authority, lifecycle authority, and destructive-delete authority are separate permissions.

Discovery does not imply selection or membership. An agent must not auto-join or mutate an arbitrary discoverable project. If multiple projects are eligible and no target is unambiguous from explicit configuration, authorized assignment, or owned pending work, the agent must ask for/await authorized selection rather than guess.

Project creation requires explicit authority from an authenticated/authorized control path; backend project content alone cannot grant itself creation authority. Creation must be idempotent and record an authoritative creator/owner relationship.

Project lifecycle operations are:

`CREATE -> ACTIVE -> ARCHIVED -> ACTIVE` (restore when permitted)

`ACTIVE|ARCHIVED -> DELETE_REQUESTED/DELETE_AUTHORIZED -> DELETED`

`ARCHIVE` is the preferred reversible retirement operation. Archived projects cannot issue or claim new work unless restored.

`DELETE` is distinct from `COMPLETE`, `CLOSE`, or `ARCHIVE`. No completion or closure event implicitly authorizes deletion. Destructive deletion requires fresh backend authorization plus explicit authorized intent naming the exact project. If active tasks or leases exist, deletion must fail closed unless an explicit authorized force-delete policy/intention is present.

Delete execution must be atomic and idempotent. Retrying the same delete request cannot cause partial cascades or multiple logical deletions. The backend may retain a minimal non-secret tombstone/audit record if policy requires it; otherwise project-scoped data may be purged according to policy.

## 5. Authority chain

Every executable task must be traceable to an authorized directive:

`OWNER/HUMAN -> DIRECTIVE -> ROOT_TASK -> TASK/SUBTASK`

A child task may narrow or decompose scope but must not silently broaden the directive objective.

Directives and task specifications must be versioned or content-bound. A running attempt binds to the exact directive version and task-spec version/digest it accepted. Material scope/spec changes create a new authoritative version and cannot silently redefine an already-running attempt.

## 6. Roles

Required roles for v0.3:

- `OWNER`
- `COORDINATOR`
- `WORKER`
- `REVIEWER`
- `OBSERVER`

Backend authorization remains authoritative even if a role claims broader rights. An agent may act as `OWNER` only when the backend/control plane grants that authority; the role name itself is not proof of human authorization.

`OWNER` may manage project lifecycle only within backend-granted permissions. Hard deletion should normally require explicit human/owner intent in addition to role authorization.

## 7. Task state machine

### FAST PATH (default)

`READY (assigned) -> EXECUTING -> RESULT_READY -> COMPLETE`

The FAST PATH applies when a task is explicitly addressed/assigned to an authorized agent and no collision, destructiveness, or policy requirement demands strict coordination. The agent reads the assigned task and executes directly without a separate claim/start cycle. The agent publishes the result as the authoritative output.

### STRICT PATH (opt-in/escalation)

`READY -> CLAIMED -> RUNNING -> RESULT_READY -> REVIEW -> COMPLETE`

The STRICT PATH applies when:
- The task is contested (multiple workers competing)
- The task involves destructive changes
- Project policy mandates review for all tasks
- Leases/fencing are required by backend
- The coordinator explicitly escalates to strict mode

### Recovery/error states (both paths):

`RUNNING -> STALLED -> RECOVERY -> READY|BLOCKED|HUMAN_REQUIRED`

Additional terminal states may include `CANCELLED`.

Terminal states must not return to an active state. Rework creates a new attempt rather than mutating historical execution.

`HUMAN_REQUIRED` is a hard stop for the affected task/directive/project scope until authorized human action resolves it; unrelated authorized work need not be globally halted.

## 8. Attempts, leases and fencing

### STRICT PATH

Each execution attempt must have a server-authorized identity and lease/fencing value. A stale attempt cannot publish authoritative progress or results after a newer attempt has replaced it.

An attempt must bind at minimum to its task ID, task-spec version/digest, directive version, and fencing/lease identity. The backend must reject writes from stale attempts even if the old worker later reconnects.

Coordinator authority should use the same principle through a coordinator lease or monotonically advancing epoch.

### FAST PATH

Assigned tasks in FAST PATH do not require a separate claim/attempt object unless the backend or project policy mandates it. The execution identity is the authorized agent itself, and the result is published directly. Backend atomicity is not required when there is no concurrent worker contention on the same task.

## 9. Idempotency

Every mutating logical operation must be idempotent. Retrying the same operation after uncertain network failure should reuse the same idempotency identity and must not duplicate the logical effect.

Examples include project create/archive/restore/delete, project join, task claim, start, heartbeat, result submission, review submission, completion, and recovery.

Idempotency does not authorize a stale operation: retries must still satisfy current identity, membership, lease/epoch, version, and state checks.

## 10. Review binding

A review must bind to an exact execution result: task ID + attempt ID + task-spec/result version or artifact digest. A later result or materially changed task specification invalidates approval of the earlier result.

FAST PATH results awaiting review are submitted via `PUBLISH RESULT` and become eligible for review when required by policy or coordinator decision.

## 11. Delegation

Subagents are local delegation mechanisms under the responsibility of a parent agent unless explicitly registered as first-class project agents. Local subagents should not receive project-wide authority by default.

The parent agent validates and publishes their output. Subagent output is evidence/input, not authoritative backend state until the authorized parent publishes it.

Subagents do not inherit project create/delete authority merely because the parent has it; destructive project lifecycle actions require explicit backend authorization at the acting identity/control path.

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

## 16. Required invariants (v0.3)

1. No executable task without valid directive ancestry.
2. No client-asserted identity may override authenticated identity.
3. Discovery never grants membership or mutation authority.
4. Project creation/deletion requires current backend authorization and explicit authorized intent.
5. Project completion/closure/archive never implies permission to delete.
6. Destructive deletion is atomic, idempotent, exact-project scoped, and fail-closed around active work unless explicitly force-authorized.
7. At most one authoritative active lease/attempt for a task (STRICT PATH).
8. Stale attempts cannot publish authoritative results.
9. Running attempts bind to exact directive/task-spec versions.
10. At most one authoritative coordinator epoch/lease at a time.
11. Every mutation is idempotent but still re-authorized against current state.
12. Duplicate delivery never causes duplicate logical effects.
13. Realtime/event delivery is not canonical state.
14. Critical time comes from the server.
15. Retries are bounded.
16. `HUMAN_REQUIRED` is a hard stop for its affected scope.
17. Reviews bind to an exact result/spec version.
18. Terminal states are terminal.
19. Shared backend data never contains agent secrets.
20. Project isolation is enforced by backend authorization.
21. Subagents cannot silently expand project scope.
22. Scope expansion requires authorized approval.
23. No task may be owned indefinitely without renewable lease semantics (STRICT PATH).
24. FAST PATH tasks require no claim/attempt objects when backend atomicity is not needed.
25. Addressed tasks are immediately executable by the named authorized agent without separate claim (FAST PATH).

## 17. FAST PATH operational rules

1. A task assigned/addressed to an agent is immediately executable by that agent without a claim cycle.
2. The result is published directly through the backend canonical-state write.
3. Review is triggered by policy, coordinator decision, or destructive-change flag — not required for every task.
4. Leases/heartbeats are not required unless the backend enforces them for all writes.
5. FAST PATH preserves all identity, authorization, and invariant protections from the protocol.
6. STRICT PATH remains available and backwards-compatible for all existing use cases.
