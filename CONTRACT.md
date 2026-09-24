# Backend-Neutral Contract - Fast Path (v0.3)

This document defines the minimal backend-neutral contract required for Cylon Fast Path operation.

## Required Operations

### 1. LIST_TASKS
```sql
-- Returns tasks visible to the authenticated agent
-- Parameters:
   - agent_id (required)
   - project_id (optional, filter)
   - assigned_only (optional, default: false)

-- Returns:
   - task_id, status, spec, assigned_agent_id, timestamps
```

### 2. READ_TASK
```sql
-- Reads a single task by ID
-- Parameters:
   - task_id (required, must be authorized)

-- Returns:
   - Complete task object including spec, assignment, metadata
```

### 3. PUBLISH_RESULT
```sql
-- Writes a durable result for a task
-- Parameters:
   - task_id (required)
   - result_data (required, task-spec bound)
   - result_version (required, for idempotency)
   - attempt_id (optional, if using attempt model)

-- Returns:
   - result_id, timestamp, version
```

### 4. ACKNOWLEDGE (Optional)
```sql
-- Optional confirmation that agent has received assigned task
-- Parameters:
   - task_id (required)
   - agent_id (required)

-- Returns:
   - acknowledgment_id, timestamp
```

## Backend Implementation Examples

### Supabase
- Uses existing RPC functions
- Task creation includes `p_assigned_agent_id` field
- `cylon_list_tasks` filters by `assigned_agent_id`
- `cylon_publish_result` writes without attempt object for Fast Path
- `cylon_acknowledge` optional for Fast Path

### GitHub
- Uses Issues as task representation
- `assigned_to` field indicates task assignment
- Comments are used for result publication
- Labels track Fast Path vs Strict Path tasks

### Shared Filesystem
- JSON files in `tasks/` directory represent tasks
- `assigned_agent` field indicates task assignment
- Results written to `results/` directory
- File locking provides atomicity

## Contract Compliance

A backend complies with Fast Path contract when:

1. **LIST_TASKS** returns tasks visible to authenticated agent
2. **READ_TASK** allows reading any visible task
3. **PUBLISH_RESULT** accepts result for any owned task
4. All operations are idempotent and atomic
5. No mandatory claim/start/review RPCs required
6. Assigned tasks are immediately executable
7. Results persist in backend canonical state

## Validation Criteria

### Unit Tests
- `LIST_TASKS` returns correct subset for agent
- `READ_TASK` enforces authorization
- `PUBLISH_RESULT` maintains task-spec binding
- All operations are idempotent

### Integration Tests
- Complete Fast Path workflow end-to-end
- Task discovery and assignment works correctly
- Result publication persists and is retrievable
- No data corruption or race conditions

### Security Tests
- Authorization checks are enforced
- Secret management is not exposed
- Backend credentials are not leaked
- Access control is properly implemented
