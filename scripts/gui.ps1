#Requires -Version 5.1
<#
.SYNOPSIS
    Launch the offline FIELDLEDGER GUI Workbench (Windows).
.DESCRIPTION
    Ensures build\fieldledger.exe exists (building it if needed) and starts
    the zero-dependency local GUI server bound to http://127.0.0.1:<Port>.
#>
[CmdletBinding()]
param(
    [int]$Port = 4173,
    [switch]$OpenBrowser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ExePath  = Join-Path $RepoRoot "build\fieldledger.exe"

if (-not (Test-Path $ExePath)) {
    Write-Host "FIELDLEDGER COBOL binary not found; building first..."
    & (Join-Path $PSScriptRoot "build.ps1")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "Node.js is required to serve the local GUI bridge (zero npm packages needed)."
    exit 1
}

if ($OpenBrowser) {
    Start-Process "http://127.0.0.1:$Port"
}

& node (Join-Path $RepoRoot "gui\server.mjs") --port $Port
exit $LASTEXITCODE
