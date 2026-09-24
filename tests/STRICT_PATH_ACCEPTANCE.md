# Strict Path Acceptance Test

This test validates that the optional Strict Path workflow works correctly for contested, destructive, or policy-required tasks.

## Test Objective
Verify that when a task requires strict coordination (contested work, destructive changes, required review, leases/fencing), the Strict Path workflow is used:

1. DISCOVER -> CLAIM -> START -> EXECUTE -> SUBMIT -> REVIEW -> COMPLETE

## Test Setup
```python
# Environment: fresh session, no prior Cylon context
# Backend: any backend that supports leases/fencing (Supabase with Layer 2)
# Agent: newly registered Cylon agent with coordinator/owner authority
```

## Test Steps

1. **CONNECT** — Authenticate to backend
2. **SYNC** — Read backend info, register, whoami, list projects
3. **SELECT PROJECT** — Pick project with coordinator/owner role
4. **DISCOVER TASKS** — List tasks available for claiming
5. **CLAIM TASK** — Atomic claim of a READY task
6. **START ATTEMPT** — Bind attempt identity and spec version
7. **EXECUTE** — Perform the work within task scope
8. **SUBMIT RESULT** — Submit result bound to exact attempt
9. **REVIEW RESULT** — Approve/reject exact submitted result
10. **COMPLETE** — Task completion

## Verification Criteria

- **Claim Required**: Task claiming is mandatory
- **Leases/Fencing**: Leases/heartbeats are used for task ownership
- **Attempt Binding**: Execution binds to exact attempt identity
- **Review Required**: Review is mandatory for task completion
- **Atomic Transitions**: All state transitions are atomic
- **Fencing**: Stale attempts are rejected
- **Result Binding**: Results are bound to exact attempt/task-spec

## Success Indicators

- All 10 steps complete successfully
- Claim/start/submit/review RPCs are used
- Leases/heartbeats are managed
- Attempt fencing is enforced
- Results are reviewed and approved

## Edge Cases

- **Multiple Claimers**: Only one worker can claim a task
- **Lease Expiration**: Worker must renew lease to continue
- **Concurrent Modifications**: Strict concurrency control prevents conflicts
- **Result Rejection**: Rejected results require rework
