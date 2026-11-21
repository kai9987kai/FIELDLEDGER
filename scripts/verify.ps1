#Requires -Version 5.1
<#
.SYNOPSIS
    Verify a FIELDLEDGER study directory against its stored manifest.sha256 (Windows).
.DESCRIPTION
    Checks manifest header integrity, parses each SHA-256 digest and byte size,
    verifies every listed file against PowerShell Get-FileHash -Algorithm SHA256,
    and detects modified, missing, corrupted, or unexpected CSV files.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$StudyPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $StudyPath -PathType Container)) {
    Write-Error "Study directory not found: $StudyPath"
    exit 1
}

$ResolvedStudy = (Resolve-Path -LiteralPath $StudyPath).Path
$ManifestPath  = Join-Path $ResolvedStudy "manifest.sha256"

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    Write-Error "Manifest file not found: $ManifestPath. Run 'fieldledger manifest --study <PATH>' first."
    exit 1
}

$RawLines = @(Get-Content -LiteralPath $ManifestPath)
if ($RawLines.Count -eq 0 -or $RawLines[0] -notmatch "^# FIELDLEDGER SHA-256 INPUT MANIFEST") {
    Write-Error "Corrupted manifest: missing or invalid FIELDLEDGER header in $ManifestPath"
    exit 1
}

$CheckedCount = 0
$FailCount    = 0
$ListedFiles  = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

for ($i = 0; $i -lt $RawLines.Count; $i++) {
    $line = $RawLines[$i].Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { continue }

    if ($line -notmatch "^([0-9a-fA-F]{64})\s+(\d+)\s+(.+)$") {
        Write-Host "[FAIL] Corrupted manifest entry on line $($i + 1): $line" -ForegroundColor Red
        $FailCount++
        continue
    }

    $expectedHash = $Matches[1].ToLowerInvariant()
    $expectedSize = [int64]$Matches[2]
    $relPath      = $Matches[3].Trim()

    if ($relPath.Contains("..") -or [System.IO.Path]::IsPathRooted($relPath)) {
        Write-Host "[FAIL] Unsafe path in manifest on line $($i + 1): $relPath" -ForegroundColor Red
        $FailCount++
        continue
    }

    [void]$ListedFiles.Add($relPath)
    $targetFile = Join-Path $ResolvedStudy $relPath

    if (-not (Test-Path -LiteralPath $targetFile -PathType Leaf)) {
        Write-Host "[FAIL] Missing file: $relPath" -ForegroundColor Red
        $FailCount++
        continue
    }

    $actualSize = (Get-Item -LiteralPath $targetFile).Length
    $actualHash = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash.ToLowerInvariant()

    if ($actualSize -ne $expectedSize -or $actualHash -ne $expectedHash) {
        Write-Host "[FAIL] INTEGRITY MISMATCH: $relPath" -ForegroundColor Red
        Write-Host "       Expected: sha256=$expectedHash size=$expectedSize"
        Write-Host "       Actual  : sha256=$actualHash size=$actualSize"
        $FailCount++
    } else {
        Write-Host "[OK]   $relPath ($actualSize bytes)"
    }
    $CheckedCount++
}

if ($CheckedCount -eq 0) {
    Write-Error "Corrupted manifest: no file digest entries found in $ManifestPath"
    exit 1
}

# Detect untracked CSV files added after manifest creation
$ActualCsvs = Get-ChildItem -LiteralPath $ResolvedStudy -File -Filter "*.csv"
foreach ($csv in $ActualCsvs) {
    if (-not $ListedFiles.Contains($csv.Name)) {
        Write-Host "[FAIL] Unexpected CSV file not in manifest: $($csv.Name)" -ForegroundColor Red
        $FailCount++
    }
}

if ($FailCount -gt 0) {
    Write-Host "MANIFEST VERIFICATION FAILED: $FailCount error(s) across $CheckedCount entry/entries."
    exit 1
}

Write-Host "MANIFEST VERIFIED: $CheckedCount file(s) matched SHA-256 digest and byte size."
exit 0
