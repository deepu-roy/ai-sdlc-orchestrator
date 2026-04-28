---
name: security-review
description: Review a PR diff for security issues — OWASP Top 10, LLM-specific risks, injection, secrets, auth, and data exposure. Posts PR comments; never approves.
argument-hint: "<pr-id>"
---

# Security review

Review PR **$1** for security issues. Be specific, cite the line, assign severity.

## Hard rules

1. **No approvals.** Comments only.
2. **Accuracy over volume.** A wrong security finding costs more trust than a missed one. If you're uncertain, mark as `minor` and note the uncertainty.
3. **Never echo secrets.** If you find one, note the file:line and the type of secret; do not paste the value.

## Checklist (OWASP Top 10 + LLM + project-specific)

### Injection
- SQL built via string concat → blocker.
- Shell built via string concat of user input → blocker.
- HTML rendered without escaping → major unless explicitly safe.
- LLM prompts built from user input without separation → major.

### Auth and session
- New endpoint without authn check → blocker.
- Role/permission check missing on mutating endpoint → blocker.
- JWT/token validation skipped or signature not verified → blocker.
- Password or token in logs → blocker.

### Data exposure
- PII returned in a response where it wasn't before → major.
- Error response includes stack trace → major.
- Error response leaks internal paths or DB schema → major.

### Cryptography
- New use of MD5 or SHA1 for anything non-cosmetic → major.
- Hardcoded IV, salt, or key → blocker.
- `Math.random()` / `random.random()` for security purposes → blocker.

### Secrets
- Any key, token, password, connection string in source → blocker.
- `.env` file committed → blocker (note: hook should have caught this; flag the hook failure too).

### Configuration
- CORS wildcard → major.
- Cookie without `HttpOnly`, `Secure`, `SameSite` → minor to major depending on content.
- Debug or verbose logging enabled for prod path → minor.

### LLM-specific
- Prompt assembled from untrusted content without isolation markers → major.
- Tool-call pattern without permission gate → major.
- Uncontrolled retry loops over LLM calls (cost risk) → minor.

### Project-specific
Read `.github/project/overrides/security-review.md` for project-specific rules (e.g. PII catalog, audit requirements). Apply them.

## Procedure

1. Load project layer (as in pr-review skill).
2. `git diff origin/main...HEAD`.
3. Walk the checklist. For each finding, post an inline comment with severity and exact line.
4. Post one summary:

```
Security review complete.
Blockers: N (must resolve before merge)
Major: N
Minor: N
Checklist coverage: <list of categories checked>
```

5. Emit standard handoff block.
