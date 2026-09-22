$ErrorActionPreference = 'Stop'

$baseUrl = 'http://jira.bocloud.com.cn:9991'
$credentialPath = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\jira-bocloud.credential.xml'
$credentialDir = Split-Path -Parent $credentialPath

New-Item -ItemType Directory -Force -Path $credentialDir | Out-Null
$credential = Get-Credential -Message 'Jira login. Credentials are encrypted for this Windows user only.'
if (-not $credential) { throw 'JIRA_CREDENTIALS_REQUIRED' }

$pair = '{0}:{1}' -f $credential.UserName, $credential.GetNetworkCredential().Password
$headers = @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair)) }
try {
  $me = Invoke-RestMethod -Uri "$baseUrl/rest/api/2/myself" -Headers $headers -TimeoutSec 15
  $credential | Export-Clixml -LiteralPath $credentialPath
  Write-Output ("JIRA_CONNECTED: {0}" -f $me.displayName)
} finally {
  $pair = $null
}
