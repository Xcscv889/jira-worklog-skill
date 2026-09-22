# Lessons learned

Add only a reusable, non-sensitive lesson that changes future decisions. Each entry records the trigger, root cause, durable rule, and evidence.

## 2026-09-22 — Verify before planning

- Trigger: a selected Jira issue may describe a bug already fixed in the current branch.
- Root cause: treating ticket text as the current system state leads to duplicate work.
- Rule: trace the current path and use source, a targeted test, or a minimal reproduction to verify the issue before proposing a fix. Stop with evidence if it is gone.
- Evidence: BOINVEST-422's dangling related-link cleanup is present in the current source.

## 2026-09-22 — Resolve through the ticket's actual workflow

- Trigger: status and resolution IDs can vary by workflow.
- Root cause: hard-coded IDs can update the wrong state or fail on another issue type.
- Rule: inspect the issue's available transitions, preview the unique transition that accepts `Done`, and refuse ambiguous workflows before any mutation.
- Evidence: BOINVEST-422 exposes a distinct resolve transition and requires a resolution field.

## 2026-09-22 — Preserve Jira descriptions

- Trigger: a one-line summary lost prerequisites, reproduction, and evidence needed for diagnosis.
- Root cause: treating an issue description as a display summary rather than source material.
- Rule: show the full Jira description verbatim; summaries are a separate field.
