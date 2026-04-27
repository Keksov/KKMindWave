@echo off
setlocal EnableExtensions EnableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
	echo [clone-workspace] Error: failed to enter the script directory.
	exit /b 2
)

set "EXIT_CODE=0"
set "MANIFEST=workspace-repos.txt"
set /a ENTRY_COUNT=0
set /a CLONED_COUNT=0
set /a SKIPPED_COUNT=0

call :preflight
if errorlevel 1 (
	set "EXIT_CODE=2"
	goto :done
)

for /f "usebackq eol=# tokens=1-3" %%A in ("%MANIFEST%") do (
	if not "%%~A"=="" (
		set /a ENTRY_COUNT+=1
		call :clone_repo "%%~A" "%%~B" "%%~C"
		if errorlevel 1 (
			set "EXIT_CODE=3"
			goto :done
		)
	)
)

if "!ENTRY_COUNT!"=="0" (
	echo [clone-workspace] Error: no repositories were found in "%MANIFEST%".
	set "EXIT_CODE=4"
	goto :done
)

:done
if "%EXIT_CODE%"=="0" (
	echo [clone-workspace] Summary: cloned !CLONED_COUNT! repositories, skipped !SKIPPED_COUNT! existing repositories.
) else (
	echo [clone-workspace] Summary: cloned !CLONED_COUNT! repositories, skipped !SKIPPED_COUNT! existing repositories, exit code %EXIT_CODE%.
)
popd >nul
exit /b %EXIT_CODE%

:preflight
where git >nul 2>nul
if errorlevel 1 (
	echo [clone-workspace] Error: git was not found in PATH.
	exit /b 1
)

if not exist "%MANIFEST%" (
	echo [clone-workspace] Error: manifest "%MANIFEST%" was not found.
	exit /b 1
)

exit /b 0

:clone_repo
set "REPO_NAME=%~1"
set "REPO_URL=%~2"
set "REPO_BRANCH=%~3"

if "%REPO_URL%"=="" (
	echo [clone-workspace] Error: manifest entry for "%REPO_NAME%" is missing the remote URL.
	exit /b 1
)

if exist "%REPO_NAME%\" (
	echo [clone-workspace] %REPO_NAME% already exists. Skipping clone.
	if not exist "%REPO_NAME%\.git" (
		echo [clone-workspace] Warning: %REPO_NAME% exists but is not obviously a git worktree.
	)
	set /a SKIPPED_COUNT+=1
	exit /b 0
)

echo [clone-workspace] Cloning %REPO_NAME%...
if "%REPO_BRANCH%"=="" (
	git clone "%REPO_URL%" "%REPO_NAME%"
) else (
	git clone --branch "%REPO_BRANCH%" --single-branch "%REPO_URL%" "%REPO_NAME%"
)
if errorlevel 1 (
	echo [clone-workspace] Error: failed to clone %REPO_NAME%.
	exit /b 1
)

set /a CLONED_COUNT+=1
exit /b 0