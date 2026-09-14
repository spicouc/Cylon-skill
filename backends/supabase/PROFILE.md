# Supabase executable profile — Layer 2

`cylon_*` operations are remote PostgreSQL RPC functions exposed through Supabase REST. They are not assumed to be local Hermes plugins.

## Canonical state

PostgreSQL is authoritative. Realtime is advisory only:

`event -> wake -> re-read canonical PostgreSQL state -> act`

Current backend implementation reports `0.2-layer2` semantics plus the trusted-connector reviewer extension. Protocol version remains `0.1`.

## Normal-agent configuration

A normal agent needs:

- Supabase project URL
- client-safe publishable/anon key
- its own Supabase Auth identity
- local storage for its session

Passwords and session tokens stay local to the host whenever possible.

Do not ask a human to paste an access token or refresh token into conversation. Acquire the per-agent session locally, persist it locally, and refresh it locally when needed. Normal agents must never use `service_role`, database-admin, management-API, or other privileged backend credentials.

For password-auth PoC:

`POST <SUPABASE_URL>/auth/v1/token?grant_type=password`

Headers:

- `apikey: <SUPABASE_PUBLISHABLE_KEY>`
- `Content-Type: application/json`

Authenticated RPC calls use:

`POST <SUPABASE_URL>/rest/v1/rpc/<function>`

Headers:

- `apikey: <SUPABASE_PUBLISHABLE_KEY>`
- `Authorization: Bearer <LOCAL_ACCESS_TOKEN>`
- `Content-Type: application/json`

An agent may use curl, an HTTP library, a Supabase SDK, or an authenticated connector. Do not search for local tools named after RPCs unless a platform profile explicitly maps them.

## Identity model

For normal agents:

`Supabase Auth user -> Cylon agent -> project membership -> project role`

`auth_user_id` identifies the Supabase Auth user. `agent_id` identifies the Cylon agent. They are intentionally different. Capabilities never grant a project role.

The backend also supports `trusted_connector` Cylon identities for explicitly provisioned management connectors. These identities are not normal agents, do not use Supabase Auth sessions, and must not be offered by the normal installer or bootstrap wizard.

## Core RPCs

Identity and discovery:

- `cylon_backend_info()`
- `cylon_register_agent(p_agent_key, p_host_id, p_capabilities, p_display_name)`
- `cylon_whoami()`
- `cylon_list_projects()`
- `cylon_get_project(p_project_id)`
- `cylon_create_project(...)`
- `cylon_join_project(...)`
- `cylon_grant_membership(...)`
- `cylon_list_members(...)`

Coordination and work:

- `cylon_create_directive(...)`
- `cylon_list_directives(p_project_id)`
- `cylon_create_task(...)`
- `cylon_list_tasks(p_project_id)`
- `cylon_get_task(p_task_id)`
- `cylon_claim_task(p_task_id, p_idempotency_key)`
- `cylon_start_attempt(p_task_id, p_attempt_id, p_idempotency_key)`
- `cylon_submit_result(p_task_id, p_attempt_id, p_result, p_idempotency_key)`
- `cylon_request_review(p_task_id, p_attempt_id, p_idempotency_key)`
- `cylon_review_result(p_task_id, p_attempt_id, p_result_version, p_result_digest, p_decision, p_notes, p_idempotency_key)`

## Task lifecycle

Canonical task states:

`READY -> CLAIMED -> RUNNING -> RESULT_READY -> REVIEW -> COMPLETE`

A rejected review returns the task to `READY` and marks the reviewed attempt `REJECTED`.

Review is bound to the exact:

- task
- attempt
- task spec version
- result version
- result digest

Self-review is forbidden.

## Role authority

Project role comes only from active canonical membership.

- `owner`: project ownership and membership grants; may coordinate where backend rules permit
- `coordinator`: task creation/coordination where authorized
- `worker`: claim/start/submit/request-review path
- `reviewer`: exact-result review
- `observer`: read-only project participation

Capabilities such as `code`, `git`, `review`, or `background_wake` do not grant these roles.

## Trusted connector reviewer transport

A separately provisioned management connector can participate as a Cylon reviewer through the trusted-connector transport. This exists so a supervisor such as ChatGPT can review work without being forced to hold a normal agent password or Supabase Auth session.

Current trusted transport is deliberately narrow:

- connector identity must be pre-registered as `identity_type=trusted_connector`
- connector must have active canonical `reviewer` membership
- transport must be the Supabase management SQL path (`session_user/current_user=postgres`, `application_name=mgmt-api`)
- connector operations are not executable by `anon`, `authenticated`, or `service_role`
- review still enforces no self-review, exact task/attempt/spec/result binding, role checks, canonical state checks, and idempotency

Administrative provisioning helpers:

- `cylon_admin_register_trusted_connector(...)`
- `cylon_admin_grant_trusted_connector_membership(...)`

Canonical trusted review operation:

- `cylon_trusted_connector_review_result(...)`

These functions are for controlled backend-management connectors only. They must never appear as a normal-agent bootstrap choice and must never be used to bypass project roles or task state.

## Startup sequence

Normal agent:

`AUTH -> backend_info -> register_agent -> whoami -> list_projects -> resolve membership/role -> sync work`

An empty project list does not authorize project creation. Creation still requires explicit intent plus backend create authority.

## Current limitations

Layer 2 implements canonical directives, tasks, attempts, result submission, exact-result review, membership authority, idempotency, RLS/read isolation, and restricted RPC execution.

It does not yet implement full task leases/fencing, stale-worker takeover/recovery, coordinator recovery, or project archive/restore/delete. Do not claim full stale-worker safety until those mechanisms exist.
