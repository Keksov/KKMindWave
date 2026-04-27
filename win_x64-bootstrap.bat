@echo off
setlocal EnableExtensions DisableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
	echo [bootstrap] Error: failed to enter the script directory.
	exit /b 2
)

set "EXIT_CODE=0"
set "FPC_MODE=release"
set "FPC_MODE_USED=release"
set "SKIP_BUILD=0"
set "WORKSPACE_STATUS=not run"
set "FPC_STATUS=not run"
set "MINDWAVE_RUNTIME_STATUS=not run"
set "BODYMONITOR_NEUROSKY_STATUS=not run"
set "MINDWAVECORE_DEPS_STATUS=not run"
set "BODYMONITOR_BUILD_STATUS=not run"
set "GNAURAL_BUILD_STATUS=not run"

call :parse_args %*
if errorlevel 1 (
	set "EXIT_CODE=1"
	goto :done
)

if /I "%FPC_MODE%"=="source" set "FPC_MODE_USED=source"
if /I "%FPC_MODE%"=="any" set "FPC_MODE_USED=release pending fallback"

echo [bootstrap] Repo root: %CD%
echo [bootstrap] FPC mode: %FPC_MODE%
if "%SKIP_BUILD%"=="1" (
	echo [bootstrap] Product builds: skipped
) else (
	echo [bootstrap] Product builds: enabled
)

call :preflight
if errorlevel 1 (
	set "EXIT_CODE=2"
	goto :done
)

echo [bootstrap] Ensuring workspace repositories...
call ".\clone-workspace.bat"
if errorlevel 1 (
	set "WORKSPACE_STATUS=failed"
	set "EXIT_CODE=3"
	goto :done
)
set "WORKSPACE_STATUS=success"

call :run_fpc
if errorlevel 1 (
	set "FPC_STATUS=failed"
	set "EXIT_CODE=4"
	goto :done
)

echo [bootstrap] Preparing MindWave runtime DLLs...
call ".\VendorsCore\MindWave\scripts\win_sdk_download.bat"
if errorlevel 1 (
	set "MINDWAVE_RUNTIME_STATUS=failed"
	set "EXIT_CODE=5"
	goto :done
)
set "MINDWAVE_RUNTIME_STATUS=success"

call :run_bodymonitor_neurosky

echo [bootstrap] Initializing MindWaveCore dependencies...
call ".\MindWaveCore\server\init-dev.bat"
if errorlevel 1 (
	set "MINDWAVECORE_DEPS_STATUS=failed"
	set "EXIT_CODE=6"
	goto :done
)
set "MINDWAVECORE_DEPS_STATUS=success"

if "%SKIP_BUILD%"=="1" (
	set "BODYMONITOR_BUILD_STATUS=skipped"
	set "GNAURAL_BUILD_STATUS=skipped"
	goto :done
)

echo [bootstrap] Building BodyMonitorCore...
call ".\BodyMonitorCore\cli\build_x64.bat"
if errorlevel 1 (
	set "BODYMONITOR_BUILD_STATUS=failed"
	set "EXIT_CODE=7"
	goto :done
)
set "BODYMONITOR_BUILD_STATUS=success"

echo [bootstrap] Building GnauralCore...
call ".\GnauralCore\cli\build_x64.bat"
if errorlevel 1 (
	set "GNAURAL_BUILD_STATUS=failed"
	set "EXIT_CODE=8"
	goto :done
)
set "GNAURAL_BUILD_STATUS=success"

:done
call :print_summary
popd >nul
exit /b %EXIT_CODE%

:parse_args
if "%~1"=="" exit /b 0

if /I "%~1"=="--fpc-source" (
	if /I "%FPC_MODE%"=="any" goto :usage
	set "FPC_MODE=source"
	shift
	goto :parse_args
)

if /I "%~1"=="--fpc-any" (
	if /I "%FPC_MODE%"=="source" goto :usage
	set "FPC_MODE=any"
	shift
	goto :parse_args
)

if /I "%~1"=="--skip-build" (
	set "SKIP_BUILD=1"
	shift
	goto :parse_args
)

echo [bootstrap] Error: unknown argument %~1
goto :usage

:usage
echo Usage: win_x64-bootstrap.bat [--fpc-source ^| --fpc-any] [--skip-build]
echo.
echo   --fpc-source  Force the full FPC source build.
echo   --fpc-any     Try FPC release setup first, then fall back to source build.
echo   --skip-build  Skip BodyMonitorCore and GnauralCore product builds.
exit /b 1

:preflight
echo [bootstrap] Checking required tools...

