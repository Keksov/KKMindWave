@echo off
setlocal EnableExtensions EnableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
	echo [pull-workspace] Error: failed to enter the script directory.
	exit /b 2
)

set "EXIT_CODE=0"
set "MANIFEST=workspace-repos.txt"
set /a REPO_COUNT=0
set /a ISSUE_COUNT=0
set /a PULL_COUNT=0

call :preflight
if errorlevel 1 (
	set "EXIT_CODE=2"
	goto :done
)

echo [pull-workspace] Running workspace preflight...
for /f "usebackq eol=# tokens=1-3" %%A in ("%MANIFEST%") do (
	if not "%%~A"=="" (
		set /a REPO_COUNT+=1
		call :preflight_repo "%%~A" "%%~B"
	)
)

if "!REPO_COUNT!"=="0" (
	echo [pull-workspace] Error: no repositories were found in "%MANIFEST%".
	set "EXIT_CODE=3"
	goto :done
)

if not "!ISSUE_COUNT!"=="0" (
	echo [pull-workspace] Preflight failed with !ISSUE_COUNT! issues. No pulls were performed.
	set "EXIT_CODE=1"
	goto :done
)

echo [pull-workspace] Preflight passed. Pulling repositories...
for /f "usebackq eol=# tokens=1-3" %%A in ("%MANIFEST%") do (
	if not "%%~A"=="" (
		call :pull_repo "%%~A"
		if errorlevel 1 (
			set "EXIT_CODE=4"
			goto :done
		)
	)
)

:done
if "%EXIT_CODE%"=="0" (
	echo [pull-workspace] Summary: pulled !PULL_COUNT! repositories.
) else (
	echo [pull-workspace] Summary: pulled !PULL_COUNT! repositories, exit code %EXIT_CODE%.
)
popd >nul
exit /b %EXIT_CODE%

:preflight
where git >nul 2>nul
if errorlevel 1 (
	echo [pull-workspace] Error: git was not found in PATH.
	exit /b 1
)

if not exist "%MANIFEST%" (
	echo [pull-workspace] Error: manifest "%MANIFEST%" was not found.
	exit /b 1
)

exit /b 0

:preflight_repo
set "REPO_NAME=%~1"
set "EXPECTED_URL=%~2"
set "CURRENT_BRANCH="
set "ACTUAL_URL="
set "UPSTREAM="
set "BEHIND="
set "AHEAD="

if not exist "%REPO_NAME%\" (
	call :report_issue "%REPO_NAME%" "missing directory"
	exit /b 0
)

git -C "%REPO_NAME%" rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
	call :report_issue "%REPO_NAME%" "directory exists but is not a git worktree"
	exit /b 0
)

for /f "delims=" %%I in ('git -C "%REPO_NAME%" symbolic-ref --quiet --short HEAD 2^>nul') do set "CURRENT_BRANCH=%%I"
if not defined CURRENT_BRANCH (
	call :report_issue "%REPO_NAME%" "repository is detached"
	exit /b 0
)

for /f "delims=" %%I in ('git -C "%REPO_NAME%" remote get-url origin 2^>nul') do set "ACTUAL_URL=%%I"
if not defined ACTUAL_URL (
	call :report_issue "%REPO_NAME%" "origin remote is missing"
	exit /b 0
)

if /I not "%EXPECTED_URL%"=="!ACTUAL_URL!" (
	call :report_issue "%REPO_NAME%" "origin URL does not match workspace-repos.txt"
	exit /b 0
)

for /f "delims=" %%I in ('git -C "%REPO_NAME%" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2^>nul') do set "UPSTREAM=%%I"
if not defined UPSTREAM (
	call :report_issue "%REPO_NAME%" "current branch has no upstream"
	exit /b 0
)

if /I not "!UPSTREAM:~0,7!"=="origin/" (
	call :report_issue "%REPO_NAME%" "current branch upstream is not on origin"
	exit /b 0
)

git -C "%REPO_NAME%" fetch --quiet origin >nul 2>nul
if errorlevel 1 (
	call :report_issue "%REPO_NAME%" "failed to fetch origin"
	exit /b 0
)

git -C "%REPO_NAME%" status --porcelain --untracked-files=normal | findstr /R "." >nul
if not errorlevel 1 (
	call :report_issue "%REPO_NAME%" "working tree is not clean"
	exit /b 0
)

for /f "tokens=1,2" %%I in ('git -C "%REPO_NAME%" rev-list --left-right --count "!UPSTREAM!...HEAD" 2^>nul') do (
	set "BEHIND=%%I"
	set "AHEAD=%%J"
)
if not defined AHEAD (
	call :report_issue "%REPO_NAME%" "failed to compare HEAD with upstream"
	exit /b 0
)

if not "!BEHIND!"=="0" if not "!AHEAD!"=="0" (
	call :report_issue "%REPO_NAME%" "branch has diverged from upstream"
	exit /b 0
)

echo [pull-workspace] OK: %REPO_NAME% (%CURRENT_BRANCH%).
exit /b 0

:pull_repo
set "REPO_NAME=%~1"
echo [pull-workspace] Pulling %REPO_NAME%...
git -C "%REPO_NAME%" pull --ff-only
if errorlevel 1 (
	echo [pull-workspace] Error: pull failed in %REPO_NAME%.
	exit /b 1
)

set /a PULL_COUNT+=1
exit /b 0

:report_issue
set /a ISSUE_COUNT+=1
echo [pull-workspace] ERROR: %~1 - %~2.
exit /b 0