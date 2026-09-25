@echo off
setlocal EnableExtensions

rem Runs the SWAN build inside the TeamCity Linux build image.
rem Usage: build_all_docker.bat [build_type] [container_tag] [repo_root] [build_tag]

if not defined CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV (
    echo ERROR: CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV must be set. 1>&2
    echo Set your Nexus credentials for the delft3d-conan-dev remote first. 1>&2
    exit /b 1
)

if not defined CONAN_PASSWORD_DELFT3D_CONAN_DEV (
    echo ERROR: CONAN_PASSWORD_DELFT3D_CONAN_DEV must be set. 1>&2
    echo Set your Nexus credentials for the delft3d-conan-dev remote first. 1>&2
    exit /b 1
)

if not defined DOCKER_REGISTRY_USERNAME (
    echo ERROR: DOCKER_REGISTRY_USERNAME must be set. 1>&2
    echo Set your containers.deltares.nl credentials first. 1>&2
    exit /b 1
)

if not defined DOCKER_REGISTRY_PASSWORD (
    echo ERROR: DOCKER_REGISTRY_PASSWORD must be set. 1>&2
    echo Set your containers.deltares.nl credentials first. 1>&2
    exit /b 1
)

set "BUILD_TYPE=%~1"
if not defined BUILD_TYPE set "BUILD_TYPE=Release"

set "CONTAINER_TAG=vs2022-intel2024-ltsc2025"

set "REPO_ROOT=%~2"
if not defined REPO_ROOT set "REPO_ROOT=%CD%"

set "BUILD_TAG=%~3"
if not defined BUILD_TAG for /f "delims=" %%B in ('git -C "%REPO_ROOT%" branch --show-current') do set "BUILD_TAG=%%B"

set "SCRIPT_ROOT=%~dp0"

docker run --rm ^
    --mount type=volume,source=swan-conan-cache,target=C:/conan-cache ^
    -e CONAN_HOME=C:/conan-cache ^
    -e CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV ^
    -e CONAN_PASSWORD_DELFT3D_CONAN_DEV ^
    -v "%REPO_ROOT%:c:\workspace" ^
    -v "%SCRIPT_ROOT%:c:\scripts" ^
    -w c:\workspace ^
    "containers.deltares.nl/swan-dev/swan-buildtools-windows:%CONTAINER_TAG%" ^
    "c:\scripts\SWAN\windows\scripts\build_all_local.bat" "%BUILD_TYPE%" "%BUILD_TAG%"


exit /b %ERRORLEVEL%
