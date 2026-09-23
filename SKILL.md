---
name: jira-worklog
description: Read assigned Jira issues and analyse, resolve, and update Jira reports for a configured Jira Server or Data Center instance.
---

# Jira worklog

Use the bundled PowerShell helper for the configured Jira Server/Data Center. The user-level skill is shared across project workspaces for the same Windows user and Codex profile. Resolve scripts from the skill installation path, not the current project directory:

```powershell
$jira = Join-Path $env:USERPROFILE '.codex\skills\jira-worklog\scripts\jira.ps1'
$auth = Join-Path $env:USERPROFILE '.codex\skills\jira-worklog\scripts\jira-auth.ps1'
```

- Read all unresolved issues assigned to the current user with `& $jira list`; filter one project with `& $jira list -Project PROJ` (replace with the Jira project key).
- Read an issue with `& $jira get PROJ-123` before analysis or edits.
- In lists, show the project key/name, issue key, summary, attachment count and filenames, and each Jira description verbatim and in full. If there are no attachments, show `None`. Retain sections such as prerequisites, reproduction, actual result, expected result, and evidence; do not replace them with a summary. List attachment metadata only; do not download attachment contents until needed for a selected issue. Do not display status, update time, or priority unless requested.

## Issue attachments

- The list shows attachment filenames and counts; inspect the selected issue's attachment metadata before deciding whether a file is needed.
- Download only attachments needed to understand or reproduce the selected issue. Set `$repoRoot` to `(git rev-parse --show-toplevel).Trim()` and run `& $jira download-attachment -IssueKey PROJ-123 -AttachmentId 12345 -ProjectRoot $repoRoot`. The helper verifies that the attachment belongs to that issue and that the content URL is on the configured Jira server. It saves a local copy under `.tmp/jira-worklog/<ISSUE-KEY>/`; `.tmp/` must be Git-ignored. It refuses existing unmanaged folders or files rather than overwriting them.
- After investigation and any code fix/review are complete, run `& $jira cleanup-attachments -IssueKey PROJ-123 -ProjectRoot $repoRoot` before handoff. Cleanup deletes only filenames recorded in the helper's manifest, never recurses, and preserves Jira's original attachment and any other files in the folder. If the helper reports preserved files, leave them untouched and report their path.
- If work is interrupted before cleanup, tell the user the exact temporary folder so cleanup can resume later.

## Selected-issue workflow

1. Start read-only: trace the complete data flow and execution path, read relevant maintenance docs, and inspect the related source before forming a cause. Do not guess.
2. Verify the ticket still exists in the current source and behavior. Use the relevant test, a minimal reproduction, or source evidence; if it no longer exists, report the evidence and stop without proposing or making a fix.
3. Before proposing a fix, produce a feature and logic brief: user and business goal, current and desired behavior, inputs and outputs, state transitions, ownership and module boundaries, invariants, edge cases, reused capabilities, and acceptance criteria. Separate verified facts, reasonable inferences, and open questions.
4. Use the narrowest reproducible check first. When stable automation is possible, add a failing test before the fix; otherwise explain why and use a minimal reproduction, read-only diagnosis, or targeted temporary logging. Remove temporary debugging code before delivery.
5. Discuss a complete, executable, low-risk plan before editing. Check existing behavior and modules, including risks not stated in the ticket, so the change does not create logical conflicts.
6. Prefer upgrading and reusing existing services, state, IPC, UI primitives, and patterns over parallel implementations. Frontend changes must follow the repository UI system, remain polished and accessible, and may include relevant proven product capabilities for the user to consider. Do not use arrow icons for navigation or action controls.
7. Follow discuss, design, implement, validate. Do not modify code until the user explicitly confirms the plan.
8. After implementation, run a QA sweep: review the changed data flow, sibling callers, state variants, regressions, and related Jira tickets for the same subsystem. Fix issues found in the same approved scope, then rerun targeted validation; otherwise surface them separately.
9. For complex business logic, cross-module behavior, backend/main-process boundaries, persistence, permissions, or recovery semantics, create or update the relevant `docs/*.md` maintenance documentation with the data flow, boundary, failure recovery, and validation approach.

## Learning log

Read [references/lessons-learned.md](references/lessons-learned.md) when a similar failure, correction, or workflow decision appears. After a meaningful reusable lesson, update it before handoff with the trigger, root cause, durable rule, and evidence. Classify it under the document's fixed categories, merge it into an existing rule when it is the same pattern, and add a category only when no existing category fits. Do not record credentials, customer data, ticket prose, or routine task history; avoid duplicates and replace obsolete rules.

- Draft a concise Chinese resolution report after validation. It must state only the cause and solution; do not include test or verification results in the Jira comment.
- Only run `& $jira comment PROJ-123 <report>` when the user explicitly says to submit/post the report.
- Before any status update, run `& $jira resolve-preview PROJ-123` and show the exact transition, target status, resolution, and concise comment to the user. Do not proceed if the workflow is ambiguous.
- When the user explicitly confirms that preview, run `& $jira resolve PROJ-123 <report>`. It atomically posts the report and applies the ticket's uniquely available transition that accepts resolution `Done`. Never infer this authorization.
- If the credential file is missing, ask the user to run `& $auth` once. If the file exists but `Import-Clixml` reports a decryption/cryptographic error, treat it as a Windows identity/DPAPI mismatch, not a logged-out account: retry the Jira command in the Windows account environment that created the credential before asking for re-authentication. Never ask for or print their password.
