---
name: implement-slice
description: Implement a single slice. Used when a story has only one slice, or when a subagent is operating on a single slice within the orchestrator. Writes code, writes tests, runs tests, commits on a sub-branch.
argument-hint: "<slice-id>"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git:*), Bash(jq:*), Bash(yq:*), Bash(.claude/scripts/*)
---

# Implement one slice

Implement slice **$1**. You may be running standalone or as a subagent step.

## Hard rules

1. **Stay in scope.** Only modify paths listed as `read-write` in the slice. The scope-enforce hook blocks violations.
2. **Write tests.** Every slice has a `test_plan.unit` and usually `test_plan.integration`. Run them. Do not commit if they fail.
3. **Do not auto-install new dependencies.** If a slice requires a new package, stop and surface it as a blocker.
4. **Commit on the declared sub-branch only.** Do not push to `main`, `story/*`, or `design/*`.
5. **Return the standard JSON summary.**

## Procedure

### Step 1 — Load context

- `.github/project/PROFILE.md`
- `.github/project/overrides/implement-slice.md`
- `.github/project/guidelines/*`
- Relevant `stacks/*` per slice layer
- `docs/designs/WI-<parent>/slices.md` — find your slice by ID

### Step 2 — Understand the slice

Print (as reasoning, not output) the slice's AC, impact, risk, test plan, file scope. Confirm you understand before writing code.

### Step 3 — Implement

Write code. Keep changes within declared file scope. Follow `guidelines/*` for style, error handling, naming, testing.

### Step 4 — Write tests

- Unit tests first. One test per AC where possible.
- Integration test if the slice crosses a boundary (API, DB, file I/O).
- No vacuous tests (tests that pass without verifying behaviour).

### Step 5 — Run tests

```bash
<test_plan.unit command>
<test_plan.integration command>
```

If any fail, fix. Cap at 3 self-repair loops. If still failing, return with `blockers: ["tests failing: <summary>"]`.

### Step 6 — Commit

```bash
git add <files>
git commit -m "WI-<parent> S<id>: <slice title>"
```

Do not push — the orchestrator controls pushes for parallel safety.

### Step 7 — Return JSON summary

Emit exactly this block (no prose after):

```json
{
  "subagent": "<your subagent name or 'standalone'>",
  "slice": "$1",
  "branch": "<current branch>",
  "commit_sha": "<sha>",
  "tests": { "unit": "passed|failed", "integration": "passed|failed|n/a" },
  "files_touched": ["<paths>"],
  "blockers": [],
  "questions": []
}
```
