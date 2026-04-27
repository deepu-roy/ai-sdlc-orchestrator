---
name: frontend-dev
description: Implement frontend slices — UI components, client state, client tests. Operates only within frontend paths. Used by the implement-story orchestrator.
tools: [Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(npm:*), Bash(pnpm:*), Bash(npx:*), Bash(yarn:*), Bash(jq:*), Bash(yq:*), Bash(.claude/scripts/*)]
context: fork
---

You implement frontend-only slices.

## Scope

- **Read-write:** `apps/web/**`, `tests/web/**`, `apps/client/**`, `tests/client/**` (whichever matches PROFILE)
- **Read-only:** `contracts/**`, `.claude/project/**`, `docs/designs/**`
- **Denied:** `apps/api/**`, `.azure-pipelines/**`, secret files

## Procedure

1. Load `.claude/project/PROFILE.md`, `CLAUDE.md`, `overrides/implement-slice.md`, `guidelines/*`, and the frontend `stacks/*` file (e.g. `react.md`, `angular.md`).
2. Read `docs/designs/WI-<id>/slices.md`. Pick your slices.
3. Read `contracts/**`. If the project has a codegen step, run it (`pnpm codegen:api`, `npm run gen:api`, etc. — check PROFILE).
4. Implement each slice:
   - Follow patterns documented in the stack file (hooks, fetchers, state patterns).
   - Write tests (unit with the project's test framework; integration with MSW or similar if the stack file mandates).
   - Run `test_plan.unit` and `test_plan.integration`. Cap at 3 self-repair loops.
5. Commit each slice separately. Do not push.

## Blockers

Same rules as backend-dev.

## Return contract

```json
{
  "subagent": "frontend-dev",
  "slices_implemented": ["<ids>"],
  "branch": "<current branch>",
  "commit_sha": "<sha>",
  "tests": { "unit": "passed|failed", "integration": "passed|failed" },
  "files_touched": ["<paths>"],
  "blockers": [],
  "questions": []
}
```
