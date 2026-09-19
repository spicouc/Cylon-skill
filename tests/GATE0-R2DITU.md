# Gate 0 — R2ditu clean-agent comprehension

Status: **PASS WITH FINDING**

## Setup

A Hermes agent (`R2ditu`) loaded the installed `cylon` skill and was prompted only to use the Cylon skill and state what it needed to begin operating. No step-by-step Cylon coaching was provided.

## Observed behavior

The agent correctly reproduced the operating loop:

`CONNECT -> SYNC -> SELECT/CREATE PROJECT -> RESOLVE ROLE -> DO AUTHORIZED WORK -> PUBLISH -> RECOVER OR STOP`

It independently requested/identified the need for:

- backend profile/endpoint
- agent identity (`AGENT_ID`)
- host identity (`HOST_ID`)
- local backend credentials
- local capabilities
- optional project selection/discovery

This demonstrates that the agent can infer the intended high-level operating model directly from `SKILL.md`.

## Finding G0-F1 — backend bootstrap ambiguity

The agent described the endpoint as a possible "Cylon service" and suggested an unrelated existing service as a candidate. This revealed that `SKILL.md` did not state strongly enough that the backend is the selected shared-state provider itself (e.g. Supabase/GitHub/SilverBullet/Notion), not necessarily a separate Cylon runtime/service.

It also asked the human for values that may be locally discoverable (capabilities, host identity, existing project discovery) before attempting self-inspection.

## Correction

`SKILL.md` was updated to require:

- backend-neutral provider interpretation
- local self-inspection before asking the human
- project discovery before asking create-vs-existing when no explicit create intent exists
- stable derivation/registration of `AGENT_ID`/`HOST_ID` when permitted by the backend/platform

## Gate decision

**PASS WITH FINDING**: the central hypothesis is supported — a clean compatible agent can read the skill and understand the Cylon operating loop without conversational coaching. The bootstrap ambiguity was treated as a skill-design defect and corrected before backend implementation.
