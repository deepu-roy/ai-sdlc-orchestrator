# AI-SDLC Orchestrator

AI-assisted SDLC pipeline for Claude Code and GitHub Copilot — from tagged work item to merged PR, with human gates at every decision point.

## What it does

A PM tags an ADO work item `ai:ready`. The pipeline generates a design PR (functional spec, technical spec, slice plan). A human reviews and merges it. The pipeline then implements every slice in parallel, opens a feature PR, runs three parallel review subagents (code quality, security, tech debt), and waits for a human to merge.

Both Claude Code (Azure Pipelines) and GitHub Copilot (GitHub Actions) execute the same workflow using identical shared skills and agents. Switching tools means changing one field in `PROFILE.md`.

## How it works

```
ADO work item
  └── tagged ai:ready
        │
        ▼
  ┌─────────────────────────────────────────┐
  │           AI pipeline                   │
  │                                         │
  │  shared/skills/requirements-analysis    │
  │  shared/skills/technical-slicing        │
  │         │                               │
  │         ▼                               │
  │    design PR  ◄── human reviews & merges│
  │         │                               │
  │         ▼                               │
  │  shared/skills/implement-story          │
  │    ├── contract-dev (alone, first)      │
  │    ├── backend-dev  ─┐                  │
  │    └── frontend-dev ─┘ (parallel)       │
  │         │                               │
  │         ▼                               │
  │    feature PR ◄── human reviews & merges│
  │         │                               │
  │         ▼                               │
  │  shared/skills/pr-review                │
  │    ├── code-reviewer                    │
  │    ├── security-auditor  (parallel)     │
  │    └── tech-debt-auditor                │
  └─────────────────────────────────────────┘
        │
        ▼
  work item closed, trace archived
```

Both Claude Code and Copilot read the same `shared/` tree — skills, agents, scripts, and project config.

## Prerequisites

| What | Claude Code path | Copilot path |
|------|-----------------|--------------|
| AI license | Anthropic API key (`ANTHROPIC_API_KEY`) | GitHub Copilot license with agent mode |
| ADO project | ADO project + PAT (Work Items RW, Code RW, Build RW) | Same |
| Notification webhook | Slack / Teams webhook URL | Same |
| `az` CLI | `az boards` extension installed | Same |
| `gh` CLI | Required for `create-pr.sh` when `repo_host: github` | Required |
| `jq` + `yq` | Both in PATH | Same |

CI pipelines run on `ubuntu-latest` — no host requirements there. The prerequisites above apply to **local development** and to the pipeline agent image if you use self-hosted runners.

## Quick setup

### Step 1 — Copy the starter into your repo

```bash
# From the root of your target repository:
cp -r /path/to/ai-sdlc-orchestrator/shared        ./shared
cp -r /path/to/ai-sdlc-orchestrator/.claude        ./.claude
cp -r /path/to/ai-sdlc-orchestrator/.github        ./.github
cp -r /path/to/ai-sdlc-orchestrator/.azure-pipelines ./.azure-pipelines
```

### Step 2 — Run bootstrap (works with either tool)

**Claude Code:**
```bash
claude -p "/bootstrap-project"
```

**Copilot:**
Open Copilot chat and type:
```
@workspace /bootstrap-project
```

Bootstrap scans your repo, detects the stack, populates `shared/project/stacks/`, and writes `shared/project/PROFILE.draft.md`.

### Step 3 — Fill in `PROFILE.draft.md`

```bash
$EDITOR shared/project/PROFILE.draft.md
```

