# Schemas

This directory will contain machine-readable Cylon Protocol schemas.

For v0.1 the first schema set should cover:

- project
- agent
- membership
- directive
- task
- task attempt
- review
- event
- join invite
- coordinator/project lease

Schema work should follow `PROTOCOL.md`; schemas must not introduce new authority or lifecycle semantics independently.

Planned rule: protocol documents define semantics, schemas validate structure, and backend profiles map those semantics to concrete storage/operations.
