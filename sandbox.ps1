#Requires -Version 5.1
<#
.SYNOPSIS
  Start and enter the agent sandbox (Windows). Same commands as sandbox.sh.

.EXAMPLE
  .\sandbox.ps1                 # shell in the container
  .\sandbox.ps1 claude          # Claude Code
  .\sandbox.ps1 hermes          # Hermes Agent
  .\sandbox.ps1 ticket ls       # ticket tool
  .\sandbox.ps1 doctor | build | update | status | logs | stop | down | reset-state
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive launcher with colored status output')]
[CmdletBinding()]
param(
  [Parameter(Position = 0)] [string] $Command = 'shell',
  [Parameter(Position = 1, ValueFromRemainingArguments = $true)] [string[]] $Rest = @()
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot
$Service = 'sandbox'

function Fail([string] $Message) { Write-Host "FEHLER: $Message" -ForegroundColor Red; exit 1 }
function Warn([string] $Message) { Write-Host $Message -ForegroundColor Yellow }

# ---------------------------------------------------------------- container engine
$Docker = if ($env:DOCKER) { $env:DOCKER } elseif (Get-Command docker -ErrorAction SilentlyContinue) { 'docker' } `
          elseif (Get-Command podman -ErrorAction SilentlyContinue) { 'podman' } else { $null }
if (-not $Docker) { Fail 'Neither Docker nor Podman found. Install: https://docs.docker.com/desktop/setup/install/windows-install/' }
& $Docker info *> $null; if ($LASTEXITCODE -ne 0) { Fail "$Docker is not running (start Docker Desktop)." }
& $Docker compose version *> $null; if ($LASTEXITCODE -ne 0) { Fail "'$Docker compose' missing (Compose v2 required)." }
function Invoke-Compose { & $Docker compose @args; if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE } }

# ---------------------------------------------------------------- check .env
if (-not (Test-Path .env)) {
  Copy-Item .env.example .env
  Warn '-> Created .env from .env.example. Fill it in (at least GIT_USER_NAME, GIT_USER_EMAIL and GH_TOKEN and/or GITLAB_TOKEN), then start again.'
  exit 1
}
function Get-EnvValue([string] $Name) {
  $line = Get-Content .env | Where-Object { $_ -match "^$Name=" } | Select-Object -Last 1
  if ($line) { return ($line -replace "^$Name=", '').Trim('"', "'") } else { return '' }
}
if (-not ((Get-EnvValue 'GH_TOKEN') + (Get-EnvValue 'GITLAB_TOKEN'))) { Warn '! GH_TOKEN and GITLAB_TOKEN are empty - tickets and PRs/MRs will not work.' }
if (-not (Get-EnvValue 'GIT_USER_NAME'))  { Warn '! GIT_USER_NAME is empty.' }
if (-not (Get-EnvValue 'GIT_USER_EMAIL')) { Warn '! GIT_USER_EMAIL is empty.' }

$ws = Get-EnvValue 'WORKSPACE_DIR'; if (-not $ws) { $ws = './workspace' }
New-Item -ItemType Directory -Force -Path $ws, 'secrets' | Out-Null

function Initialize-Sandbox {
  $img = Get-EnvValue 'SANDBOX_IMAGE'; if (-not $img) { $img = 'agent-sandbox:local' }
  & $Docker image inspect $img *> $null
  if ($LASTEXITCODE -ne 0) { Write-Host '-> First start: building the image (takes a few minutes) ...' -ForegroundColor Green; Invoke-Compose build }
  $running = & $Docker compose ps -q --status running $Service 2>$null
  if (-not $running) { Invoke-Compose up -d --remove-orphans | Out-Null }
}
function Invoke-InSandbox {
  Initialize-Sandbox
  $tty = if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { '-T' } else { '-it' }
  & $Docker compose exec $tty $Service @args
  exit $LASTEXITCODE
}

switch ($Command) {
  'shell'  { Invoke-InSandbox bash }
  'claude' { Invoke-InSandbox claude @Rest }
  'hermes' { Invoke-InSandbox hermes @Rest }
  'ticket' { Invoke-InSandbox ticket @Rest }
  'gate'   { Invoke-InSandbox devsecops-gate @Rest }
  'doctor' { Invoke-InSandbox sandbox-doctor }
  'exec'   { Invoke-InSandbox @Rest }
  'build'  { Invoke-Compose build --pull; Invoke-Compose up -d --force-recreate | Out-Null; Write-Host 'OK: rebuilt' -ForegroundColor Green }
  'update' { $env:CACHE_BUST_AGENTS = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds(); Invoke-Compose build --pull; Invoke-Compose up -d --force-recreate | Out-Null; Write-Host 'OK: updated' -ForegroundColor Green }
  'status' { Invoke-Compose ps }
  'logs'   { Invoke-Compose logs --tail 100 -f }
  'stop'   { Invoke-Compose stop }
  'down'   { Invoke-Compose down }
  'reset-state' {
    $a = Read-Host 'Delete all logins, sessions, Hermes memory and caches? [yes/N]'
    if ($a -eq 'yes') { Invoke-Compose down -v; Write-Host 'OK: volumes deleted.' -ForegroundColor Green }
  }
  default  { Get-Help $PSCommandPath -Detailed }
}