Fix every `[NEEDS HUMAN INPUT]` entry. The most important block is the `orchestration` section — see [Filling in PROFILE.md](#filling-in-profilemd) below.

### Step 4 — Activate the profile

```bash
mv shared/project/PROFILE.draft.md shared/project/PROFILE.md
```

### Step 5 — Wire up pipelines and secrets

See [Pipeline setup](#pipeline-setup) below.

---

## Filling in PROFILE.md

The `orchestration` block tells every skill which tools to use at runtime. `notify.sh` reads `notifications.type`; `create-pr.sh` reads `repo_host`.

```yaml
orchestration:
  pipeline_tool: github-actions   # github-actions | azure-pipelines
  repo_host: github               # github | azure-repos

  work_items:
    source: ado                   # only ado supported today
    org_url: https://dev.azure.com/myorg
    project: MyProject            # ADO project name (case-sensitive)

  notifications:
    type: slack                   # slack | teams | webhook
    webhook_url: https://hooks.slack.com/services/T.../B.../...
    channel: "#engineering"       # slack: channel name; teams: ignored
```

Everything else in PROFILE.md (repo name, stack, guidelines) is populated by bootstrap. You only need to hand-edit the orchestration block and the `[NEEDS HUMAN INPUT]` markers.

---

## Pipeline setup

### Azure Pipelines

**Secrets — create a variable group named `ai-sdlc-secrets`** (Project Settings → Pipelines → Library):

| Variable | Type | Value |
|----------|------|-------|
| `ANTHROPIC_API_KEY` | secret | Your Anthropic API key |
| `ADO_PAT` | secret | PAT with Work Items RW, Code RW, Build RW |
| `SLACK_WEBHOOK_URL` | secret | Slack (or Teams) incoming webhook URL |

**Create four pipelines**, each pointing at its YAML file:

```
design-gen        → .azure-pipelines/design-gen.yml
implement-story   → .azure-pipelines/implement-story.yml
pr-review         → .azure-pipelines/pr-review.yml
post-merge        → .azure-pipelines/post-merge.yml
```

**Wire the ADO service hook** (Project Settings → Service Hooks → New):

- Type: `Work item updated`
- Filter: `Tags` contains `ai:ready`
- Action: Trigger pipeline `design-gen`, pass `workItemId` from the payload

**Branch policies** on `main` and `design/**`:

- Require 1 human reviewer
- Require the PR build to pass
- Prevent direct pushes

---

### GitHub Actions

**Secrets — add to repo or org secrets** (Settings → Secrets and variables → Actions):

| Secret | Value |
|--------|-------|
| `ANTHROPIC_API_KEY` | Your Anthropic API key |
| `ADO_PAT` | PAT with Work Items RW, Code RW |
| `GH_TOKEN` | GitHub token with repo + PR write scope |
| `SLACK_WEBHOOK_URL` | Slack (or Teams) incoming webhook URL |

**Workflows are already in `.github/workflows/`:**

```
design-gen.yml        — work item tag → design PR
ado-poller.yml        — polls ADO every 5 min for new ai:ready items
implement-story.yml   — design merge → feature PR
pr-review.yml         — feature PR → 3 parallel reviewers
post-merge.yml        — cleanup on merge
```

`ado-poller.yml` replaces the ADO service hook: it polls ADO on a cron schedule and triggers `design-gen` when it finds newly tagged work items. If you prefer a push-based trigger, replace it with an ADO service hook that calls the `workflow_dispatch` endpoint.

**Branch protection rules** on `main` and `design/**`:

- Require 1 approving review
- Require status checks to pass
- Restrict pushes to main

---

## Windows: getting hooks working

Hooks in `.claude/hooks/` and `.github/hooks/` are bash scripts. Claude Code and Copilot execute them on the **local machine**. On Windows, bash isn't native — pick one of the options below.

### Option A: WSL2 (recommended)

Run Claude Code inside WSL2. All hooks execute in a real Linux environment; nothing else changes.

```powershell
# Install WSL2 if you haven't already
wsl --install

# Open a WSL2 terminal, then install Claude Code inside it
npm install -g @anthropic-ai/claude-code

# Clone your repo inside WSL2 (not under /mnt/c — use the Linux filesystem)
cd ~
git clone https://github.com/your-org/your-repo
cd your-repo
claude
```

### Option B: Git Bash

Git Bash ships bash 5.x and handles most POSIX scripts without changes.

1. Install [Git for Windows](https://git-scm.com/download/win) — ensure "Git Bash" is included.
2. Configure Claude Code to use Git Bash as its shell. In `.claude/settings.json`:

```json
{
  "shell": "C:\\Program Files\\Git\\bin\\bash.exe"
}
```

3. Restart Claude Code. Hooks will now execute via Git Bash.

**Caveat:** Windows paths under `/mnt/` don't exist in Git Bash. If any script uses `$(pwd)` in a path passed to a Windows tool, adjust the path handling in that script.

### Option C: Native PowerShell

For teams that cannot use WSL2 or Git Bash, you can replace the bash hook scripts with `.ps1` equivalents and update `settings.json` to call PowerShell.

1. For each `.sh` file in `.claude/hooks/`, create a matching `.ps1` that replicates its logic.

2. Update `.claude/settings.json` to point at the `.ps1` files:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File .claude/hooks/block-sensitive-files.ps1" },
          { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File .claude/hooks/scope-enforce.ps1" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File .claude/hooks/format-after-edit.ps1" },
          { "type": "command", "command": "powershell -ExecutionPolicy Bypass -File .claude/hooks/trace-decisions.ps1" }
        ]
      }
    ]
  }
}
```

3. CI pipelines are unaffected — they run on `ubuntu-latest`.

---

## Normal workflow

1. PM creates a work item in ADO, writes a clear description, tags it `ai:ready`.
2. The `design-gen` pipeline fires within minutes. It generates `docs/designs/WI-<id>/functional.md`, `technical.md`, and `slices.md`, creates child Task work items, and opens a design PR.
3. Tech lead reviews the design PR. Edits slice YAML if the split is wrong. Merges when satisfied.
4. `implement-story` fires on merge. The orchestrator runs `contract-dev` first (alone), then `backend-dev` and `frontend-dev` in parallel, scoped to their file boundaries. Opens a feature PR.
5. `pr-review` fires on the feature PR. Three subagents post review comments in parallel — no approvals, comments only.
6. Human reviews comments, iterates if needed, merges.
7. `post-merge` closes the ADO work items and archives the run trace as a pipeline artifact.

---

## Rules worth repeating

- **Skills are read-only.** Customize behavior via `shared/project/` (overrides, guidelines, stacks). Never edit files under `shared/skills/` or `shared/agents/`.
- **Hooks are the trust layer.** They block writes to sensitive files and enforce subagent scope. Disabling them collapses the whole safety model.
- **Claude never merges.** Branch policies enforce this. Do not remove or bypass them.
- **Every run produces a trace.** Local runs write to `.claude/trace/`; pipeline runs archive as build artifacts. Read the trace when something goes wrong.
- **CLI over MCP.** New integrations get a script wrapper in `shared/scripts/` first. MCP is reserved for services with no stable CLI.

---

## Detailed docs

- **[docs/TECHNICAL_DESIGN.md](docs/TECHNICAL_DESIGN.md)** — full architecture, every file spec, hook contract, and skill interface. If this README disagrees with that doc, the doc is authoritative.
- **[docs/FUNCTIONAL_DESIGN.md](docs/FUNCTIONAL_DESIGN.md)** — what the system does and why, without implementation details.
