param(
  [ValidateSet("UpstreamFastDev", "FastDev", "Default")]
  [string]$Config = "UpstreamFastDev",

  [string]$Profile = "google-sync-profile"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$workspaceRoot = Split-Path -Parent $PSCommandPath
$outDir = Join-Path $workspaceRoot ("src\out\" + $Config)
$chrome = Join-Path $outDir "chrome.exe"
$argsFile = Join-Path $outDir "args.gn"

if (-not (Test-Path $chrome)) {
  throw "Chromium not found: $chrome"
}

function Get-GnString([string]$Name) {
  if (-not (Test-Path $argsFile)) {
    return $null
  }

  $pattern = ('^\s*' + [regex]::Escape($Name) + '\s*=\s*"([^"]*)"')
  $line = Select-String -Path $argsFile -Pattern $pattern |
    Select-Object -First 1
  if ($line) {
    return $line.Matches[0].Groups[1].Value
  }
  return $null
}

$clientId = Get-GnString "google_default_client_id"
$clientSecret = Get-GnString "google_default_client_secret"
if ([string]::IsNullOrWhiteSpace($clientId) -or [string]::IsNullOrWhiteSpace($clientSecret)) {
  throw "Google OAuth settings are missing from args.gn."
}

$profileDir = Join-Path $workspaceRoot $Profile
$arguments = @(
  "--user-data-dir=$profileDir"
  "--no-first-run"
  "--no-default-browser-check"
  "--oauth2-client-id=$clientId"
  "--oauth2-client-secret=$clientSecret"
  "chrome://settings/people"
)

Start-Process -FilePath $chrome -ArgumentList $arguments
