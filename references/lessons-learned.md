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
- Rule: distinguish missing credential files from decryption errors. Codex may see the profile path while running as an isolated Windows identity without the DPAPI key. Check `whoami` and file presence without reading secrets, then retry the read under the identity that created the credential. Do not ask for reauthentication unless that retry reports an actual Jira authentication failure. Never expose the credential.
- Evidence: Jira `list` failed under an isolated Codex identity and succeeded under the user's Windows identity without changing or recreating the credential.

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

### Select a project before loading issue details

- Trigger: a user asks to browse assigned issues across several projects.
- Root cause: fetching every full description before knowing the desired project creates unnecessary output and makes the list hard to scan.
- Rule: fetch only project names/keys and unresolved counts first; let the user select a project, then fetch and display that project's issues as readable cards with full descriptions.
