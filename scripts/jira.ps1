param(
  [Parameter(Mandatory = $true)][ValidateSet('list', 'get', 'comment', 'resolve-preview', 'resolve')][string]$Action,
  [string]$IssueKey,
  [string]$Report
)

$ErrorActionPreference = 'Stop'
$baseUrl = 'http://jira.bocloud.com.cn:9991'
$credentialPath = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\jira-bocloud.credential.xml'
if (-not (Test-Path -LiteralPath $credentialPath)) { throw 'JIRA_CREDENTIALS_MISSING' }

$credential = Import-Clixml -LiteralPath $credentialPath
$pair = '{0}:{1}' -f $credential.UserName, $credential.GetNetworkCredential().Password
$headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair)); Accept = 'application/json' }

function Get-JiraTransitions([string]$IssueKey) {
  $issue = [uri]::EscapeDataString($IssueKey)
  Invoke-RestMethod -Uri "$baseUrl/rest/api/2/issue/$issue/transitions?expand=transitions.fields" -Headers $headers -TimeoutSec 20
}

function Get-DoneResolveCandidate($Transitions) {
  $candidates = @($Transitions | Where-Object {
    $resolutionField = $_.fields.resolution
    $resolutionField -and @($resolutionField.allowedValues | Where-Object { $_.name -eq 'Done' }).Count -gt 0
  })
  if ($candidates.Count -ne 1) { throw 'JIRA_DONE_TRANSITION_AMBIGUOUS_OR_UNAVAILABLE' }
  $transition = $candidates[0]
  $resolution = @($transition.fields.resolution.allowedValues | Where-Object { $_.name -eq 'Done' }) | Select-Object -First 1
  [pscustomobject]@{ transition = $transition; resolution = $resolution }
}

try {
  switch ($Action) {
    'list' {
      $jql = 'project = BOINVEST AND assignee = currentUser() AND resolution = Unresolved ORDER BY updated DESC'
      $query = [uri]::EscapeDataString($jql)
      Invoke-RestMethod -Uri "$baseUrl/rest/api/2/search?jql=$query&fields=summary,status,priority,updated,description,comment&maxResults=50" -Headers $headers -TimeoutSec 20 |
        ConvertTo-Json -Depth 20
    }
    'get' {
      if (-not $IssueKey) { throw 'JIRA_ISSUE_KEY_REQUIRED' }
      Invoke-RestMethod -Uri "$baseUrl/rest/api/2/issue/$([uri]::EscapeDataString($IssueKey))?fields=summary,status,priority,description,comment,attachment,issuelinks,updated" -Headers $headers -TimeoutSec 20 |
        ConvertTo-Json -Depth 20
    }
    'comment' {
      if (-not $IssueKey -or -not $Report) { throw 'JIRA_ISSUE_KEY_OR_REPORT_REQUIRED' }
      $body = @{ body = $Report } | ConvertTo-Json -Compress
      $commentHeaders = $headers.Clone()
      $commentHeaders['Content-Type'] = 'application/json'
      Invoke-RestMethod -Method Post -Uri "$baseUrl/rest/api/2/issue/$([uri]::EscapeDataString($IssueKey))/comment" -Headers $commentHeaders -Body $body -TimeoutSec 20 |
        ConvertTo-Json -Depth 10
    }
    'resolve-preview' {
      if (-not $IssueKey) { throw 'JIRA_ISSUE_KEY_REQUIRED' }
      $available = Get-JiraTransitions $IssueKey
      $candidate = Get-DoneResolveCandidate $available.transitions
      [pscustomobject]@{
        issue = $IssueKey
        selected = @{ transitionId = $candidate.transition.id; transition = $candidate.transition.name; targetStatus = $candidate.transition.to.name; resolution = $candidate.resolution.name }
        transitions = @($available.transitions | ForEach-Object { @{ id = $_.id; name = $_.name; targetStatus = $_.to.name; requiredFields = @($_.fields.psobject.Properties | Where-Object { $_.Value.required } | ForEach-Object Name) } })
      } | ConvertTo-Json -Depth 10
    }
    'resolve' {
      if (-not $IssueKey -or -not $Report) { throw 'JIRA_ISSUE_KEY_OR_REPORT_REQUIRED' }
      $issue = [uri]::EscapeDataString($IssueKey)
      $candidate = Get-DoneResolveCandidate (Get-JiraTransitions $IssueKey).transitions
      $transition = $candidate.transition
      $resolution = $candidate.resolution
      $body = @{ transition = @{ id = $transition.id }; fields = @{ resolution = @{ id = $resolution.id } }; update = @{ comment = @(@{ add = @{ body = $Report } }) } } | ConvertTo-Json -Depth 10 -Compress
      $transitionHeaders = $headers.Clone()
      $transitionHeaders['Content-Type'] = 'application/json'
      Invoke-RestMethod -Method Post -Uri "$baseUrl/rest/api/2/issue/$issue/transitions" -Headers $transitionHeaders -Body $body -TimeoutSec 20
      @{ issue = $IssueKey; status = $transition.to.name; resolution = $resolution.name } | ConvertTo-Json -Compress
    }
  }
} finally {
  $pair = $null
}
