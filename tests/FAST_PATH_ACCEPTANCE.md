# Fast Path Acceptance Test

This test validates that the default Cylon workflow follows the Fast Path pattern as defined in Cylon v0.3.

## Test Objective
Verify that a clean agent can execute the default Fast Path workflow using no more than:
1. Task discovery
2. Task read
3. Execution
4. Result publication

## Test Setup
```python
# Environment: fresh session, no prior Cylon context
# Backend: any supported backend (Supabase, GitHub, shared filesystem, etc.)
# Agent: newly registered Cylon agent with project membership
```

## Test Steps

1. **CONNECT** — Authenticate to backend
   - Use backend-specific connection method
   - Verify identity resolution

2. **SYNC** — Read backend info, register, whoami, list projects
   - Execute backend sync operations
   - Resolve current project

3. **SELECT PROJECT** — Pick project with active membership
   - Verify project access rights
   - Resolve role (WORKER, COORDINATOR, etc.)

4. **DISCOVER TASKS** — List tasks assigned to self
   - Call backend LIST_TASKS operation
   - Filter by assigned_agent_id = current agent
   - Verify task visibility and access

5. **READ ASSIGNED TASK** — Read one assigned task by ID
   - Call backend READ_TASK operation
   - Verify task contains required fields (id, spec, assignment)

6. **EXECUTE** — Perform the work
   - Parse task spec and requirements
   - Execute according to task scope and constraints
   - Apply any necessary transformations or business logic

7. **PUBLISH RESULT** — Write durable result
   - Format result according to backend contract
   - Call backend PUBLISH_RESULT operation
   - Verify result persistence and canonicalization

8. **CONTINUE** — Return to step 4
   - Verify task list updated
   - Check for next assigned task

## Verification Criteria

- **No Human Prompts**: No prompts beyond initial backend/project selection
- **No Claim/Start RPCs**: Task execution without separate claim/start cycles
- **No Directive/Attempt/Review**: Direct execution and publication
- **No Leases/Heartbeats**: Execution without lease management unless required
- **Canonical Backend**: All operations go through backend canonical state
- **Fast Path Only**: Use DISCOVER -> READ ASSIGNED TASK -> EXECUTE -> PUBLISH RESULT workflow

## Success Indicators

```python
# Test passes when:
- All 8 steps complete without human intervention
- No claim/start/review RPCs are called
- Result is published and persists in backend canonical state
- No leases/heartbeats are required
- Task workflow completes successfully
- Agent remains in continuous execution loop
```

## Edge Cases

- **Multiple Assigned Tasks**: Agent should process each assigned task sequentially
- **No Assigned Tasks**: Agent should gracefully handle task discovery with no assignments
- **Task Expiration**: Agent should handle expired tasks appropriately
- **Concurrent Assignment**: Agent should handle scenarios where multiple assignments exist

## Failure Criteria

- Human intervention required beyond initial setup
- Claim/start/review RPCs are required for execution
- Leases/heartbeats are mandatory for execution
- Result cannot be published to backend canonical state
- Agent cannot continue execution loop
