# .github/project/copilot-instructions.md — Project policy

This file holds **project-specific policy** that overrides the global `.github/copilot-instructions.md`.

On conflict, precedence (highest wins):

1. `.github/project/overrides/<skill-name>.md`
2. `.github/project/copilot-instructions.md` (this file)
3. `.github/project/guidelines/*.md`
4. `.github/copilot-instructions.md` (global)

Everything below this line is project-owned. Edit freely.

---

## Examples (delete or adapt)

- All public API endpoints require OpenAPI documentation.
- All database changes go through migrations; never hand-modify schema.
- Use `DomainException` for domain errors; never throw raw `Exception`.
- Frontend data fetching goes through the `useQuery` wrapper at `@/lib/query`.

## Non-obvious landmines

> Document non-obvious things future-Claude and future-humans will get wrong. The best test: if you had to explain to a new hire over coffee, write it here.

-
