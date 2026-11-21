#Requires -Version 5.1
<#
.SYNOPSIS
    Generates large synthetic datasets and runs real per-stage COBOL benchmarks.
.DESCRIPTION
    Compiles tests\integration\BENCHMARK.cob against the compiled FIELDLEDGER
    object modules, generates synthetic datasets (50,000 observations across
    100 sites & 25 species, plus full 250,000-observation capacity test), and
    records measured wall-clock durations and throughput.
#>
[CmdletBinding()]
param(
    [int]$Sites = 100,
    [int]$SurveysPerSite = 20,
    [int]$SpeciesCount = 25,
    [int]$Bootstrap = 2000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot  = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$BuildDir  = Join-Path $RepoRoot "build"
$ObjDir    = Join-Path $BuildDir "obj"
$BenchExe  = Join-Path $BuildDir "benchmark.exe"
$BenchRoot = Join-Path $RepoRoot "output\benchmark"
$StudyDir  = Join-Path $BenchRoot "study-synth"
$OutDir    = Join-Path $BenchRoot "results"

if (-not (Test-Path (Join-Path $ObjDir "BACI-ENGINE.o"))) {
    & (Join-Path $RepoRoot "scripts\build.ps1")
}

# Locate cobc
$CobcCmd = Get-Command cobc -ErrorAction SilentlyContinue
$MsysPrefix = $null
if (-not $CobcCmd) {
    foreach ($candidate in @("C:\msys64\ucrt64", "C:\msys64\mingw64", "C:\GnuCOBOL")) {
        if (Test-Path (Join-Path $candidate "bin\cobc.exe")) {
            $env:PATH = (Join-Path $candidate "bin") + ";" + $env:PATH
            $CobcCmd = Get-Command cobc -ErrorAction SilentlyContinue
            if ($candidate -like "*msys64*") { $MsysPrefix = $candidate }
            break
        }
    }
} elseif ((Split-Path (Split-Path $CobcCmd.Source -Parent) -Parent) -like "*msys64*") {
    $MsysPrefix = Split-Path (Split-Path $CobcCmd.Source -Parent) -Parent
}
if ($MsysPrefix) {
    $env:COB_CONFIG_DIR = Join-Path $MsysPrefix "share\gnucobol\config"
    $env:COB_COPY_DIR   = Join-Path $MsysPrefix "share\gnucobol\copy"
    $env:COB_CFLAGS     = "-I" + (Join-Path $MsysPrefix "include")
    $env:COB_LIBS       = "-L" + (Join-Path $MsysPrefix "lib") + " -lcob"
}

$AllObjs = Get-ChildItem -Path $ObjDir -Filter "*.o" | Sort-Object Name | ForEach-Object { $_.FullName }
& cobc -x -free -Wall -O2 -I (Join-Path $RepoRoot "copybooks") `
    -o $BenchExe (Join-Path $PSScriptRoot "BENCHMARK.cob") @AllObjs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

New-Item -ItemType Directory -Force -Path $StudyDir, $OutDir | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)

$totalSurveys = $Sites * $SurveysPerSite
$totalObs     = $totalSurveys * $SpeciesCount
Write-Host "Generating synthetic benchmark dataset ($Sites sites, $totalSurveys surveys, $totalObs observations, $SpeciesCount species)..."

[System.IO.File]::WriteAllText((Join-Path $StudyDir "study.csv"),
    "study_id,study_title,study_design,primary_outcome,primary_outcome_unit,study_description`nbench_synth,Synthetic Performance Benchmark Study,BACI,species_observations,detections_per_hour,Explicitly synthetic scalability benchmark dataset`n", $utf8)

[System.IO.File]::WriteAllText((Join-Path $StudyDir "sources.csv"),
    "source_id,source_type,source_title,organisation,citation,source_url,licence,accessed_date`nSRC001,synthetic_test_dataset,Synthetic Benchmark Fixture,FIELDLEDGER QA,Synthetic benchmark dataset,,MIT,2026-11-20`n", $utf8)

$swSites = New-Object System.IO.StreamWriter((Join-Path $StudyDir "sites.csv"), $false, $utf8)
$swSites.WriteLine("site_id,site_role,reference_date,area_ha,habitat_type,region_code")
$half = [int]($Sites / 2)
for ($s = 1; $s -le $Sites; $s++) {
    $role = if ($s -le $half) { "IMPACT" } else { "CONTROL" }
    $sid  = ("SITE{0:D4}" -f $s)
    $swSites.WriteLine("$sid,$role,2025-01-01,50.00,freshwater_marsh,REG01")
}
$swSites.Close()

$swSurvs = New-Object System.IO.StreamWriter((Join-Path $StudyDir "surveys.csv"), $false, $utf8)
$swSurvs.WriteLine("survey_id,site_id,survey_date,survey_minutes,method,observer_id,source_id")
$swObs   = New-Object System.IO.StreamWriter((Join-Path $StudyDir "observations.csv"), $false, $utf8)
$swObs.WriteLine("observation_id,survey_id,species_code,count,observation_status")

$survNo = 0
$obsNo  = 0
$halfSurv = [int]($SurveysPerSite / 2)
for ($s = 1; $s -le $Sites; $s++) {
    $sid = ("SITE{0:D4}" -f $s)
    $isImp = ($s -le $half)
    for ($v = 1; $v -le $SurveysPerSite; $v++) {
        $survNo++
        $svid = ("SRV{0:D6}" -f $survNo)
        $isPost = ($v -gt $halfSurv)
        $day = (($v - 1) % 28) + 1
        $dt  = if ($isPost) { "2025-06-{0:D2}" -f $day } else { "2024-06-{0:D2}" -f $day }
        $swSurvs.WriteLine("$svid,$sid,$dt,60,point_count,OBS01,SRC001")

        for ($sp = 1; $sp -le $SpeciesCount; $sp++) {
            $obsNo++
            $oid = ("OBS{0:D7}" -f $obsNo)
            $spc = ("SP{0:D3}" -f $sp)
            $cnt = 10 + (($s + $sp) % 7)
            if ($isPost) {
                $cnt += if ($isImp) { 8 } else { 2 }
            }
            $swObs.WriteLine("$oid,$svid,$spc,$cnt,DETECTED")
        }
    }
}
$swSurvs.Close()
$swObs.Close()

Write-Host "Running COBOL benchmark..."
Write-Host "CPU     : $((Get-CimInstance Win32_Processor).Name)"
Write-Host "Compiler: $((& cobc --version | Select-Object -First 1))"
& $BenchExe $StudyDir $OutDir $Bootstrap
exit $LASTEXITCODE
