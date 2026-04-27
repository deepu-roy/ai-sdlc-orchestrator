---
name: update-functional
description: Incorporate answers to open questions in functional.md, update the document, and determine whether technical design can now proceed. Use after a human has answered questions flagged in §6 of functional.md.
argument-hint: "<work-item-id>"
allowed-tools: Read, Write, Edit, Bash(git:*), Bash(.claude/scripts/*)
---

# Update functional design with answers

Work item: $1

## Procedure

### Step 1 — Load current state
Read `docs/designs/WI-$1/functional.md`. Extract all items in section 6
(Open questions). Categorise each as:
- ANSWERED — answer is present inline or in the ADO work item comments
- UNANSWERED — still open
- DEFERRED — explicitly out of scope for this story

### Step 2 — Read answers
Read the ADO work item comments for any answers posted since the
document was generated:
```bash
.github/scripts/ado-wi-show.sh $1 | jq '.comments // .fields["System.History"]'
```
Also read any inline edits the human made directly to functional.md.

### Step 3 — Update functional.md
For each ANSWERED question:
- Incorporate the answer into the relevant section
  (personas, success criteria, scope, journeys — wherever it belongs)
- Remove it from section 6
- Add a citation: [answered by <source> on <date>]

For each DEFERRED question:
- Move to a new section 7 Deferred decisions with rationale

For each still UNANSWERED question:
- Leave in section 6, flag as [BLOCKING] if it prevents technical design,
  [NON-BLOCKING] if technical design can proceed without it

### Step 4 — Re-run tech-agnostic check
```bash
.github/scripts/check-tech-agnostic.sh docs/designs/WI-$1/functional.md
```

### Step 5 — Gate check
Evaluate: can technical design proceed?

BLOCKING criteria (any one blocks):
- A success criterion is still [NEEDS HUMAN INPUT]
- A user journey has an unresolved branch
- The scope boundary is ambiguous (in-scope vs out-of-scope unclear)

NON-BLOCKING (can proceed):
- Edge cases not fully defined
- Nice-to-have persona details missing
- Non-critical NFRs unspecified

### Step 6 — Commit and report
```bash
git add docs/designs/WI-$1/functional.md
git commit -m "WI-$1: update functional.md with answered questions"
git push
```

Emit:
```
=== FUNCTIONAL UPDATE COMPLETE ===
Questions answered: N
Questions deferred: N
Questions still open: N
  - BLOCKING: N
  - NON-BLOCKING: N

Verdict: PROCEED to technical design | BLOCKED — resolve open questions first

Blocking questions remaining:
- <list>
```