where git >nul 2>nul
if errorlevel 1 (
	echo [bootstrap] Error: git was not found in PATH.
	echo [bootstrap] Install Git and retry.
	exit /b 1
)

where powershell >nul 2>nul
if errorlevel 1 (
	echo [bootstrap] Error: powershell was not found in PATH.
	echo [bootstrap] Install Windows PowerShell and retry.
	exit /b 1
)

exit /b 0

:run_fpc
if /I "%FPC_MODE%"=="source" goto :run_fpc_source
if /I "%FPC_MODE%"=="any" goto :run_fpc_any

echo [bootstrap] Preparing FPC via release setup...
call ".\VendorsCore\fpc\scripts\win_x64\fpc_release_setup.bat"
if errorlevel 1 exit /b 1

set "FPC_STATUS=success"
set "FPC_MODE_USED=release"
exit /b 0

:run_fpc_source
echo [bootstrap] WARNING: FPC source build selected. This may take 1-2 hours.
echo [bootstrap] Preparing FPC via source build...
call ".\VendorsCore\fpc\scripts\win_x64\fpc_main_build.bat"
if errorlevel 1 exit /b 1

set "FPC_STATUS=success"
set "FPC_MODE_USED=source"
exit /b 0

:run_fpc_any
echo [bootstrap] Preparing FPC via release setup...
call ".\VendorsCore\fpc\scripts\win_x64\fpc_release_setup.bat"
set "FPC_RELEASE_EXIT=%ERRORLEVEL%"
if "%FPC_RELEASE_EXIT%"=="0" (
	set "FPC_STATUS=success"
	set "FPC_MODE_USED=release (via --fpc-any)"
	exit /b 0
)

echo [bootstrap] Release setup failed with exit code %FPC_RELEASE_EXIT%. Falling back to source build.
echo [bootstrap] WARNING: FPC source build selected. This may take 1-2 hours.
call ".\VendorsCore\fpc\scripts\win_x64\fpc_main_build.bat"
if errorlevel 1 exit /b 1

set "FPC_STATUS=success"
set "FPC_MODE_USED=source fallback (via --fpc-any)"
exit /b 0

:run_bodymonitor_neurosky
echo [bootstrap] Attempting BodyMonitor NeuroSky source/import-lib setup...
powershell -NoProfile -ExecutionPolicy Bypass -File ".\BodyMonitorCore\scripts\setup-neurosky-sdk.ps1"
if errorlevel 1 (
	set "BODYMONITOR_NEUROSKY_STATUS=warning"
	echo [bootstrap] Warning: BodyMonitor NeuroSky source/import-lib setup failed.
	echo [bootstrap] Manual follow-up from the repo root:
	echo [bootstrap]   powershell -NoProfile -ExecutionPolicy Bypass -File ".\BodyMonitorCore\scripts\setup-neurosky-sdk.ps1" -SdkRoot "<path-to-Windows-Developer-Tools-3.2>"
	exit /b 0
)

set "BODYMONITOR_NEUROSKY_STATUS=success"
exit /b 0

:print_summary
echo.
echo [bootstrap] Summary
echo [bootstrap] Workspace repos: %WORKSPACE_STATUS%
echo [bootstrap] FPC: %FPC_STATUS% [%FPC_MODE_USED%]
echo [bootstrap] MindWave runtime: %MINDWAVE_RUNTIME_STATUS%
echo [bootstrap] BodyMonitor NeuroSky source: %BODYMONITOR_NEUROSKY_STATUS%
echo [bootstrap] MindWaveCore deps: %MINDWAVECORE_DEPS_STATUS%
echo [bootstrap] BodyMonitor build: %BODYMONITOR_BUILD_STATUS%
echo [bootstrap] Gnaural build: %GNAURAL_BUILD_STATUS%

if not "%EXIT_CODE%"=="0" (
	echo [bootstrap] Result: bootstrap failed.
	echo [bootstrap] Exit code: %EXIT_CODE%
	exit /b 0
)

if /I "%BODYMONITOR_NEUROSKY_STATUS%"=="warning" (
	if "%SKIP_BUILD%"=="1" (
		echo [bootstrap] Result: bootstrap completed with warnings. Product builds were skipped, and BodyMonitor NeuroSky source/import-lib setup still needs manual follow-up.
	) else (
		echo [bootstrap] Result: workspace is ready, but BodyMonitor NeuroSky source/import-lib setup still needs manual follow-up.
	)
	exit /b 0
)

if "%SKIP_BUILD%"=="1" (
	echo [bootstrap] Result: workspace bootstrap completed. Product builds were skipped by request.
) else (
	echo [bootstrap] Result: workspace is fully ready.
)

exit /b 0