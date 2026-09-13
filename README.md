# Cylon Skill

Universal multi-agent coordination skill and protocol for autonomous AI agents.

## Status

Experimental. Current target: **v0.1 Supabase PoC** with two independent agents on two hosts using the same `SKILL.md` and no Cylon-specific runtime.

## Product rule

`SKILL.md` is the primary installed artifact. A compatible agent should be able to read it quickly and know how to connect, discover/select a project, resolve its role, obtain authorized work, delegate to subagents, publish durable results, review work, recover stalls, and stop safely when human authority is required.

The remaining documents exist to make that compact skill precise and testable; they are not intended to be re-read on every invocation.

## Core idea

The backend is canonical shared state. Agents do not need direct agent-to-agent communication. Native platform capabilities provide tools, wake/scheduling, and subagents; Cylon Skill provides the common operating protocol.

## v0.1 goals

- backend: Supabase
- 2 independent agents / 2 hosts
- one shared `SKILL.md`
- project discovery and join
- explicit human-authorized project/directive creation
- task decomposition and atomic claiming
- `ACK -> STARTED -> RESULT -> REVIEW -> COMPLETE`
- bounded subagent delegation
- leases, fencing, idempotency and retries
- stalled-task and coordinator recovery
- `HUMAN_REQUIRED` as a hard stop
- no secrets stored in shared project data

## Repository layout

```text
SKILL.md                    # what the agent normally reads
PROTOCOL.md                 # formal contract/invariants
SECURITY.md                 # trust and secret boundaries
RECOVERY.md                 # recovery details
schemas/                    # machine-readable contract
backends/supabase/          # backend-specific mapping
 tests/                     # acceptance and failure tests
```

## Non-goal for v0.1

This repository does **not** copy the existing Cylon runtime or `cylon_autowake.py`. The experiment is specifically to determine whether the coordination intelligence can live primarily in a universal skill/protocol while relying on native agent capabilities for wake/scheduling/tools.
