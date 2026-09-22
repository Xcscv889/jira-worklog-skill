# Jira Worklog Skill

A small Codex skill for an individual developer's Jira loop:

1. List assigned unresolved issues.
2. Read the full issue description.
3. Verify the problem in the current source before planning work.
4. Discuss a low-risk implementation plan and wait for approval.
5. Review related code and regressions after the fix.
6. Preview, then update Jira with a concise resolution comment and workflow transition.

It deliberately does not manage boards, sprints, worklogs, or bulk ticket changes.

## Install

Copy or clone this repository to your Codex skills directory as `jira-worklog`:

```text
%USERPROFILE%\.codex\skills\jira-worklog
```

## Connect Jira

PowerShell is required. Configure the Jira base URL and store credentials for the current Windows user:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\jira-auth.ps1 -BaseUrl https://jira.example.com
```

The setup verifies the account through Jira's REST API. The base URL is stored in `%LOCALAPPDATA%\OpenAI\Codex\jira-worklog.config.json`; the credential is encrypted with Windows DPAPI in `%LOCALAPPDATA%\OpenAI\Codex\jira-worklog.credential.xml`. Neither file belongs in this repository.

HTTPS is required by default. Use `-AllowInsecureHttp` only for a trusted legacy network where HTTPS is unavailable.

## Commands

```powershell
# Assigned unresolved issues
powershell -ExecutionPolicy Bypass -File scripts\jira.ps1 list

# One issue
powershell -ExecutionPolicy Bypass -File scripts\jira.ps1 get PROJ-123

# Read-only preview of the available Done transition
powershell -ExecutionPolicy Bypass -File scripts\jira.ps1 resolve-preview PROJ-123
```

`comment` and `resolve` change Jira. They are intended to be called by Codex only after the user explicitly confirms the preview. `resolve` adds the supplied comment and performs the uniquely available transition that accepts resolution `Done`; it refuses ambiguous workflows.

## Safety model

- Credentials and configuration are local and ignored by Git.
- Issue descriptions are shown in full; a summary never replaces source details.
- Source and behavior are verified before a fix is proposed.
- Jira status changes are previewed first and require explicit confirmation.
- Reusable, non-sensitive lessons are organized in `references/lessons-learned.md`.

## Scope

The helper targets Jira Server and Data Center REST APIs that support Basic authentication. Cloud instances may require an API token in place of a password and are not otherwise tested here.
