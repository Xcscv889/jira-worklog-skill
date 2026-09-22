param(
  [Parameter(Mandatory = $true)][ValidateSet('list', 'get', 'comment', 'resolve')][string]$Action,
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
    'resolve' {
      if (-not $IssueKey -or -not $Report) { throw 'JIRA_ISSUE_KEY_OR_REPORT_REQUIRED' }
      $issue = [uri]::EscapeDataString($IssueKey)
      $available = Invoke-RestMethod -Uri "$baseUrl/rest/api/2/issue/$issue/transitions?expand=transitions.fields" -Headers $headers -TimeoutSec 20
      $transition = @($available.transitions | Where-Object { $_.to.id -eq '5' }) | Select-Object -First 1
      if (-not $transition) { throw 'JIRA_RESOLVE_TRANSITION_UNAVAILABLE' }
      $resolution = @($transition.fields.resolution.allowedValues | Where-Object { $_.id -eq '10300' }) | Select-Object -First 1
      if (-not $resolution) { throw 'JIRA_RESOLUTION_VALUE_UNAVAILABLE' }
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
