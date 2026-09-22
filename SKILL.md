---
name: jira-worklog
description: Read assigned Jira issues and analyse, resolve, and update Jira reports for the local BOINVEST Jira Server.
---

# Jira worklog

Use the bundled PowerShell helper for Jira Server at `http://jira.bocloud.com.cn:9991`.

- Read the current user's unresolved BOINVEST issues with `scripts/jira.ps1 list`.
- Read an issue with `scripts/jira.ps1 get BOINVEST-123` before analysis or edits.
- In lists, show each Jira description verbatim and in full. Retain sections such as prerequisites, reproduction, actual result, expected result, and evidence; do not replace them with a summary.

## Selected-issue workflow

1. Start read-only: trace the complete data flow and execution path, read relevant maintenance docs, and inspect the related source before forming a cause. Do not guess.
2. Verify the ticket still exists in the current source and behavior. Use the relevant test, a minimal reproduction, or source evidence; if it no longer exists, report the evidence and stop without proposing or making a fix.
3. Before proposing a fix, produce a feature and logic brief: user and business goal, current and desired behavior, inputs and outputs, state transitions, ownership and module boundaries, invariants, edge cases, reused capabilities, and acceptance criteria. Separate verified facts, reasonable inferences, and open questions.
4. Use the narrowest reproducible check first. When stable automation is possible, add a failing test before the fix; otherwise explain why and use a minimal reproduction, read-only diagnosis, or targeted temporary logging. Remove temporary debugging code before delivery.
5. Discuss a complete, executable, low-risk plan before editing. Check existing behavior and modules, including risks not stated in the ticket, so the change does not create logical conflicts.
6. Prefer upgrading and reusing existing services, state, IPC, UI primitives, and patterns over parallel implementations. Frontend changes must follow the repository UI system, remain polished and accessible, and may include relevant proven product capabilities for the user to consider. Do not use arrow icons for navigation or action controls.
7. Follow discuss, design, implement, validate. Do not modify code until the user explicitly confirms the plan.
8. After implementation, review the changed data flow, sibling callers, regressions, and test results. Fix issues found in the same approved scope, then rerun targeted validation.
9. For complex business logic, cross-module behavior, backend/main-process boundaries, persistence, permissions, or recovery semantics, create or update the relevant `docs/*.md` maintenance documentation with the data flow, boundary, failure recovery, and validation approach.

- Draft a concise Chinese resolution report after validation. It must state only the cause and solution; do not include test or verification results in the Jira comment.
- Only run `scripts/jira.ps1 comment BOINVEST-123 <report>` when the user explicitly says to submit/post the report.
- When the user explicitly confirms an issue is solved and asks to update it, run `scripts/jira.ps1 resolve BOINVEST-123 <report>`. It atomically posts the report, transitions the issue to its resolved state, and sets resolution to `Done`. Never infer this authorization.
- If credentials are missing, ask the user to run `scripts/jira-auth.ps1` once. Never ask for or print their password.
