#Requires -Version 5.1
<#
.SYNOPSIS
    Automated FIELDLEDGER test suite (Unit, Integration, Statistical, Regression).
.DESCRIPTION
    1. Builds FIELDLEDGER (if not already built or if -Rebuild specified).
    2. Compiles and runs native COBOL unit tests (tests\unit\UNIT-TESTS.cob).
    3. Executes integration, validation-rejection, statistical, regression,
       provenance/manifest-tamper, receipt-verification, and escaping tests.
#>
[CmdletBinding()]
param(
    [switch]$Rebuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BuildDir = Join-Path $RepoRoot "build"
$ObjDir   = Join-Path $BuildDir "obj"
$ExePath  = Join-Path $BuildDir "fieldledger.exe"
$UnitExe  = Join-Path $BuildDir "unit-tests.exe"
$TmpOut   = Join-Path $RepoRoot "output\test-runs"

if ($Rebuild -or -not (Test-Path $ExePath)) {
    & (Join-Path $PSScriptRoot "build.ps1")
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (Test-Path $TmpOut) {
    Remove-Item -Recurse -Force $TmpOut
}
New-Item -ItemType Directory -Force -Path $TmpOut | Out-Null

# Locate cobc for compiling native COBOL unit test harness
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

$script:Passed = 0
$script:Failed = 0

function Assert-Test([string]$Name, [bool]$Condition, [string]$Detail = "") {
    if ($Condition) {
        $script:Passed++
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:Failed++
        Write-Host "  [FAIL] $Name :: $Detail" -ForegroundColor Red
    }
}

function Invoke-FL([string[]]$ArgsList) {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $out = & $ExePath @ArgsList 2>&1 | Out-String
        return @{ Code = $LASTEXITCODE; Output = $out }
    } finally {
        $ErrorActionPreference = $prev
    }
}

Write-Host "====================================================================="
Write-Host " 1. NATIVE COBOL UNIT TESTS"
Write-Host "====================================================================="
$UnitObjs = @(
    "CONFIGURATION.o", "ERROR-HANDLING.o", "DATE-UTILS.o", "NUMERIC-UTILS.o",
    "RECORD-NORMALISER.o", "CSV-READER.o", "EFFORT-STANDARDISER.o",
    "BOOTSTRAP-ENGINE.o", "UNCERTAINTY-ENGINE.o", "SENSITIVITY-ENGINE.o"
) | ForEach-Object { Join-Path $ObjDir $_ }

$UnitSrc = Join-Path $RepoRoot "tests\unit\UNIT-TESTS.cob"
$needUnitBuild = $Rebuild -or (-not (Test-Path $UnitExe)) -or ((Get-Item $UnitSrc).LastWriteTimeUtc -gt (Get-Item $UnitExe).LastWriteTimeUtc)
$unitCompileRc = 0
if ($needUnitBuild) {
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & cobc -x -free -Wall -O2 -I (Join-Path $RepoRoot "copybooks") `
        -o $UnitExe $UnitSrc @UnitObjs
    $unitCompileRc = $LASTEXITCODE
    $ErrorActionPreference = $prevEap
}
Assert-Test "Compile native COBOL unit tests" ($unitCompileRc -eq 0) "cobc exit $unitCompileRc"

if ($unitCompileRc -eq 0) {
    & $UnitExe
    Assert-Test "All native COBOL unit assertions pass" ($LASTEXITCODE -eq 0) "unit-tests exit $LASTEXITCODE"
}

Write-Host ""
Write-Host "====================================================================="
Write-Host " 2. CLI, INIT, DEMO, AND REGRESSION TESTS"
Write-Host "====================================================================="

# Help & version
$helpOut = & $ExePath help 2>&1 | Out-String
Assert-Test "CLI help displays commands and limitations" (($LASTEXITCODE -eq 0) -and ($helpOut -match "SCIENTIFIC LIMITATIONS"))

# Invalid CLI flag rejected with non-zero exit
$null = & $ExePath analyze baci --study "examples\wetland-demo" --out "$TmpOut\badcli" --bogus 2>&1
Assert-Test "CLI rejects unknown option with non-zero exit" ($LASTEXITCODE -ne 0) "exit=$LASTEXITCODE"

# Out-of-range bootstrap rejected
$null = & $ExePath analyze baci --study "examples\wetland-demo" --out "$TmpOut\badboot" --bootstrap 50 2>&1
Assert-Test "CLI rejects --bootstrap < 100" ($LASTEXITCODE -ne 0) "exit=$LASTEXITCODE"

# Init with spaces in path and from different CWD
$spaceStudy = Join-Path $TmpOut "study with spaces"
Push-Location $env:TEMP
try {
    $null = & $ExePath init --study $spaceStudy 2>&1
    $initRc = $LASTEXITCODE
} finally {
    Pop-Location
}
Assert-Test "Init works with spaces in path from non-repo CWD" (
    ($initRc -eq 0) -and
    (Test-Path (Join-Path $spaceStudy "study.csv")) -and
    (Test-Path (Join-Path $spaceStudy "observations.csv"))
) "exit=$initRc"

# Reference regression test: examples/wetland-demo -> exact BACI = +6.000000
$refOut = Join-Path $TmpOut "wetland-ref"
$null = & $ExePath analyze baci --study (Join-Path $RepoRoot "examples\wetland-demo") --out $refOut --seed 20261120 --bootstrap 2000 2>&1
$refRc = $LASTEXITCODE
$refCsv = @(Import-Csv (Join-Path $refOut "baci-results.csv"))
Assert-Test "Regression: wetland-demo exit=0" ($refRc -eq 0) "exit=$refRc"
Assert-Test "Regression: wetland-demo impact_change=+8.000000, control_change=+2.000000, BACI=+6.000000" (
    $refCsv.Count -eq 1 -and
    $refCsv[0].impact_change -eq "8.000000" -and
    $refCsv[0].control_change -eq "2.000000" -and
    $refCsv[0].baci_estimate -eq "6.000000"
) "got imp=$($refCsv[0].impact_change) ctrl=$($refCsv[0].control_change) baci=$($refCsv[0].baci_estimate)"
Assert-Test "Regression: small-sample (<5 sites) CI strictly WITHHELD with NA bounds" (
    $refCsv[0].ci_status -eq "WITHHELD" -and
    $refCsv[0].ci_95_low -eq "NA" -and
    $refCsv[0].ci_95_high -eq "NA"
) "got ci_status=$($refCsv[0].ci_status)"

# Verify research-receipt.json is valid JSON and report files exist
$refReceipt = Get-Content (Join-Path $refOut "research-receipt.json") -Raw | ConvertFrom-Json
Assert-Test "JSON receipt valid and matches study_001" (
    $refReceipt.application -eq "FIELDLEDGER" -and
    $refReceipt.study_id -eq "study_001" -and
    $refReceipt.baci_summary[0].baci_estimate -eq 6.0 -and
    $null -eq $refReceipt.baci_summary[0].ci_95_low
)
$refHtml = Get-Content (Join-Path $refOut "report.html") -Raw
Assert-Test "HTML report self-contained (zero http/cdn script/link tags)" (
    ($refHtml -notmatch "<script[^>]+src=") -and
    ($refHtml -notmatch "https?://cdn") -and
    ($refHtml -match "<svg") -and
    ($refHtml -match "6\.000000")
)
$refMd = Get-Content (Join-Path $refOut "report.md") -Raw
Assert-Test "Markdown report includes methodology and scientific limitations" (
    ($refMd -match "Transparent Calculation Methodology") -and
    ($refMd -match "Scientific Limitations") -and
    ($refMd -match "6\.000000")
)

# Demo command end-to-end
$demoOut = Join-Path $TmpOut "demo-e2e"
$null = & $ExePath demo --out $demoOut 2>&1
Assert-Test "Demo command creates dataset, validates, analyzes, reports" (
    ($LASTEXITCODE -eq 0) -and
    (Test-Path (Join-Path $demoOut "baci-results.csv")) -and
    (Test-Path (Join-Path $demoOut "report.html"))
)

Write-Host ""
Write-Host "====================================================================="
Write-Host " 3. STATISTICAL CORRECTNESS TESTS"
Write-Host "====================================================================="

# S1: Missing vs explicit zero
$mvzOut = Join-Path $TmpOut "missing-vs-zero"
$null = & $ExePath analyze baci --study (Join-Path $RepoRoot "tests\fixtures\missing-vs-zero") --out $mvzOut 2>&1
$mvzCsv = @(Import-Csv (Join-Path $mvzOut "baci-results.csv"))
$spZero = $mvzCsv | Where-Object { $_.species_code -eq "SP_ZERO" }
$spMiss = $mvzCsv | Where-Object { $_.species_code -eq "SP_MISS" }
Assert-Test "Statistical: explicit NOT_DETECTED zero included in mean (SP_ZERO BACI=6.000000)" (
    $spZero.baci_estimate -eq "6.000000" -and
    $spZero.explicit_zero_observations -eq "1" -and
    $spZero.missing_observations -eq "0"
) "got baci=$($spZero.baci_estimate) zero=$($spZero.explicit_zero_observations)"
Assert-Test "Statistical: missing row NOT converted to zero (SP_MISS BACI=3.000000, missing=1)" (
    $spMiss.baci_estimate -eq "3.000000" -and
    $spMiss.missing_observations -eq "1" -and
    $spMiss.coverage_pct -eq "88.89"
) "got baci=$($spMiss.baci_estimate) miss=$($spMiss.missing_observations) cov=$($spMiss.coverage_pct)"

# S2: Equal-site weighting + effort standardisation (30 min & 120 min)
$uneqOut = Join-Path $TmpOut "unequal-surveys"
$null = & $ExePath analyze baci --study (Join-Path $RepoRoot "tests\fixtures\unequal-surveys") --out $uneqOut 2>&1
$uneqCsv = @(Import-Csv (Join-Path $uneqOut "baci-results.csv"))
Assert-Test "Statistical: equal-site weighting & 30m/120m effort rate (BACI=8.000000, not survey-weighted 14)" (
    $uneqCsv[0].impact_change -eq "10.000000" -and
    $uneqCsv[0].control_change -eq "2.000000" -and
    $uneqCsv[0].baci_estimate -eq "8.000000"
) "got imp=$($uneqCsv[0].impact_change) baci=$($uneqCsv[0].baci_estimate)"

# S3: Zero BACI, Negative BACI, and TRANSITION exclusion
$znOut = Join-Path $TmpOut "baci-zero-and-neg"
$null = & $ExePath analyze baci --study (Join-Path $RepoRoot "tests\fixtures\baci-zero-and-neg") --out $znOut 2>&1
$znCsv = @(Import-Csv (Join-Path $znOut "baci-results.csv"))
$spZeroEff = $znCsv | Where-Object { $_.species_code -eq "SP_ZERO_EFF" }
$spNegEff  = $znCsv | Where-Object { $_.species_code -eq "SP_NEG_EFF" }
Assert-Test "Statistical: equal impact/control change yields BACI=0.000000 (TRANSITION excluded)" (
    $spZeroEff.baci_estimate -eq "0.000000" -and
    $spZeroEff.transition_excluded_observations -eq "1"
) "got baci=$($spZeroEff.baci_estimate) trans=$($spZeroEff.transition_excluded_observations)"
Assert-Test "Statistical: larger control gain yields negative BACI=-5.000000" (
    $spNegEff.baci_estimate -eq "-5.000000" -and
    $spNegEff.transition_excluded_observations -eq "1"
) "got baci=$($spNegEff.baci_estimate)"

# S4: Site-cluster bootstrap >= 5 sites per group & exact seed reproducibility
$bootOut1 = Join-Path $TmpOut "boot-run1"
$bootOut2 = Join-Path $TmpOut "boot-run2"
$null = & $ExePath analyze baci --study (Join-Path $RepoRoot "tests\fixtures\bootstrap-large") --out $bootOut1 --seed 20261120 --bootstrap 2000 2>&1
$null = & $ExePath analyze baci --study (Join-Path $RepoRoot "tests\fixtures\bootstrap-large") --out $bootOut2 --seed 20261120 --bootstrap 2000 2>&1
$b1 = @(Import-Csv (Join-Path $bootOut1 "baci-results.csv"))[0]
$b2 = @(Import-Csv (Join-Path $bootOut2 "baci-results.csv"))[0]
Assert-Test "Statistical: 6+6 sites reports 95% site-cluster bootstrap CI" (
    $b1.ci_status -eq "REPORTED" -and
    $b1.bootstrap_replicates -eq "2000" -and
    [double]$b1.ci_95_low -lt [double]$b1.baci_estimate -and
    [double]$b1.ci_95_high -gt [double]$b1.baci_estimate
) "got status=$($b1.ci_status) CI=[$($b1.ci_95_low), $($b1.ci_95_high)]"
Assert-Test "Statistical: identical seed yields identical bootstrap CI bounds" (
    $b1.ci_95_low -eq $b2.ci_95_low -and $b1.ci_95_high -eq $b2.ci_95_high
) "run1=[$($b1.ci_95_low),$($b1.ci_95_high)] run2=[$($b2.ci_95_low),$($b2.ci_95_high)]"

# S5: Multiple methods NOT silently pooled
$mmOut = Join-Path $TmpOut "multi-method"
$null = & $ExePath analyze baci --study (Join-Path $RepoRoot "tests\fixtures\multi-method") --out $mmOut 2>&1
$mmCsv = @(Import-Csv (Join-Path $mmOut "baci-results.csv"))
$mmPt = $mmCsv | Where-Object { $_.method -eq "point_count" }
$mmAc = $mmCsv | Where-Object { $_.method -eq "acoustic_recorder" }
Assert-Test "Statistical: multiple methods stratified separately (never pooled)" (
    $mmCsv.Count -eq 2 -and
    $mmPt.baci_estimate -eq "6.000000" -and
    $mmAc.baci_estimate -eq "10.000000"
) "rows=$($mmCsv.Count)"

$mmFiltOut = Join-Path $TmpOut "multi-method-filt"
$null = & $ExePath analyze baci --study (Join-Path $RepoRoot "tests\fixtures\multi-method") --out $mmFiltOut --method point_count 2>&1
$mmFiltCsv = @(Import-Csv (Join-Path $mmFiltOut "baci-results.csv"))
Assert-Test "Statistical: --method point_count selects single method cleanly" (
    $mmFiltCsv.Count -eq 1 -and $mmFiltCsv[0].method -eq "point_count" -and $mmFiltCsv[0].baci_estimate -eq "6.000000"
)

# S6: Insufficient PRE & Insufficient Control sites -> NOT calculable, explicit exclusion
$npOut = Join-Path $TmpOut "insufficient-pre"
$null = & $ExePath analyze baci --study (Join-Path $RepoRoot "tests\fixtures\insufficient-pre") --out $npOut 2>&1
$npCsv = @(Import-Csv (Join-Path $npOut "baci-results.csv"))
$npSites = @(Import-Csv (Join-Path $npOut "site-summaries.csv"))
Assert-Test "Edge case: insufficient PRE marks site NO_PRE_OBSERVATIONS and BACI=NA" (
    $npCsv[0].calculable -eq "N" -and $npCsv[0].baci_estimate -eq "NA" -and
    (($npSites | Where-Object { $_.site_id -eq "IMP01" }).status -eq "NO_PRE_OBSERVATIONS")
)

$ncOut = Join-Path $TmpOut "insufficient-control"
$null = & $ExePath analyze baci --study (Join-Path $RepoRoot "tests\fixtures\insufficient-control") --out $ncOut 2>&1
$ncCsv = @(Import-Csv (Join-Path $ncOut "baci-results.csv"))
Assert-Test "Edge case: insufficient CONTROL sites marks BACI=NA with warning" (
    $ncCsv[0].calculable -eq "N" -and $ncCsv[0].baci_estimate -eq "NA" -and
    ($ncCsv[0].warnings -match "INSUFFICIENT_COMPLETE_CONTROL_SITES")
)

Write-Host ""
Write-Host "====================================================================="
Write-Host " 4. VALIDATION REJECTION, ESCAPING, AND INTEGRITY TESTS"
Write-Host "====================================================================="

$badCases = @{
    "invalid-duplicate" = "DUPLICATE_SURVEY_SPECIES"
    "invalid-fk"        = "FK_SITE_NOT_FOUND"
    "invalid-date"      = "INVALID_DATE"
    "invalid-status"    = "STATUS_COUNT_MISMATCH"
    "invalid-csv"       = "CSV_MALFORMED"
}
foreach ($bad in @("invalid-duplicate", "invalid-fk", "invalid-date", "invalid-status", "invalid-csv")) {
    $badOut = Join-Path $TmpOut $bad
    $null = & $ExePath analyze baci --study (Join-Path $RepoRoot "tests\fixtures\$bad") --out $badOut 2>&1
    $badRc = $LASTEXITCODE
    $valCsvPath = Join-Path $badOut "validation-report.csv"
    $valCsvExists = Test-Path $valCsvPath
    $baciCsvExists = Test-Path (Join-Path $badOut "baci-results.csv")
    $expectedCode = $badCases[$bad]
    $hasExpectedCode = $valCsvExists -and ((Get-Content $valCsvPath -Raw) -match $expectedCode)
    Assert-Test "Validation rejects '$bad' ($expectedCode) and blocks BACI output" (
        ($badRc -eq 2) -and $hasExpectedCode -and (-not $baciCsvExists)
    ) "rc=$badRc hasCode=$hasExpectedCode baciCsv=$baciCsvExists"
}

# Special characters RFC 4180 CSV + JSON + HTML escaping
$escOut = Join-Path $TmpOut "special-chars"
$null = & $ExePath analyze baci --study (Join-Path $RepoRoot "tests\fixtures\special-chars") --out $escOut 2>&1
$escRc = $LASTEXITCODE
$escJsonOk = $false
try {
    $ej = Get-Content (Join-Path $escOut "research-receipt.json") -Raw | ConvertFrom-Json
    $escJsonOk = ($ej.study_id -eq "study_esc")
} catch { $escJsonOk = $false }
$escHtml = Get-Content (Join-Path $escOut "report.html") -Raw
Assert-Test "RFC 4180 quotes/commas, JSON escaping, and HTML <script> escaping" (
    ($escRc -eq 0) -and $escJsonOk -and
    ($escHtml -notmatch "<script>alert") -and
    ($escHtml -match "&lt;script&gt;alert")
) "rc=$escRc jsonOk=$escJsonOk"

# Manifest generation, verification, tamper detection, corrupted manifest detection
$manStudy = Join-Path $TmpOut "manifest-test"
Copy-Item -Recurse -Force (Join-Path $RepoRoot "examples\wetland-demo") $manStudy
$null = & $ExePath manifest --study $manStudy 2>&1
Assert-Test "Integrity: manifest generates manifest.sha256" (($LASTEXITCODE -eq 0) -and (Test-Path (Join-Path $manStudy "manifest.sha256")))
$null = & $ExePath verify --study $manStudy 2>&1
Assert-Test "Integrity: verify passes on unmodified dataset" ($LASTEXITCODE -eq 0)

# Modify one source file -> verify MUST fail
Add-Content -Path (Join-Path $manStudy "observations.csv") -Value "OBS999,SRV001,SP002,1,DETECTED"
$vMod = Invoke-FL @("verify", "--study", $manStudy)
Assert-Test "Integrity: verify FAILS when source file is modified" ($vMod.Code -ne 0) "exit=$($vMod.Code)"

# Corrupted manifest file -> verify MUST fail
Set-Content -Path (Join-Path $manStudy "manifest.sha256") -Value "NOT A VALID MANIFEST"
$vCor = Invoke-FL @("verify", "--study", $manStudy)
Assert-Test "Integrity: verify FAILS on corrupted manifest file" ($vCor.Code -ne 0) "exit=$($vCor.Code)"

# Report command: succeeds on matching study, rejects mismatched study
$rOk = Invoke-FL @("report", "--study", (Join-Path $RepoRoot "examples\wetland-demo"), "--out", $refOut)
Assert-Test "Report: regenerates from verified matching receipt" ($rOk.Code -eq 0) "exit=$($rOk.Code)"
$rBad = Invoke-FL @("report", "--study", (Join-Path $RepoRoot "tests\fixtures\missing-vs-zero"), "--out", $refOut)
Assert-Test "Report: rejects mismatched study_id vs research-receipt.json" ($rBad.Code -ne 0) "exit=$($rBad.Code)"

# Append-only evidence ledger check (second run appends rather than overwriting)
$null = & $ExePath validate --study (Join-Path $RepoRoot "examples\wetland-demo") --out $refOut 2>&1
$ledgerRows = @(Import-Csv (Join-Path $refOut "evidence-ledger.csv"))
Assert-Test "Ledger: evidence-ledger.csv preserves append-only multi-run history" ($ledgerRows.Count -ge 2) "rows=$($ledgerRows.Count)"

Write-Host ""
Write-Host "====================================================================="
Write-Host " SUMMARY: $($script:Passed) passed, $($script:Failed) failed"
Write-Host "====================================================================="
if ($script:Failed -gt 0) {
    exit 1
}
exit 0
