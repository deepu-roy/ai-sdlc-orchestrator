---
name: implement-story
description: Orchestrate multi-slice story implementation. Delegates to contract-dev, backend-dev, and frontend-dev subagents with enforced file-boundary scopes, merges their work, runs tests, opens one feature PR. Use when invoked with a parent work item ID after its design PR has merged.
argument-hint: "<parent-work-item-id>"
allowed-tools: Task, Read, Write, Glob, Grep, Bash(git:*), Bash(gh:*), Bash(az:*), Bash(curl:*), Bash(jq:*), Bash(yq:*), Bash(.claude/scripts/*)
---

# Implement story (orchestrator)

You orchestrate the implementation of story **$1**. You do not write feature code yourself.

## Hard rules

1. **You delegate. You do not write feature code.** If a subagent fails, relaunch with a sharper prompt. Do not hand-patch.
2. **Contract first, alone.** If any slice has `layer: contract`, spawn `contract-dev` and wait for it to complete before spawning anything else.
3. **File boundaries are enforced by a hook.** A merge conflict at Phase 4 means a subagent violated its scope — that's a prompt bug, not a diff to paper over. Abort and flag.
4. **Aborts are loud.** On any aborted run, leave the story branch intact, comment on the parent work item with the exact failure, and return a non-zero exit.
5. **No merges to main.** Only the feature PR is opened; humans merge.

## Procedure

### Phase 1 — Load context

1. Read `.claude/project/PROFILE.md`, `CLAUDE.md`, `overrides/implement-slice.md` (applies to orchestrator too), `guidelines/*`, relevant `stacks/*`.
2. Read `docs/designs/WI-$1/slices.md`.
3. Validate the slice YAML parses cleanly. If not, abort: write the parse error to the parent work item.

### Phase 2 — Group slices

```
contract_slices  = slices where layer == "contract"
backend_slices   = slices where layer == "backend"
frontend_slices  = slices where layer == "frontend"
infra_slices     = slices where layer == "infra"    # refuse these — flag for human
```

If `infra_slices` is non-empty, **do not proceed**. Comment on the parent work item: "Infra slices present; human implementation required." Return.

### Phase 3 — Contract first (if applicable)

If `contract_slices` is non-empty:

1. Check out a branch: `git checkout -b story/WI-$1/contract`.
2. Spawn via Task tool:
   - Subagent: `contract-dev`
   - Prompt: "Implement contract slices for WI-$1. Slice IDs: <list>. Branch: story/WI-$1/contract. Return the standard JSON summary when done."
3. Wait for completion. Parse the subagent's return JSON.
4. If `questions` or `blockers` is non-empty:
   - Open a draft PR on that branch surfacing the questions.
   - Comment on parent work item.
   - Return. **Do not proceed to Phase 4.**
5. Otherwise, merge `story/WI-$1/contract` into a new base branch `story/WI-$1`:
   ```bash
   git checkout -b story/WI-$1
   git merge --no-ff story/WI-$1/contract
   git push --set-upstream origin story/WI-$1
   ```

If `contract_slices` is empty, create `story/WI-$1` from `main`:

```bash
git checkout main && git pull && git checkout -b story/WI-$1
git push --set-upstream origin story/WI-$1
```

### Phase 4 — Parallel backend + frontend

Spawn in parallel using the Task tool (one call per subagent, issued in the same response):

**Subagent 1:**
- Name: `backend-dev`
- Prompt: "Implement backend slices for WI-$1. Slice IDs: <list>. Base branch: story/WI-$1. Your sub-branch: story/WI-$1/backend. Return the standard JSON summary."

**Subagent 2:**
- Name: `frontend-dev`
- Prompt: "Implement frontend slices for WI-$1. Slice IDs: <list>. Base branch: story/WI-$1. Your sub-branch: story/WI-$1/frontend. Return the standard JSON summary."

Wait for both. Collect both JSON summaries.

If either returns `blockers` or `questions`, do not merge yet — see Phase 5b.

### Phase 5 — Merge sub-branches into story branch

```bash
git checkout story/WI-$1
git merge --no-ff story/WI-$1/backend
git merge --no-ff story/WI-$1/frontend
```

#### 5a. Success path

If both merges are clean:

1. Run full test suite: `gates.pre_merge` command from PROFILE.md.
2. Run compile check for each layer that was implemented:
   - `gates.compile.frontend` if frontend slices were present
   - `gates.compile.backend` if backend slices were present
3. Run startup check for the full integrated app:
   - Start backend first, wait `startup_wait_seconds`
   - Start frontend, wait `startup_wait_seconds`
   - Hit both healthchecks
   - Kill both processes

If all pass → proceed to Phase 6.

If compile fails → attempt 1 self-repair loop, then surface as blocker.
If startup fails → do not self-repair. Open a draft PR with the
startup error output attached. Post to Slack:
`"WI-$1 startup check failed — human pairing needed"`

#### 5b. Conflict path

If either merge produces conflicts, or a subagent returned blockers/questions:

- Do not auto-resolve conflicts.
- Push all sub-branches.
- Open a DRAFT PR from `story/WI-$1` to `main` with a description that:
  - Lists each subagent's JSON summary verbatim.
  - Lists each conflict with file paths.
  - Notes "Scope violation detected" if a conflict exists between `backend-dev` and `frontend-dev` sub-branches (they should have disjoint files).
- Comment on parent work item.
- Return. Do not proceed to Phase 6.

### Phase 6 — Open feature PR

```bash
az repos pr create \
  --source-branch story/WI-$1 \
  --target-branch main \
  --title "WI-$1: <title>" \
  --description "$(cat <<EOF
## Implementation of WI-$1

### Subagent summaries
<contract-dev summary>
<backend-dev summary>
<frontend-dev summary>

### Test results
Unit: passed | failed — <summary>
Integration: passed | failed — <summary>

### Slices implemented
<list of slice IDs>

### Review checklist
- [ ] Code correctness
- [ ] Security subagent comments addressed
- [ ] Tech-debt subagent comments triaged

Refs WI-$1
EOF
)" \
  --work-items $1
```

### Phase 7 — Update ADO + Slack

For each slice's child work item:

```bash
.claude/scripts/ado-wi-update.sh <slice-wi-id> --state "Resolved" \
  --discussion "Implemented in PR <feature-pr-url>"
```

```bash
.claude/scripts/slack-notify.sh "Feature PR open for WI-$1 — <PR URL>"
```

### Phase 8 — Handoff

```
=== STORY IMPLEMENTATION COMPLETE ===
Work item: WI-$1
Contract branch: <yes | no>
Parallel subagents: backend-dev, frontend-dev
Feature PR: <URL>
Tests: unit <status>, integration <status>
Blockers surfaced: <count>
Aborted: <no | reason>

Next step: pr-review pipeline runs on the feature PR. Humans approve and merge.
```
