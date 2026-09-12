# Cylon Skill

Universal multi-agent coordination skill and protocol for autonomous AI agents.

## Status

Experimental. Current target: **v0.1 Supabase PoC** with two independent agents on two hosts using the same `SKILL.md` and no Cylon-specific runtime.

## Core idea

Cylon Skill defines how an agent discovers projects, joins them, receives authorized work, delegates substantive work to subagents, publishes results, reviews work, and recovers stalled execution through a shared backend.

The backend is the canonical shared state. Agents do not need direct agent-to-agent communication.

## v0.1 goals

- backend: Supabase
- 2 independent agents / 2 hosts
- project discovery and join
- human-authorized directives
- task decomposition and atomic claiming
- `ACK -> STARTED -> RESULT -> REVIEW -> COMPLETE`
- bounded subagent delegation
- leases, fencing, idempotency and retries
- stalled-task recovery and coordinator recovery
- `HUMAN_REQUIRED` as a hard stop
- no secrets stored in shared project data

## Repository layout

```text
SKILL.md
PROTOCOL.md
SECURITY.md
RECOVERY.md
schemas/
backends/supabase/
tests/
```

## Non-goal for v0.1

This repository does **not** copy the existing Cylon runtime or `cylon_autowake.py`. The experiment is specifically to determine how much coordination can live in a universal skill/protocol while relying on native agent capabilities for wake/scheduling/tools.
