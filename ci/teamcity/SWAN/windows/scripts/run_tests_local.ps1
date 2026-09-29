# Local equivalent of the OMP test step in ci\teamcity\SWAN\linux\build.kt.
# Run this from the repository root in the Windows build-tools container.
# Usage: test_all_local.ps1 <testbed-folder> <test-version> <ref-version>

param(
    [Parameter(Mandatory = $true)] [string]$TestbedFolder,
    [Parameter(Mandatory = $true)] [string]$TestVersion,
    [Parameter(Mandatory = $true)] [string]$RefVersion
)

$ErrorActionPreference = 'Stop'

if (-not $env:SVN_USER_NAME) {
    Write-Error "SVN_USER_NAME must be set."
    exit 1
}

if (-not $env:SVN_PASSWORD) {
    Write-Error "SVN_PASSWORD must be set."
    exit 1
}

if (-not $env:CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV) {
    Write-Error "CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV must be set."
    exit 1
}

if (-not $env:CONAN_PASSWORD_DELFT3D_CONAN_DEV) {
    Write-Error "CONAN_PASSWORD_DELFT3D_CONAN_DEV must be set."
    exit 1
}

$TestbedFolder = (Resolve-Path -LiteralPath $TestbedFolder -ErrorAction SilentlyContinue).Path
if (-not $TestbedFolder) { $TestbedFolder = $PSBoundParameters['TestbedFolder'] }
$TestbedUrl = "https://repos.deltares.nl/repos/swan/testbed/trunk/"
$OriginalDir = (Get-Location).Path
$VenvDir = Join-Path $TestbedFolder ".venv"
$ExecutableRoot = Join-Path $TestbedFolder "executables\swan"

Write-Host "== Starting test setup..."
if (-not (Test-Path $TestbedFolder)) { New-Item -ItemType Directory -Path $TestbedFolder | Out-Null }
Set-Location $TestbedFolder

Write-Host "== Clean output folders ..."
Get-ChildItem -Path $TestbedFolder -Filter "run_testbench_*.log" -File |
    Remove-Item -Force -ErrorAction SilentlyContinue
Get-ChildItem -Path (Join-Path $TestbedFolder "analyse_output") -Force -ErrorAction SilentlyContinue |
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
Get-ChildItem -Path (Join-Path $TestbedFolder "analyse_timings") -Force -ErrorAction SilentlyContinue |
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
Get-ChildItem -Path (Join-Path $TestbedFolder "plot_output") -Force -ErrorAction SilentlyContinue |
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
Get-ChildItem -Path (Join-Path $TestbedFolder "stat_output") -Force -ErrorAction SilentlyContinue |
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
Get-ChildItem -Path (Join-Path $TestbedFolder "swan_output") -Force -ErrorAction SilentlyContinue |
    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue


if (Test-Path ".svn") {
    Write-Host "== SVN update ..."
    svn cleanup .
    svn update --non-interactive --no-auth-cache --username "$env:SVN_USER_NAME" --password "$env:SVN_PASSWORD" .
} else {
    Write-Host "== SVN checkout ..."
    svn checkout --non-interactive  --no-auth-cache --username "$env:SVN_USER_NAME" --password "$env:SVN_PASSWORD" "$TestbedUrl" .
}
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Test-Path -Path ".venv" -PathType Container)) {
    Write-Host "== Create venv ..."
    uv venv --python 3.12
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

. ".\.venv\Scripts\Activate.ps1"

Write-Host "== Update venv ..."
uv pip sync ./pip/win-requirements.txt
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ArchivePlatform = "x64"
foreach ($Version in @($TestVersion, $RefVersion)) {
    $ExecutableDir = Join-Path $ExecutableRoot "$Version\$ArchivePlatform"
    $ArchiveName = "swan_${Version}_${ArchivePlatform}.zip"
    $ExtractionDir = Join-Path $env:TEMP "swan_${Version}_${ArchivePlatform}"
    $ArchivePath = Join-Path $env:TEMP $ArchiveName
    $ArchiveUrl = "https://internal-artifacts.deltares.nl/repository/swan-dev/$Version/$ArchivePlatform/$ArchiveName"
    Write-Host "Downloading archive from $ArchiveUrl"
    New-Item -ItemType Directory -Force -Path $ExecutableDir | Out-Null
    curl.exe --fail --show-error --silent --location `
        --user "${env:CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV}:${env:CONAN_PASSWORD_DELFT3D_CONAN_DEV}" `
        $ArchiveUrl `
        --output $ArchivePath
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $ExtractionDir
    New-Item -ItemType Directory -Force -Path $ExtractionDir | Out-Null
    Expand-Archive -Path $ArchivePath -DestinationPath $ExtractionDir -Force
    $SourceDir = Join-Path $ExtractionDir "swan_${Version}_${ArchivePlatform}"
    Get-ChildItem -Path $SourceDir -Force -ErrorAction SilentlyContinue |
        Copy-Item -Destination $ExecutableDir -Recurse -Force
    Remove-Item -Recurse -Force $ArchivePath, $ExtractionDir
}

$LogFile = "run_testbench_${TestVersion}_${ArchivePlatform}_OMP.log"

Write-Host "== Run testbench OMP ..."
& ".\.venv\Scripts\python.exe" run_testbench.py --prl omp --ref $RefVersion --test $TestVersion --cases settings/templates/OMP_DELTARES_swan_cases.inp 2>&1 |
    Tee-Object -FilePath $LogFile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "== Collect artifacts ..."
Set-Location $OriginalDir
if (Test-Path "test_results") { Remove-Item -Recurse -Force "test_results" }
New-Item -ItemType Directory -Force -Path "test_results" | Out-Null

foreach ($Item in @(
    (Join-Path $TestbedFolder $LogFile),
    (Join-Path $TestbedFolder "analyse_output"),
    (Join-Path $TestbedFolder "analyse_timings"),
    (Join-Path $TestbedFolder "plot_output"),
    (Join-Path $TestbedFolder "stat_output")
)) {
    if (Test-Path $Item) {
        Copy-Item -Path $Item -Destination "test_results" -Force -Recurse -ErrorAction SilentlyContinue
    }
}

Get-ChildItem -Path (Join-Path $TestbedFolder "swan_output") -Filter "*.log" -File -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object {
        Copy-Item -Path $_.FullName -Destination "test_results" -Force -ErrorAction SilentlyContinue
    }

Write-Host "== ... run_tests_local finished"
