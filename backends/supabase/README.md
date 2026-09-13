# Supabase backend profile — PoC v0

Supabase is the first experimental backend for Cylon Skill. It provides canonical shared state and enforces protocol operations that require authorization or atomicity.

## Building blocks

- Supabase Auth for per-agent identity
- PostgreSQL for canonical state
- RLS for isolation
- PostgreSQL RPC for protocol mutations/reads
- server timestamps for later lease/order semantics
- Realtime only as an advisory wake signal

Concrete HTTP/Auth/RPC mapping is documented in [`PROFILE.md`](./PROFILE.md). The exact deployed Layer 1 migrations are recorded under [`migrations/`](./migrations/).

## Layer 1 — deployed and tested

Current tables:

- `cylon_agents`
- `cylon_projects`
- `cylon_memberships`
- `cylon_idempotency`

Current RPCs:

- `cylon_backend_info`
- `cylon_register_agent`
- `cylon_whoami`
- `cylon_list_projects`
- `cylon_get_project`
- `cylon_create_project`
- `cylon_join_project`

Project creation is fail-closed through backend-side `can_create_projects`. Successful authorized creation creates an active `owner` membership. Create and join use idempotency identities.

A clean Hermes agent on a separate host successfully authenticated, registered, read canonical project state, was denied unauthorized creation, then created exactly one project after an explicit backend authority grant; retrying the same logical create did not duplicate the project.

## Important semantics learned from Layer 1

- `cylon_*` names are remote backend RPCs; they are not assumed to be local agent plugins.
- Auth/session material is obtained and retained locally by the agent host, not pasted through conversation.
- technical capabilities do not imply project roles; role comes from canonical project membership/authorization state.
- Supabase `auth_user_id` and Cylon `agent_id` are distinct identifiers.

## Later layers

The protocol still requires explicit operations for directives, tasks, attempts, claims, leases/fencing, results, exact-result reviews, recovery, and project archive/restore/delete. These semantics are not claimed as implemented merely because they exist in the protocol specification.

Direct unrestricted updates to protocol-critical status fields are not the normal agent interface.

## Realtime rule

`event -> wake -> re-read canonical PostgreSQL state -> act`

Correctness must not depend on realtime messages being delivered once, in order, or at all.

## Credentials

Normal agents use client-safe connection configuration plus a dedicated authenticated identity. Administrative backend credentials are not part of normal agent operation, and credentials/session material are never written into shared Cylon project data.
