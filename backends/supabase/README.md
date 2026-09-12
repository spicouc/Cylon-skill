# Supabase backend profile — PoC v0

Supabase is the first experimental backend for Cylon Skill.

## Intended responsibilities

Supabase should provide canonical shared state and enforce the parts of the protocol that require atomicity or authorization. Agents should not implement concurrency control only in prompts.

Expected building blocks:

- Supabase Auth for identity
- PostgreSQL tables for canonical entities
- Row Level Security for project isolation and role-aware access
- PostgreSQL functions/RPC for atomic protocol operations
- server timestamps for leases and ordering
- Realtime only as an optional wake signal

## Initial tables

The first PoC should start with:

- `projects`
- `agents`
- `memberships`
- `directives`
- `tasks`
- `task_attempts`
- `reviews`
- `events`

Additional tables such as join invites or coordinator leases may be added when their acceptance test is introduced.

## Operations that must be atomic

At minimum:

- join/approve membership where required
- claim task
- start/renew task lease
- submit result for current attempt
- submit review for exact result
- complete task
- recover/reassign expired work
- coordinator takeover/epoch advance when implemented

Direct unrestricted updates to protocol-critical status fields should not be the normal agent interface.

## Realtime rule

Realtime notifications are advisory only:

`event -> wake -> re-read canonical PostgreSQL state -> act`

The system must remain correct if realtime messages are lost, duplicated, reordered, or delayed.

## Credentials

Normal agents must never receive the Supabase service-role key. Agent credentials remain local to their host/platform and are not written into Cylon project data.

## Next implementation step

Create a reviewed `schema.sql` only after the v0.1 entity/state/permission contract is frozen enough to test. Every protocol-critical SQL function should have concurrency and negative tests before the PoC is declared PASS.
