#Requires -Version 5.1
<#
.SYNOPSIS
    Generate SHA-256 input manifest for a FIELDLEDGER study directory (Windows).
.DESCRIPTION
    Uses PowerShell Get-FileHash -Algorithm SHA256 to compute digests for all
    CSV dataset files in the study directory without modifying source files.
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
$RequiredFiles = @("study.csv", "sources.csv", "sites.csv", "surveys.csv", "observations.csv")

foreach ($req in $RequiredFiles) {
    $fullReq = Join-Path $ResolvedStudy $req
    if (-not (Test-Path -LiteralPath $fullReq -PathType Leaf)) {
        Write-Error "Required dataset file missing: $req (in $ResolvedStudy)"
        exit 1
    }
}

# Extract dataset_id from study.csv (row 2, col 1)
$DatasetId = "UNKNOWN"
$studyLines = @(Get-Content -LiteralPath (Join-Path $ResolvedStudy "study.csv") -TotalCount 2)
if ($studyLines.Count -ge 2) {
    $firstCol = ($studyLines[1] -split ",")[0].Trim().Trim('"')
    if ($firstCol) { $DatasetId = $firstCol }
}

$TimestampUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$ManifestPath = Join-Path $ResolvedStudy "manifest.sha256"

# Collect all CSV files sorted deterministically by relative path
$Files = Get-ChildItem -LiteralPath $ResolvedStudy -File -Filter "*.csv" |
    Sort-Object Name

$Lines = New-Object System.Collections.Generic.List[string]
$Lines.Add("# FIELDLEDGER SHA-256 INPUT MANIFEST v1")
$Lines.Add("# dataset_id: $DatasetId")
$Lines.Add("# generated_utc: $TimestampUtc")
$Lines.Add("# algorithm: SHA-256")
$Lines.Add("# format: <sha256_hex>  <file_size_bytes>  <relative_path>")

foreach ($f in $Files) {
    $hashObj = Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256
    $digest  = $hashObj.Hash.ToLowerInvariant()
    $size    = $f.Length
    $relName = $f.Name
    $Lines.Add("$digest  $size  $relName")
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($ManifestPath, $Lines, $utf8NoBom)

Write-Host "Generated SHA-256 manifest: $ManifestPath"
Write-Host "  Dataset ID : $DatasetId"
Write-Host "  Files      : $($Files.Count)"
Write-Host "  Generated  : $TimestampUtc"
exit 0
