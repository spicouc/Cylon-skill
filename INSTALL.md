# Cylon installation wizard

This document is for an AI/agent that does not yet have Cylon installed.

The intended human experience is simple:

`Install Cylon from this repository and follow INSTALL.md.`

The agent should perform the rest as a guided wizard.

## 1. Installation goals

The installer should:

1. detect the agent/framework and its skill mechanism;
2. detect the correct local installation path;
3. inspect whether Cylon is already installed;
4. install or update the Cylon skill and backend profiles without silent overwrite;
5. preserve local configuration and credentials;
6. hand control to `SKILL.md` after installation;
7. let `SKILL.md` run backend/auth/project bootstrap.

Do not require the human to understand skill directories, RPCs, JWTs, backend internals, or Cylon protocol files.

## 2. Human interaction

When a bounded decision is required, present a numbered menu and ask one decision at a time.

Example:

```text
CYLON SETUP

Cylon is not installed on this agent.

1. Install Cylon
2. Show what will be installed
3. Cancel
```

Do not ask open-ended questions when a short bounded menu is possible.

## 3. Installation contents

Install at minimum:

- `SKILL.md`
- backend profiles under `backends/`

Keep these available for deeper reference:

- `PROTOCOL.md`
- `SECURITY.md`
- `RECOVERY.md`

The framework-specific installer may copy, symlink, vendor, or register these files according to the platform's normal skill mechanism.

## 4. Safe overwrite/update rule

Never blindly overwrite an existing Cylon installation.

Before replacing an installed file:

1. read the current local version;
2. determine whether it matches the previously installed version/hash when known;
3. compare with the incoming version;
4. preserve locally modified files before replacement;
5. use atomic replace where supported.

If an installed file was modified locally, present a menu such as:

```text
A local modification was detected in SKILL.md.

1. Keep the local version
2. Install the new version and save a backup
3. Compare versions
4. Cancel
```

Never silently discard local changes.

## 5. Repair

A request such as `Repair Cylon` should verify the installation and repair only Cylon installation files that are missing/corrupt.

Repair must not silently alter:

- backend project state;
- Cylon memberships/roles;
- agent identities;
- project/task data;
- credentials;
- unrelated local files.

If backend protocol state appears inconsistent, use the recovery semantics in `SKILL.md`/`RECOVERY.md`; do not use arbitrary database repair as an installation action.

## 6. Credential handling during setup

Prefer, in order:

`local secret manager > protected local config > environment variable > hidden local terminal/input > temporary conversational fallback`

The conversational fallback is allowed only when no safer local secret channel is available and the human explicitly selects it.

When needed, present:

```text
I cannot use a safer local secret channel on this host.

How should authentication continue?

1. Configure the credential manually outside this chat
2. Provide a temporary password here as a last-resort fallback
3. Cancel

If you choose 2, use a temporary password that is not reused elsewhere. It must be rotated after authentication, and the message containing it should be deleted when practical.
```

If a temporary password is supplied in conversation:

- do not echo or quote it;
- do not log or persist it in Cylon files/backend state;
- use it only for immediate authentication/bootstrap;
- never accept service-role/admin/master credentials this way;
- never request JWT/access/refresh tokens this way;
- after successful authentication, surface `ROTATE_PASSWORD_REQUIRED` until the password is changed.

### Supabase hard rule

For normal Cylon agent installation and operation, Supabase uses:

- Supabase project URL;
- a client-safe publishable/anon key;
- the agent's own Supabase Auth identity/session.

`service_role`, secret/admin/master keys are FORBIDDEN for normal Cylon agents.

The installer MUST NOT present `service_role` or another privileged backend key as a selectable setup option, fallback, convenience path, repair path, or alternative to an anon/publishable key.

A valid Supabase setup menu is therefore similar to:

```text
Supabase selected.

1. Use detected project URL + publishable/anon key
2. Configure project URL + publishable/anon key locally
3. Choose another backend
4. Cancel
```

A menu containing an option such as `Provide service_role key` is a Cylon installation failure and must not be followed.

If only a privileged Supabase key is available, refuse to use it and ask for a client-safe publishable/anon key or let the human choose another backend.

## 7. First-run handoff

After installation, load `SKILL.md` and continue with its bootstrap rules.

Expected flow:

`INSTALL -> LOAD SKILL -> DISCOVER BACKEND -> AUTH -> BACKEND INFO -> REGISTER/WHOAMI -> PROJECT DISCOVERY -> ROLE RESOLUTION`

The first clean-agent acceptance run should stop at role resolution unless explicitly authorized to continue.

## 8. Ready state

A successful installer should end with a clear state such as:

```text
CYLON READY

Skill: installed
Backend: configured
Identity: authenticated
Agent: registered
Project: resolved or waiting for selection/membership
Role: resolved or NONE / UNRESOLVED
```

If configuration remains incomplete, present the next valid numbered choice rather than technical implementation details.
