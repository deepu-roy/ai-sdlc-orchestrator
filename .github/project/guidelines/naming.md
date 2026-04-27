# Naming conventions

> Consumed by implement-slice and pr-review. Keep concrete.

## Files

- [NEEDS HUMAN INPUT] — e.g. "React components: PascalCase.tsx. Hooks: useFoo.ts. Tests: *.test.ts / *.spec.ts."

## Branches

- `design/WI-<id>` for design PRs.
- `story/WI-<id>` for feature branches.
- `story/WI-<id>/<layer>` for subagent sub-branches.
- Never force-push.

## Commits

- [NEEDS HUMAN INPUT] — e.g. "Conventional Commits (feat, fix, chore, refactor)."
- First line: `WI-<id> S<slice-id>: <imperative summary>`.

## Work items

- Epic / Feature / Task hierarchy (ADO default).
- Child tasks created from slices are titled `[S<n>] <slice title>`.

## Identifiers in code

- [NEEDS HUMAN INPUT]
