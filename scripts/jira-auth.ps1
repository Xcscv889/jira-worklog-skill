param(
  [Parameter(Mandatory = $true)][string]$BaseUrl,
  [switch]$AllowInsecureHttp
)

$ErrorActionPreference = 'Stop'
try { $uri = [uri]$BaseUrl } catch { throw 'JIRA_BASE_URL_INVALID' }
if ($uri.Scheme -notin @('https', 'http') -or -not $uri.Host) { throw 'JIRA_BASE_URL_INVALID' }
if ($uri.Scheme -ne 'https' -and -not $AllowInsecureHttp) { throw 'JIRA_HTTPS_REQUIRED' }

$baseUrl = $uri.GetLeftPart([System.UriPartial]::Authority) + $uri.AbsolutePath.TrimEnd('/')
$stateDir = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex'
$credentialPath = Join-Path $stateDir 'jira-worklog.credential.xml'
$configPath = Join-Path $stateDir 'jira-worklog.config.json'

New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
$credential = Get-Credential -Message 'Jira login. Credentials are encrypted for this Windows user only.'
if (-not $credential) { throw 'JIRA_CREDENTIALS_REQUIRED' }

$pair = '{0}:{1}' -f $credential.UserName, $credential.GetNetworkCredential().Password
$headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair)) }
try {
  $me = Invoke-RestMethod -Uri "$baseUrl/rest/api/2/myself" -Headers $headers -TimeoutSec 15
  $credential | Export-Clixml -LiteralPath $credentialPath
  @{ baseUrl = $baseUrl } | ConvertTo-Json -Compress | Set-Content -LiteralPath $configPath -Encoding utf8
  Write-Output ("JIRA_CONNECTED: {0}" -f $me.displayName)
} finally {
  $pair = $null
}
