---
name: jira-worklog
description: Read assigned Jira issues and analyse, resolve, and update Jira reports for a configured Jira Server or Data Center instance.
---

# Jira worklog

Use the bundled PowerShell helper. Configure it once with `scripts/jira-auth.ps1 -BaseUrl https://jira.example.com`.

- Read the current user's unresolved issues with `scripts/jira.ps1 list`.
- Read an issue with `scripts/jira.ps1 get PROJ-123` before analysis or edits.
- In lists, show each Jira description verbatim and in full. Retain sections such as prerequisites, reproduction, actual result, expected result, and evidence; do not replace them with a summary.

## Selected-issue workflow

1. Start read-only: trace the complete data flow and execution path, read relevant maintenance docs, and inspect the related source before forming a cause. Do not guess.
2. Verify the ticket still exists in the current source and behavior. Use the relevant test, a minimal reproduction, or source evidence; if it no longer exists, report the evidence and stop without proposing or making a fix.
3. Before proposing a fix, produce a feature and logic brief: user and business goal, current and desired behavior, inputs and outputs, state transitions, ownership and module boundaries, invariants, edge cases, reused capabilities, and acceptance criteria. Separate verified facts, reasonable inferences, and open questions.
4. Use the narrowest reproducible check first. When stable automation is possible, add a failing test before the fix; otherwise explain why and use a minimal reproduction, read-only diagnosis, or targeted temporary logging. Remove temporary debugging code before delivery.
5. Discuss a complete, executable, low-risk plan before editing. Check existing behavior and modules, including risks not stated in the ticket, so the change does not create logical conflicts.
6. Prefer upgrading and reusing existing services, state, IPC, UI primitives, and patterns over parallel implementations. Frontend changes must follow the repository UI system, remain polished and accessible, and may include relevant proven product capabilities for the user to consider. Do not use arrow icons for navigation or action controls.
7. Follow discuss, design, implement, validate. Do not modify code until the user explicitly confirms the plan.
8. After implementation, run a QA sweep: review the changed data flow, sibling callers, state variants, regressions, and related Jira tickets for the same subsystem. Fix issues found in the same approved scope, then rerun targeted validation; otherwise surface them separately.
9. For complex business logic, cross-module behavior, backend/main-process boundaries, persistence, permissions, or recovery semantics, create or update the relevant maintenance documentation with the data flow, boundary, failure recovery, and validation approach.

## Learning log

Read [references/lessons-learned.md](references/lessons-learned.md) when a similar failure, correction, or workflow decision appears. After a meaningful reusable lesson, update it before handoff with the trigger, root cause, durable rule, and evidence. Classify it under the document's fixed categories, merge it into an existing rule when it is the same pattern, and add a category only when no existing category fits. Do not record credentials, customer data, ticket prose, or routine task history; avoid duplicates and replace obsolete rules.

- Draft a concise resolution report after validation. It must state only the cause and solution; do not include test or verification results unless the user asks.
- Only run `scripts/jira.ps1 comment PROJ-123 <report>` when the user explicitly says to submit/post the report.
- Before any status update, run `scripts/jira.ps1 resolve-preview PROJ-123` and show the exact transition, target status, resolution, and concise comment to the user. Do not proceed if the workflow is ambiguous.
- When the user explicitly confirms that preview, run `scripts/jira.ps1 resolve PROJ-123 <report>`. It atomically posts the report and applies the ticket's uniquely available transition that accepts resolution `Done`. Never infer this authorization.
