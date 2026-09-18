@echo off
setlocal EnableExtensions

rem Local equivalent of the OMP test step in ci\teamcity\SWAN\linux\build.kt.
rem Run this from the repository root in the Windows build-tools container.
rem Usage: test_all_local.bat <testbed-folder> <test-version> <ref-version>

if "%~3"=="" (
	echo Usage: %~nx0 ^<testbed-folder^> ^<test-version^> ^<ref-version^> 1>&2
	exit /b 1
)

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

set "TESTBED_FOLDER=%~f1"
set "TEST_VERSION=%~2"
set "REF_VERSION=%~3"
set "TESTBED_URL=https://repos.deltares.nl/repos/swan/testbed/trunk/"
set "ORIGINAL_DIR=%CD%"
set "VENV_DIR=%TESTBED_FOLDER%\.venv"
set "EXECUTABLE_ROOT=%TESTBED_FOLDER%\executables\swan"

echo Starting test setup...
if not exist "%TESTBED_FOLDER%" mkdir "%TESTBED_FOLDER%"
if errorlevel 1 exit /b %errorlevel%
cd /d "%TESTBED_FOLDER%"
if errorlevel 1 exit /b %errorlevel%

if exist ".svn" (
	svn update --non-interactive --no-auth-cache --username "%SVN_USER_NAME%" --password "%SVN_PASSWORD%" .
) else (
	svn checkout --no-auth-cache --username "%SVN_USER_NAME%" --password "%SVN_PASSWORD%"  "%TESTBED_URL%" .
)
exit /b 0
if errorlevel 1 exit /b %errorlevel%

if not exist "%VENV_DIR%" (
	uv venv --python 3.12
	if errorlevel 1 exit /b %errorlevel%
)
uv pip sync .\pip\win-requirements.txt
if errorlevel 1 exit /b %errorlevel%

call :download_and_extract "%TEST_VERSION%"
if errorlevel 1 exit /b %errorlevel%
call :download_and_extract "%REF_VERSION%"
if errorlevel 1 exit /b %errorlevel%

set "LOG_FILE=run_testbench_%TEST_VERSION%_x64_OMP.log"
set "OMP_NUM_THREADS=4"
set "NPROCESSES=1"


:download_and_extract
set "VERSION=%~1"
set "ARCHIVE_NAME=swan_%VERSION%_x64.zip"
set "ARCHIVE_PATH=%TEMP%\%ARCHIVE_NAME%"
set "EXTRACTION_DIR=%TEMP%\swan_%VERSION%_x64"
set "EXECUTABLE_DIR=%EXECUTABLE_ROOT%\%VERSION%\x64"
set "NEXUS_ARTIFACT_URL=https://internal-artifacts.deltares.nl/repository/swan-dev/%VERSION%/x64/%ARCHIVE_NAME%"

if not exist "%EXECUTABLE_DIR%" mkdir "%EXECUTABLE_DIR%"
if errorlevel 1 exit /b %errorlevel%
curl.exe --fail --show-error --silent --location --user "%CONAN_LOGIN_USERNAME_DELFT3D_CONAN_DEV%:%CONAN_PASSWORD_DELFT3D_CONAN_DEV%" "%NEXUS_ARTIFACT_URL%" --output "%ARCHIVE_PATH%"
if errorlevel 1 exit /b %errorlevel%
if exist "%EXTRACTION_DIR%" rmdir /s /q "%EXTRACTION_DIR%"
mkdir "%EXTRACTION_DIR%"
tar.exe -xf "%ARCHIVE_PATH%" -C "%EXTRACTION_DIR%"
if errorlevel 1 exit /b %errorlevel%
xcopy "%EXTRACTION_DIR%\swan_%VERSION%_x64\*" "%EXECUTABLE_DIR%\" /E /I /Y >nul
if errorlevel 1 exit /b %errorlevel%
del /q "%ARCHIVE_PATH%"
rmdir /s /q "%EXTRACTION_DIR%"

"%VENV_DIR%\Scripts\python.exe" run_testbench.py --prl omp --ref "%REF_VERSION%" --test "%TEST_VERSION%" --cases settings/archive/two_swan_cases.inp > "%LOG_FILE%" 2>&1
set "TEST_EXIT_CODE=%errorlevel%"
type "%LOG_FILE%"
echo End Tests

cd /d "%ORIGINAL_DIR%"
if exist test_results rmdir /s /q test_results
mkdir test_results
if exist "%TESTBED_FOLDER%\%LOG_FILE%" copy /Y "%TESTBED_FOLDER%\%LOG_FILE%" test_results\ >nul
if exist "%TESTBED_FOLDER%\stat_output" xcopy "%TESTBED_FOLDER%\stat_output" test_results\stat_output\ /E /I /Y >nul
if exist "%TESTBED_FOLDER%\swan_output" xcopy "%TESTBED_FOLDER%\swan_output" test_results\swan_output\ /E /I /Y >nul

exit /b %TEST_EXIT_CODE%
