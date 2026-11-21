#Requires -Version 5.1
<#
.SYNOPSIS
    Build FIELDLEDGER native COBOL executable on Windows using GnuCOBOL.
.DESCRIPTION
    Locates GnuCOBOL (PATH or MSYS2 UCRT64/MinGW64), compiles all modular
    COBOL sources under src/ with -free -Wall -O2 -I copybooks, links
    build\fieldledger.exe, and stages MinGW runtime DLLs if needed.
#>
[CmdletBinding()]
param(
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BuildDir = Join-Path $RepoRoot "build"
$ObjDir   = Join-Path $BuildDir "obj"
$CopyDir  = Join-Path $RepoRoot "copybooks"
$SrcDir   = Join-Path $RepoRoot "src"
$ExePath  = Join-Path $BuildDir "fieldledger.exe"

if ($Clean -and (Test-Path $BuildDir)) {
    Remove-Item -Recurse -Force $BuildDir
}
New-Item -ItemType Directory -Force -Path $ObjDir | Out-Null

# Locate cobc compiler
$CobcCmd = Get-Command cobc -ErrorAction SilentlyContinue
$MsysPrefix = $null

if (-not $CobcCmd) {
    foreach ($candidate in @("C:\msys64\ucrt64", "C:\msys64\mingw64", "C:\GnuCOBOL")) {
        $probe = Join-Path $candidate "bin\cobc.exe"
        if (Test-Path $probe) {
            $env:PATH = (Join-Path $candidate "bin") + ";" + $env:PATH
            $CobcCmd = Get-Command cobc -ErrorAction SilentlyContinue
            if ($candidate -like "*msys64*") {
                $MsysPrefix = $candidate
            }
            break
        }
    }
} else {
    $cobcDir = Split-Path $CobcCmd.Source -Parent
    $parentDir = Split-Path $cobcDir -Parent
    if ($parentDir -like "*msys64*") {
        $MsysPrefix = $parentDir
    }
}

if (-not $CobcCmd) {
    Write-Error "GnuCOBOL (cobc.exe) not found in PATH or C:\msys64\ucrt64\bin. See docs/BUILD-INSTRUCTIONS.md."
    exit 1
}

if ($MsysPrefix) {
    $env:COB_CONFIG_DIR = Join-Path $MsysPrefix "share\gnucobol\config"
    $env:COB_COPY_DIR   = Join-Path $MsysPrefix "share\gnucobol\copy"
    $env:COB_CFLAGS     = "-I" + (Join-Path $MsysPrefix "include")
    $env:COB_LIBS       = "-L" + (Join-Path $MsysPrefix "lib") + " -lcob"
}

Write-Host "=== FIELDLEDGER Build (Windows / PowerShell) ==="
$verLine = (& cobc --version | Select-Object -First 1)
Write-Host "Compiler : $verLine"
Write-Host "Flags    : -free -Wall -O2 -I copybooks"
Write-Host "Output   : $ExePath"

$SubModules = @(
    "core\CONFIGURATION.cob",
    "core\ERROR-HANDLING.cob",
    "core\DATE-UTILS.cob",
    "core\NUMERIC-UTILS.cob",
    "core\COMMAND-PARSER.cob",
    "ingestion\RECORD-NORMALISER.cob",
    "ingestion\CSV-READER.cob",
    "ingestion\DATA-IMPORT.cob",
    "validation\VALIDATE-STUDY.cob",
    "validation\VALIDATE-SOURCES.cob",
    "validation\VALIDATE-SITES.cob",
    "validation\VALIDATE-SURVEYS.cob",
    "validation\VALIDATE-OBSERVATIONS.cob",
    "validation\DUPLICATE-DETECTION.cob",
    "ledger\EVIDENCE-LEDGER.cob",
    "ledger\RUN-RECEIPT.cob",
    "ecology\EFFORT-STANDARDISER.cob",
    "ecology\SPECIES-AGGREGATOR.cob",
    "ecology\SITE-SUMMARY.cob",
    "analysis\BOOTSTRAP-ENGINE.cob",
    "analysis\UNCERTAINTY-ENGINE.cob",
    "analysis\SENSITIVITY-ENGINE.cob",
    "analysis\BACI-ENGINE.cob",
    "reporting\CSV-REPORTER.cob",
    "reporting\JSON-REPORTER.cob",
    "reporting\MARKDOWN-REPORTER.cob",
    "reporting\HTML-REPORTER.cob"
)

$ObjFiles = New-Object System.Collections.Generic.List[string]
foreach ($rel in $SubModules) {
    $srcPath = Join-Path $SrcDir $rel
    $base    = [System.IO.Path]::GetFileNameWithoutExtension($srcPath)
    $objPath = Join-Path $ObjDir ($base + ".o")
    Write-Host "  [CC] $rel"
    & cobc -c -free -Wall -O2 -I $CopyDir -o $objPath $srcPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Compilation failed for $rel (exit $LASTEXITCODE)"
        exit $LASTEXITCODE
    }
    $ObjFiles.Add($objPath)
}

$MainSrc = Join-Path $SrcDir "main.cob"
Write-Host "  [LD] main.cob -> fieldledger.exe"
& cobc -x -free -Wall -O2 -I $CopyDir -o $ExePath $MainSrc @ObjFiles
if ($LASTEXITCODE -ne 0) {
    Write-Error "Link failed for fieldledger.exe (exit $LASTEXITCODE)"
    exit $LASTEXITCODE
}

# Stage MSYS2 runtime DLLs alongside build\fieldledger.exe so it runs without PATH changes
if ($MsysPrefix) {
    $binDir = Join-Path $MsysPrefix "bin"
    $dlls = @(
        "libcob-4.dll",
        "libgmp-10.dll",
        "libdb-6.2.dll",
        "libintl-8.dll",
        "libjson-c-5.dll",
        "libncursesw6.dll",
        "libwinpthread-1.dll",
        "libxml2-16.dll",
        "libiconv-2.dll",
        "zlib1.dll"
    )
    foreach ($dll in $dlls) {
        $srcDll = Join-Path $binDir $dll
        $dstDll = Join-Path $BuildDir $dll
        if (Test-Path $srcDll) {
            if (-not (Test-Path $dstDll) -or ((Get-Item $srcDll).Length -ne (Get-Item $dstDll).Length)) {
                Copy-Item -Force $srcDll $dstDll
            }
        }
    }
}

Write-Host "Build succeeded: $ExePath"
exit 0
