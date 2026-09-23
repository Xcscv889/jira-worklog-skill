# Lessons learned

Store only reusable, non-sensitive lessons that change future decisions. Classify a new lesson under an existing category, merge duplicate patterns into the existing rule, and add a category only when none fits.

## Issue verification

### Verify before planning

- Trigger: a selected Jira issue may describe a bug already fixed in the current branch.
- Root cause: treating ticket text as the current system state leads to duplicate work.
- Rule: trace the current path and use source, a targeted test, or a minimal reproduction to verify the issue before proposing a fix. Stop with evidence if it is gone.
- Evidence: a selected issue's reported cleanup defect was already covered by the current source.

## Jira workflow safety

### Distinguish missing credentials from decryption failures

- Trigger: a configured Jira query reports `Import-Clixml` cryptographic failure.
- Root cause: Windows-protected credentials can only be decrypted by the Windows identity that created them; the file may still exist and the Jira account may still be logged in.
- Rule: distinguish missing credential files from decryption errors. Retry under the creating Windows identity before asking the user to authenticate again. Never expose the credential.
- Evidence: a configured credential file failed to decrypt in an isolated Codex execution identity; the same query succeeded in the user's Windows environment.

### Download and remove Jira attachment copies safely

- Trigger: a selected issue includes an attachment needed to inspect or reproduce the defect.
- Root cause: downloading into ordinary source paths risks accidental commits or deleting unrelated files during cleanup.
- Rule: download only the required attachment into a Git-ignored, issue-specific temporary directory. Track exact downloaded filenames in a manifest and remove only those copies after investigation; preserve Jira originals and all unlisted files.
- Evidence: the Jira helper uses `.tmp/jira-worklog/<ISSUE-KEY>/` and a per-issue manifest.

### Resolve through the ticket's actual workflow

- Trigger: status and resolution IDs can vary by workflow.
- Root cause: hard-coded IDs can update the wrong state or fail on another issue type.
- Rule: inspect the issue's available transitions, preview the unique transition that accepts `Done`, and refuse ambiguous workflows before any mutation.
- Evidence: a Jira issue exposed a distinct resolve transition and required a resolution field.

## Information presentation

### Preserve Jira descriptions

- Trigger: a one-line summary lost prerequisites, reproduction, and evidence needed for diagnosis.
- Root cause: treating an issue description as a display summary rather than source material.
- Rule: show the full Jira description verbatim; summaries are a separate field.
