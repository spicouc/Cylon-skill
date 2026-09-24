# Cylon Skill v0.1 — Acceptance plan

A happy-path demo is not sufficient. The Supabase PoC passes only when the protocol remains correct under concurrency, duplicate delivery, stale workers, loss of wake events, host failure, and project lifecycle operations.

## Gate 0 — SKILL.md comprehension

Before testing distributed behavior, use a clean agent that has no prior Cylon context. Give it only:

- `SKILL.md`
- configured backend access/profile
- its local authenticated identity/capabilities

Do not give it step-by-step Cylon instructions. In one normal invocation it must infer the correct startup loop: authenticate, re-read canonical state, discover/select or explicitly create a project when authorized, resolve role/permissions, resume owned work before new work, then process only authorized tasks/reviews/recovery. If no project exists, it must not invent one without explicit authorized instruction.

It must also understand from `SKILL.md` alone that project completion/closure is not permission to delete, that archive is the normal reversible retirement path, and that hard deletion requires explicit exact-project authorization.

The happy path should not require reading `PROTOCOL.md`, `RECOVERY.md`, or `SECURITY.md`; those are precision/reference documents for edge cases. If the clean agent needs conversational coaching to perform the normal loop, `SKILL.md` fails this gate.

## Functional path

1. Agent A authenticates without a preconfigured `PROJECT_ID`.
2. Agent A can list discoverable projects or create one when explicitly authorized.
3. Agent B on another host authenticates with a different identity.
4. Agent B discovers the project and joins according to policy.
5. An authorized human/owner directive is created.
6. Coordinator decomposes the directive into valid tasks.
7. Worker atomically claims a task.
8. Worker records start and may use bounded local subagents.
9. Worker submits an exact result/attempt.
10. Reviewer evaluates that exact result.
11. Approval completes the task/project without manual database repair.
12. Owner can archive the completed project and restore it when authorized.
13. An explicit owner/human deletion request for the exact project can delete it atomically/idempotently according to policy.

## Failure/concurrency battery

The PoC must test at least:

1. two agents claim the same task concurrently; exactly one wins
2. same mutation/request delivered twice; one logical effect
3. worker dies immediately after claim
4. worker dies after doing work but before result submission
5. stale worker returns after task reassignment; stale write rejected
6. coordinator disappears
7. two agents race to recover coordinator authority; one authoritative epoch/lease
8. backend temporarily unavailable
9. transport timeout after a successful backend commit; idempotent retry does not duplicate
10. duplicate realtime event
11. missing realtime event; polling/wake recovery still finds canonical work
12. duplicate result submission
13. review submitted against an old result version; rejected/stale
14. invalid credentials
15. replay/reuse of a one-time join token when join invites are implemented
16. unauthorized cross-project read/write attempt
17. task/subagent attempts to broaden directive scope
18. subagent failure with bounded fresh-subagent recovery
19. identical failure repeated until circuit breaker triggers
20. host A killed during active project work
21. host B killed during active project work
22. incompatible protocol major versions
23. prompt injection embedded in task/project content
24. expired lease attempts to heartbeat or submit result
25. project reaches terminal completion with no manual cleanup
26. unauthorized worker/reviewer attempts to create or delete a project; rejected
27. project is completed/closed; no implicit delete occurs
28. delete requested while active task/lease exists; rejected or escalated unless explicit force-delete authority exists
29. duplicate/retried delete request after uncertain transport outcome; one logical deletion and no partial cascade
30. deletion request targets ambiguous/wrong project; fail closed

## Universal-skill proof

After the two-agent battery passes, introduce a third clean agent/framework where practical. Give it only the same `SKILL.md`, backend connection/profile, and local identity. Do not provide Cylon coaching.

Success means it can discover/create/select the proper project when authorized, determine its role, obtain/execute/review authorized work, recover safely from canonical backend state, and manage allowed project lifecycle actions using the skill plus backend profile alone.

## PASS criteria

The v0.1 hypothesis is accepted only when evidence shows:

- Gate 0 SKILL-only cold-start PASS
- two independent agents
- two hosts
- same universal skill
- Supabase canonical backend
- no direct agent-to-agent dependency
- separate agent credentials
- discovery/join
- authorized create/archive/restore/delete project lifecycle
- authorized directive ancestry
- atomic task claim
- exact-result review
- bounded subagent delegation
- idempotent mutations
- lease/fencing stale-worker rejection
- recovery/reassignment
- coordinator recovery
- kill tests
- project isolation
- terminal project completion

Any manual database edit required to rescue the test is a failed recovery test and must be documented rather than hidden.
