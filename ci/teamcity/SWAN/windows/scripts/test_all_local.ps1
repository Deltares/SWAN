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

Write-Host "Starting test setup..."
if (-not (Test-Path $TestbedFolder)) { New-Item -ItemType Directory -Path $TestbedFolder | Out-Null }
Set-Location $TestbedFolder

if (Test-Path ".svn") {
    svn update --non-interactive --no-auth-cache --username "$env:SVN_USER_NAME" --password "$env:SVN_PASSWORD" .
} else {
    svn checkout --non-interactive  --no-auth-cache --username "$env:SVN_USER_NAME" --password "$env:SVN_PASSWORD" "$TestbedUrl" .
}
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Test-Path -Path ".venv" -PathType Container)) {
    uv venv --python 3.12
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

. ".\.venv\Scripts\Activate.ps1"
Get-Location
Get-ChildItem -Force .
uv pip sync ./pip/lnx-requirements.txt
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }


