# Cylon Protocol v0.3

## Overview

Cylon Protocol v0.3 introduces two workflow paths to support different task coordination needs while maintaining backward compatibility and security.

## Core Protocols

### 1. Identity and Authentication

- Backend-authenticated identity is authoritative
- Agent IDs are mapped to authenticated Supabase Auth users
- No client-supplied AGENT_ID trusted as proof of identity
- Host IDs identify local execution environments but do not grant authority

### 2. Project Membership and Roles

- Roles are project-scoped canonical backend state
- Required roles: OWNER, COORDINATOR, WORKER, REVIEWER, OBSERVER
- Backend authorization always overrides claimed role
- Discovery never grants membership or mutation authority

### 3. Task Lifecycle (Fast Path)

**FAST PATH (default)**:

```
READY (assigned) -> EXECUTING -> RESULT_READY -> COMPLETE
```

Workflow steps:
1. DISCOVER - List tasks assigned to agent
2. READ ASSIGNED TASK - Read assigned task by ID
3. EXECUTE - Execute work according to spec
4. PUBLISH RESULT - Publish result to backend
5. CONTINUE - Return to step 1

**STRICT PATH (opt-in)**:

```
READY -> CLAIMED -> RUNNING -> RESULT_READY -> REVIEW -> COMPLETE
```

Workflow steps:
1. DISCOVER - List available tasks
2. CLAIM - Atomic task claim
3. START - Bind attempt identity
4. EXECUTE - Execute work within scope
5. SUBMIT RESULT - Submit result bound to attempt
6. REVIEW RESULT - Exact-result review
7. COMPLETE - Task completion

### 4. Required Operations

#### Fast Path Operations

1. **LIST_TASKS(p_agent_id, p_project_id, p_assigned_only)**
   - Returns tasks visible to authenticated agent
   - Filter by `assigned_only=true` for assigned tasks only

2. **READ_TASK(p_task_id)**
   - Read single task by ID
   - Must be authorized (task assigned to agent)

3. **PUBLISH_RESULT(p_task_id, p_result, p_result_version, p_attempt_id)**
   - Write durable result for task
   - Result must bind to task spec version

4. **ACKNOWLEDGE(p_task_id, p_agent_id)** - Optional confirmation

#### Strict Path Operations

1. **CLAIM_TASK(p_task_id, p_idempotency_key)** - Atomic claim
2. **START_ATTEMPT(p_task_id, p_attempt_id, p_idempotency_key)** - Bind attempt
3. **SUBMIT_RESULT(p_task_id, p_attempt_id, p_result, p_idempotency_key)** - Submit result
4. **REQUEST_REVIEW(p_task_id, p_attempt_id, p_idempotency_key)** - Request review
5. **REVIEW_RESULT(p_task_id, p_attempt_id, p_result_version, p_result_digest, p_decision, p_notes, p_idempotency_key)** - Exact-result review

### 5. Fast Path Operational Rules

1. **Assigned tasks are immediately executable**: Tasks assigned to an agent can be executed without separate claim/start cycles
2. **No review required for simple tasks**: Review only triggered by policy, coordinator decision, or destructive-change flag
3. **Direct result publication**: Results published directly through backend canonical state write
4. **No lease/heartbeat management**: Required only when backend enforces for all writes
5. **Continuous processing**: Agent continuously processes assigned tasks

### 6. Strict Path Operational Rules

1. **Atomic task claiming**: Tasks must be atomically claimed by single worker
2. **Attempt binding**: Execution binds to exact attempt identity
3. **Lease/heartbeat management**: Required for task ownership
4. **Exact-result review**: Review binds to task ID, attempt ID, spec version, result version, result digest
5. **Stale-worker rejection**: Stale attempts cannot publish authoritative results
6. **Coordinator recovery**: Coordinator authority managed through epochs/leases

### 7. Backend Implementation Examples

#### Supabase

**FAST PATH**:
- Task creation includes `p_assigned_agent_id` field
- `cylon_list_tasks` filters: `WHERE assigned_agent_id = p_agent_id`
- `cylon_publish_result` writes without attempt object
- `cylon_acknowledge` optional confirmation

**STRICT PATH**:
- Full Layer 2 coordination
- Atomic claim via `cylon_claim_task`
- Attempt binding via `cylon_start_attempt`
- Result submission via `cylon_submit_result`
- Review via `cylon_request_review` and `cylon_review_result`

#### GitHub

**FAST PATH**:
- Issues with `assigned_to` field
- Comments used for result publication
- Label `fast-path` indicates workflow
- No claim/start/review RPCs needed

**STRICT PATH**:
- Not applicable (GitHub doesn't support full coordination)

#### Shared Filesystem

**FAST PATH**:
- JSON files in `tasks/` with `assigned_agent` field
- Results written to `results/` directory
- File locking provides atomicity

**STRICT PATH**:
- Not applicable (File locking provides sufficient coordination)

### 8. Acceptance Criteria

#### Fast Path Validation

1. **Task Discovery**: Agent can discover tasks assigned to self
2. **Task Reading**: Agent can read assigned task by ID
3. **Execution**: Agent can execute work according to spec
4. **Result Publication**: Agent can publish result to backend
5. **Continuous Processing**: Agent can continuously process assigned tasks

**Test Requirements:**
- No human intervention beyond initial setup
- No claim/start/review RPCs required
- Results published to backend canonical state
- All identity/authorization invariants preserved

#### Strict Path Validation

1. **Task Claiming**: Agent can atomically claim tasks
2. **Attempt Binding**: Agent can bind attempt identity
3. **Lease Management**: Agent can manage leases/heartbeats
4. **Result Submission**: Agent can submit results bound to attempt
5. **Exact-Result Review**: Agent can review exact results
6. **Stale-Worker Rejection**: Stale attempts are rejected

**Test Requirements:**
- Claim/start/submit/review RPCs used
- Exact-result review binding enforced
- Leases/heartbeats managed
- Both Fast Path and Strict Path can coexist

### 9. Protocol Invariants

1. **Identity and Authorization**: Backend-authenticated identity is authoritative
2. **Discovery**: Discovery never grants membership or mutation authority
3. **Project Lifecycle**: Creation/deletion requires backend authorization and explicit intent
4. **Task Execution**: No silent scope expansion or overwrite/repair of canonical state
5. **Result Binding**: Reviews bind to exact result/spec version
6. **Self-Review**: Self-review is forbidden unless explicitly allowed
7. **Secret Safety**: No agent secrets in shared backend data
8. **Isolation**: Project isolation enforced by backend authorization
9. **Fast/Strict Path**: Both workflow paths available and functional

### 10. Summary

Cylon Protocol v0.3 introduces two complementary workflow paths:

- **FAST PATH**: Lightweight, default workflow for assigned tasks
- **STRICT PATH**: Full coordination, opt-in for contested tasks

Both paths:
- Preserve all security and authorization invariants
- Maintain backward compatibility
- Support different performance and coordination needs
- Can coexist on same backend
- Provide clear decision rules for path selection

The Fast Path enables high-performance execution for simple assigned tasks, while the Strict Path provides full coordination for tasks that require it. Both paths maintain the same security, authorization, and recovery guarantees while offering different trade-offs.
