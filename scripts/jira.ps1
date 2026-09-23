param(
  [Parameter(Mandatory = $true)][ValidateSet('list', 'get', 'comment', 'resolve-preview', 'resolve', 'download-attachment', 'cleanup-attachments')][string]$Action,
  [string]$IssueKey,
  [string]$Report,
  [ValidatePattern('^[A-Z][A-Z0-9_]*$')][string]$Project,
  [ValidatePattern('^\d+$')][string]$AttachmentId,
  [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'
$stateDir = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex'
$baseUrl = $null
$pair = $null
$headers = @{}
if ($Action -ne 'cleanup-attachments') {
  $credentialPath = Join-Path $stateDir 'jira-worklog.credential.xml'
  $configPath = Join-Path $stateDir 'jira-worklog.config.json'
  if (-not (Test-Path -LiteralPath $configPath)) { throw 'JIRA_SETUP_REQUIRED' }
  if (-not (Test-Path -LiteralPath $credentialPath)) { throw 'JIRA_CREDENTIALS_MISSING' }
  $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
  $baseUrl = ([string]$config.baseUrl).TrimEnd('/')
  if (-not $baseUrl) { throw 'JIRA_CONFIG_INVALID' }
  try {
    $credential = Import-Clixml -LiteralPath $credentialPath
  } catch {
    throw 'JIRA_CREDENTIALS_DECRYPT_FAILED: retry under the Windows identity that created the credential before asking the user to authenticate again.'
  }
  $pair = '{0}:{1}' -f $credential.UserName, $credential.GetNetworkCredential().Password
  $headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair)); Accept = 'application/json' }
}
function Get-ProjectAttachmentDirectory([string]$ProjectRoot, [string]$IssueKey, [switch]$RequireIgnored) {
  if (-not $ProjectRoot -or $IssueKey -notmatch '^[A-Z][A-Z0-9]+-\d+$') { throw 'JIRA_ATTACHMENT_PROJECT_OR_ISSUE_INVALID' }
  $repoRoot = (& git -C $ProjectRoot rev-parse --show-toplevel 2>$null)
  if ($LASTEXITCODE -ne 0 -or -not $repoRoot) { throw 'JIRA_ATTACHMENT_PROJECT_NOT_GIT_REPOSITORY' }
  $repoRoot = $repoRoot.Trim()
  if ($RequireIgnored) {
    $ignorePath = ".tmp/jira-worklog/$IssueKey/.jira-worklog-manifest.json"
    & git -C $repoRoot check-ignore -q -- $ignorePath
    if ($LASTEXITCODE -ne 0) { throw 'JIRA_ATTACHMENT_TEMP_DIRECTORY_NOT_GIT_IGNORED' }
  }
  $directory = Join-Path $repoRoot ".tmp\jira-worklog\$IssueKey"
  foreach ($candidate in @((Join-Path $repoRoot '.tmp'), (Join-Path $repoRoot '.tmp\jira-worklog'), $directory)) {
    if (Test-Path -LiteralPath $candidate) {
      $item = Get-Item -LiteralPath $candidate -Force
      if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'JIRA_ATTACHMENT_PATH_REPARSE_POINT' }
    }
  }
  $directory
}
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
      $jql = 'assignee = currentUser() AND resolution = Unresolved'
      if ($Project) { $jql = "project = $Project AND $jql" }
      $jql += ' ORDER BY updated DESC'
      $query = [uri]::EscapeDataString($jql)
      Invoke-RestMethod -Uri "$baseUrl/rest/api/2/search?jql=$query&fields=project,summary,description,attachment&maxResults=50" -Headers $headers -TimeoutSec 20 |
        ConvertTo-Json -Depth 20
    }
    'get' {
      if (-not $IssueKey) { throw 'JIRA_ISSUE_KEY_REQUIRED' }
      Invoke-RestMethod -Uri "$baseUrl/rest/api/2/issue/$([uri]::EscapeDataString($IssueKey))?fields=summary,status,priority,description,comment,attachment,issuelinks,updated" -Headers $headers -TimeoutSec 20 |
        ConvertTo-Json -Depth 20
    }
    'download-attachment' {
      if (-not $IssueKey -or -not $AttachmentId -or -not $ProjectRoot) { throw 'JIRA_ATTACHMENT_ARGUMENT_REQUIRED' }
      $issue = [uri]::EscapeDataString($IssueKey)
      $issueData = Invoke-RestMethod -Uri "$baseUrl/rest/api/2/issue/$issue?fields=attachment" -Headers $headers -TimeoutSec 20
      $attachment = @($issueData.fields.attachment | Where-Object { $_.id -eq $AttachmentId }) | Select-Object -First 1
      if (-not $attachment) { throw 'JIRA_ATTACHMENT_NOT_FOUND_ON_ISSUE' }
      $contentUri = [uri]$attachment.content
      $baseUri = [uri]$baseUrl
      if ($contentUri.Scheme -ne $baseUri.Scheme -or $contentUri.Authority -ne $baseUri.Authority) { throw 'JIRA_ATTACHMENT_URL_ORIGIN_MISMATCH' }

      $directory = Get-ProjectAttachmentDirectory -ProjectRoot $ProjectRoot -IssueKey $IssueKey -RequireIgnored
      $manifestPath = Join-Path $directory '.jira-worklog-manifest.json'
      $safeName = [IO.Path]::GetFileName([string]$attachment.filename)
      $safeName = [regex]::Replace($safeName, '[<>:"/\\|?*\x00-\x1f]', '_').TrimEnd(' ', '.')
      if (-not $safeName) { $safeName = "attachment-$AttachmentId" }
      $fileName = "$AttachmentId-$safeName"
      $targetPath = Join-Path $directory $fileName

      if (Test-Path -LiteralPath $directory) {
        if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'JIRA_ATTACHMENT_DIRECTORY_NOT_OWNED' }
        if ((Get-Item -LiteralPath $manifestPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'JIRA_ATTACHMENT_MANIFEST_REPARSE_POINT' }
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        if ($manifest.issue -ne $IssueKey) { throw 'JIRA_ATTACHMENT_MANIFEST_ISSUE_MISMATCH' }
      } else {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        $manifest = [pscustomobject]@{ issue = $IssueKey; files = @() }
        [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), [Text.Encoding]::UTF8)
      }
      if (Test-Path -LiteralPath $targetPath) { throw 'JIRA_ATTACHMENT_TARGET_EXISTS' }
      $manifest.files = @($manifest.files) + @($fileName)
      [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 5), [Text.Encoding]::UTF8)
      try {
        Invoke-WebRequest -Uri $contentUri -Headers $headers -OutFile $targetPath -TimeoutSec 60 -UseBasicParsing | Out-Null
        if ((Get-Item -LiteralPath $targetPath).Length -ne [long]$attachment.size) { throw 'JIRA_ATTACHMENT_SIZE_MISMATCH' }
      } catch {
        throw "JIRA_ATTACHMENT_DOWNLOAD_FAILED: $($_.Exception.Message). The manifest records the partial copy for safe cleanup."
      }
      [pscustomobject]@{ issue = $IssueKey; attachmentId = $AttachmentId; filename = $attachment.filename; localPath = $targetPath } | ConvertTo-Json -Compress
    }
    'cleanup-attachments' {
      if (-not $IssueKey -or -not $ProjectRoot) { throw 'JIRA_ATTACHMENT_ARGUMENT_REQUIRED' }
      $directory = Get-ProjectAttachmentDirectory -ProjectRoot $ProjectRoot -IssueKey $IssueKey
      $manifestPath = Join-Path $directory '.jira-worklog-manifest.json'
      if (-not (Test-Path -LiteralPath $manifestPath)) {
        [pscustomobject]@{ issue = $IssueKey; deletedCopies = 0; preservedOtherFiles = 0 } | ConvertTo-Json -Compress
        break
      }
      if ((Get-Item -LiteralPath $manifestPath -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'JIRA_ATTACHMENT_MANIFEST_REPARSE_POINT' }
      $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
      if ($manifest.issue -ne $IssueKey) { throw 'JIRA_ATTACHMENT_MANIFEST_ISSUE_MISMATCH' }
      $deleted = 0
      foreach ($fileName in @($manifest.files)) {
        if ([IO.Path]::GetFileName([string]$fileName) -ne [string]$fileName) { throw 'JIRA_ATTACHMENT_MANIFEST_PATH_INVALID' }
        $targetPath = Join-Path $directory ([string]$fileName)
        if (Test-Path -LiteralPath $targetPath) { Remove-Item -LiteralPath $targetPath -Force; $deleted++ }
      }
      Remove-Item -LiteralPath $manifestPath -Force
      $remaining = @(Get-ChildItem -LiteralPath $directory -Force)
      if ($remaining.Count -eq 0) { Remove-Item -LiteralPath $directory -Force }
      [pscustomobject]@{ issue = $IssueKey; deletedCopies = $deleted; preservedOtherFiles = $remaining.Count } | ConvertTo-Json -Compress
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
