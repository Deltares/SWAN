@echo off
setlocal EnableExtensions

rem Local equivalent of the "Build All" step in ci\teamcity\SWAN\windows\build.kt.
rem Run this from the repository root inside the Windows build-tools container.
rem Usage: build_all_local.bat [build_type] [build_tag]

if not defined CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV (
	echo ERROR: CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV must be set. 1>&2
	exit /b 1
)

if not defined CONAN_PASSWORD_DELFT3D_CONAN_DEV (
	echo ERROR: CONAN_PASSWORD_DELFT3D_CONAN_DEV must be set. 1>&2
	exit /b 1
)

set "BUILD_TYPE=%~1"
if not defined BUILD_TYPE set "BUILD_TYPE=Release"

set "BUILD_TAG=%~2"
if not defined BUILD_TAG for /f "delims=" %%B in ('git branch --show-current') do set "BUILD_TAG=%%B"
if not defined BUILD_TAG (
	echo ERROR: A build tag could not be determined. 1>&2
	exit /b 1
)

set "ARCHIVE_NAME=swan_%BUILD_TAG%_x64"
set "ARCHIVE_PATH=build\%ARCHIVE_NAME%.zip"
set "STAGING_PATH=build\%ARCHIVE_NAME%"
set "NEXUS_ARTIFACT_URL=https://internal-artifacts.deltares.nl/repository/swan-dev/%BUILD_TAG%/x64/%ARCHIVE_NAME%.zip"

echo "================================="
echo "== Current build tag: %BUILD_TAG%"
echo "================================="


echo "== Source set-env.cmd ..."
call C:\set-env.cmd
if errorlevel 1 exit /b %errorlevel%

echo "== run_conan.py ..."
python run_conan.py initialize deltares --ci
if errorlevel 1 exit /b %errorlevel%

echo "== build OMP ..."
python build.py --build --build-type "%BUILD_TYPE%" --ci
if errorlevel 1 exit /b %errorlevel%

if exist artifacts rmdir /s /q artifacts
xcopy install artifacts /E /I /Y
if errorlevel 1 exit /b %errorlevel%

echo "== build MPI ..."
python build.py --mpi --build --build-type "%BUILD_TYPE%" --ci
if errorlevel 1 exit /b %errorlevel%
copy /Y install\bin\swan_mpi.exe artifacts\bin\
copy /Y install\lib\swan_mpi_lib.lib artifacts\lib\
if errorlevel 1 exit /b %errorlevel%

echo "== build timing ..."
python build.py --timing --build --build-type "%BUILD_TYPE%" --ci
if errorlevel 1 exit /b %errorlevel%
copy /Y install\bin\swan_omp_timing.exe artifacts\bin\
copy /Y install\lib\swan_omp_timing_lib.lib artifacts\lib\
if errorlevel 1 exit /b %errorlevel%

echo "== build double ..."
python build.py --double --build --build-type "%BUILD_TYPE%" --ci
if errorlevel 1 exit /b %errorlevel%
copy /Y install\bin\swan_omp_doubleprecision.exe artifacts\bin\
copy /Y install\lib\swan_omp_doubleprecision_lib.lib artifacts\lib\
if errorlevel 1 exit /b %errorlevel%

echo "== Collect artifacts ..."
if exist "%STAGING_PATH%" rmdir /s /q "%STAGING_PATH%"
if exist "%ARCHIVE_PATH%" del /q "%ARCHIVE_PATH%"
xcopy artifacts "%STAGING_PATH%" /E /I /Y
if errorlevel 1 exit /b %errorlevel%

tar.exe -a -c -f "%ARCHIVE_PATH%" -C build "%ARCHIVE_NAME%"
if errorlevel 1 exit /b %errorlevel%

echo "== Upload to Nexus ..."
curl.exe --fail --show-error --silent ^
	--user "%CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV%:%CONAN_PASSWORD_DELFT3D_CONAN_DEV%" ^
	--upload-file "%ARCHIVE_PATH%" ^
	"%NEXUS_ARTIFACT_URL%"
if errorlevel 1 exit /b %errorlevel%

echo "== ... build_all_local finished"
exit /b 0
