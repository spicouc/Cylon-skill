# Supabase executable profile — Layer 1

`cylon_*` operations are remote PostgreSQL RPC functions exposed through Supabase REST. They are not assumed to be local Hermes plugins.

## Local configuration

A normal agent needs the Supabase project URL, a client-safe publishable key, and its own Supabase Auth identity. Passwords and session tokens stay local to the host.

Do not ask a human to paste an access token or refresh token into conversation. Acquire the per-agent session locally, persist it locally, and refresh it locally when needed. Normal agents must not use backend administrative credentials.

## Transport

Authenticate with the configured Supabase Auth flow. For the password-auth PoC:

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

An agent may use curl, an HTTP library, a Supabase SDK, or an authenticated connector. Do not search for local tools named after RPCs unless the platform profile explicitly maps them.

## Layer 1 RPCs

`cylon_backend_info()` — implementation/protocol metadata and operation discovery.

`cylon_register_agent(p_agent_key, p_host_id, p_capabilities, p_display_name)` — registers the authenticated identity. Supabase Auth is authoritative; caller-supplied identity is not proof.

`cylon_whoami()` — returns the current registry identity. `auth_user_id` is the Supabase Auth UUID; `agent_id` is the Cylon agent UUID. They are intentionally different.

`cylon_list_projects()` — lists visible projects plus membership/role when applicable. Capabilities never imply project role. No membership means role `NONE / UNRESOLVED`.

`cylon_get_project(p_project_id)` — returns project metadata when visible.

`cylon_create_project(p_name, p_slug, p_visibility, p_join_policy, p_idempotency_key)` — requires backend-side `can_create_projects = true`. Visibility is `hidden` or `discoverable`; join policy is `closed`, `invite_only`, `approval_required`, or `auto_join`. Successful creation creates an active `owner` membership. Repeating the same logical request with the same idempotency key must not create a duplicate.

`cylon_join_project(p_project_id, p_idempotency_key)` — active discoverable projects only. `closed` and `invite_only` reject direct join; `auto_join` creates active worker membership; `approval_required` creates pending worker membership.

## Startup sequence

`AUTH -> cylon_backend_info -> cylon_register_agent -> cylon_whoami -> cylon_list_projects -> resolve membership/role`

An empty project list does not authorize project creation. Creation still requires explicit intent plus backend create authority.

## Scope

Layer 1 implements Auth identity, agent registration, whoami, project discovery/info, backend-controlled create/join, owner membership on create, idempotency, RLS/read isolation, and restricted RPC execution.

Layer 1 does not yet implement directives, tasks/attempts, task leases/fencing, result submission, exact-result review, coordinator recovery, or project archive/restore/delete.

Realtime is advisory only: `event -> wake -> re-read canonical PostgreSQL state -> act`.
