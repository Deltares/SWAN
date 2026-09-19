@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Runs the SWAN OMP test inside the Windows build image.
rem Usage: test_docker.bat <test-version> [ref-version] [repo-root] [container-tag]
rem        test_docker.bat shell [repo-root] [container-tag]
rem   The "shell" form drops you into an interactive PowerShell session in the
rem   container (same env vars/mounts) instead of running test_all_local.bat.

if not defined SVN_USER_NAME (
    echo ERROR: SVN_USER_NAME must be set. 1>&2
    exit /b 1
)

if not defined SVN_PASSWORD (
    echo ERROR: SVN_PASSWORD must be set. 1>&2
    exit /b 1
)

if not defined CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV (
    echo ERROR: CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV must be set. 1>&2
    exit /b 1
)

if not defined CONAN_PASSWORD_DELFT3D_CONAN_DEV (
    echo ERROR: CONAN_PASSWORD_DELFT3D_CONAN_DEV must be set. 1>&2
    exit /b 1
)

set "MODE=%~1"
if /i "%MODE%"=="shell" (
    set "REPO_ROOT=%~2"
    if not defined REPO_ROOT set "REPO_ROOT=%CD%"

    set "CONTAINER_TAG=%~3"
    if not defined CONTAINER_TAG set "CONTAINER_TAG=vs2022-intel2024-ltsc2025"

    set "SCRIPT_ROOT=%~dp0SWAN\windows\scripts"

    docker run --rm -it ^
        -e SVN_USER_NAME ^
        -e SVN_PASSWORD ^
        -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV ^
        -e CONAN_PASSWORD_DELFT3D_CONAN_DEV ^
        -v "!REPO_ROOT!:C:/workspace" ^
        -v "!SCRIPT_ROOT!:C:/scripts" ^
        -w C:/workspace ^
        "containers.deltares.nl/swan-dev/swan-buildtools-windows:!CONTAINER_TAG!" ^
        powershell -NoExit -Command "Write-Host 'Interactive shell ready. Scripts are in C:\scripts, workspace mounted at C:\workspace.'"

    exit /b !ERRORLEVEL!
)

set "TEST_VERSION=%~1"
if not defined TEST_VERSION (
    echo Usage: %~nx0 ^<test-version^> [ref-version] [repo-root] [container-tag] 1>&2
    echo    or: %~nx0 shell [repo-root] [container-tag] 1>&2
    exit /b 1
)

set "REF_VERSION=%~2"
if not defined REF_VERSION set "REF_VERSION=41.51.9CONAN"

set "REPO_ROOT=%~3"
if not defined REPO_ROOT set "REPO_ROOT=%CD%"

set "CONTAINER_TAG=%~4"
if not defined CONTAINER_TAG set "CONTAINER_TAG=vs2022-intel2024-ltsc2025"

set "SCRIPT_ROOT=%~dp0SWAN\windows\scripts"

docker run --rm ^
    -e SVN_USER_NAME ^
    -e SVN_PASSWORD ^
    -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV ^
    -e CONAN_PASSWORD_DELFT3D_CONAN_DEV ^
    -v "%REPO_ROOT%:C:/workspace" ^
    -v "%SCRIPT_ROOT%:C:/scripts" ^
    -w C:/workspace ^
    "containers.deltares.nl/swan-dev/swan-buildtools-windows:%CONTAINER_TAG%" ^
    powershell -NoProfile -ExecutionPolicy Bypass -File C:\scripts\test_all_local.ps1 C:\workspace "%TEST_VERSION%" "%REF_VERSION%"

exit /b %ERRORLEVEL%