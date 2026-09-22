# jira-worklog-skill

Codex skill for reading, analysing, reporting, and resolving assigned Jira Server issues.

## Install

Copy this repository to your Codex skills directory as `jira-worklog`:

```text
%USERPROFILE%\.codex\skills\jira-worklog
```

Run `scripts/jira-auth.ps1` once to store the Jira credential encrypted for the current Windows user. Credentials are saved outside this repository under `%LOCALAPPDATA%\OpenAI\Codex`.

> This skill is configured for the BOINVEST internal Jira Server and should remain in a private repository.
