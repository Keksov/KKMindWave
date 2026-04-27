@echo off
setlocal EnableExtensions EnableDelayedExpansion

pushd "%~dp0" >nul
if errorlevel 1 (
	echo [precheck-reclone] Error: failed to enter the script directory.
	exit /b 2
)

set "EXIT_CODE=0"
set "MANIFEST=workspace-repos.txt"
set /a REPO_COUNT=0
set /a ISSUE_COUNT=0
set /a SKIPPED_COUNT=0

call :preflight
if errorlevel 1 (
	set "EXIT_CODE=2"
	goto :done
)

echo [precheck-reclone] Checking workspace repositories before a clean re-clone...
for /f "usebackq eol=# tokens=1-3" %%A in ("%MANIFEST%") do (
	if not "%%~A"=="" (
		set /a REPO_COUNT+=1
		call :check_repo "%%~A" "%%~B"
	)
)

if "!REPO_COUNT!"=="0" (
	echo [precheck-reclone] Error: no repositories were found in "%MANIFEST%".
	set "EXIT_CODE=3"
	goto :done
)

if not "!ISSUE_COUNT!"=="0" (
	echo [precheck-reclone] Re-clone is blocked. Push, commit, stash, or back up the reported work first.
	set "EXIT_CODE=1"
	goto :done
)

echo [precheck-reclone] Safe to clean re-clone. No blocking local-only work was detected.

:done
echo [precheck-reclone] Summary: checked !REPO_COUNT! repo(s), skipped !SKIPPED_COUNT! missing repo(s), issues !ISSUE_COUNT!.
popd >nul
exit /b %EXIT_CODE%

:preflight
where git >nul 2>nul
if errorlevel 1 (
	echo [precheck-reclone] Error: git was not found in PATH.
	exit /b 1
)

if not exist "%MANIFEST%" (
	echo [precheck-reclone] Error: manifest "%MANIFEST%" was not found.
	exit /b 1
)

exit /b 0

:check_repo
set "REPO_NAME=%~1"
set "EXPECTED_URL=%~2"
set "CURRENT_BRANCH="
set "ACTUAL_URL="
set "UPSTREAM="
set "BEHIND="
set "AHEAD="

if not exist "%REPO_NAME%\" (
	echo [precheck-reclone] %REPO_NAME%: directory is missing. Nothing to check.
	set /a SKIPPED_COUNT+=1
	exit /b 0
)

git -C "%REPO_NAME%" rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
	call :report_issue "%REPO_NAME%" "directory exists but is not a git worktree"
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

git -C "%REPO_NAME%" fetch --quiet origin >nul 2>nul
if errorlevel 1 (
	call :report_issue "%REPO_NAME%" "failed to fetch origin for verification"
	exit /b 0
)

git -C "%REPO_NAME%" status --porcelain --untracked-files=normal | findstr /R "." >nul
if not errorlevel 1 (
	call :report_issue "%REPO_NAME%" "working tree is not clean"
	exit /b 0
)

for /f "delims=" %%I in ('git -C "%REPO_NAME%" symbolic-ref --quiet --short HEAD 2^>nul') do set "CURRENT_BRANCH=%%I"
if defined CURRENT_BRANCH (
	for /f "delims=" %%I in ('git -C "%REPO_NAME%" rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2^>nul') do set "UPSTREAM=%%I"
	if not defined UPSTREAM (
		call :report_issue "%REPO_NAME%" "current branch has no upstream"
		exit /b 0
	)

	if /I not "!UPSTREAM:~0,7!"=="origin/" (
		call :report_issue "%REPO_NAME%" "current branch upstream is not on origin"
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

	if not "!AHEAD!"=="0" (
		call :report_issue "%REPO_NAME%" "has !AHEAD! unpushed commits on !CURRENT_BRANCH!"
		exit /b 0
	)

	echo [precheck-reclone] %REPO_NAME%: no blocking local commits detected on !CURRENT_BRANCH!.
	exit /b 0
)

git -C "%REPO_NAME%" branch -r --contains HEAD 2>nul | findstr /R /C:"origin/" >nul
if errorlevel 1 (
	call :report_issue "%REPO_NAME%" "detached HEAD is not contained in any origin branch"
	exit /b 0
)

echo [precheck-reclone] %REPO_NAME%: detached HEAD is backed by origin; no blocking local-only commit detected.
exit /b 0

:report_issue
set /a ISSUE_COUNT+=1
echo [precheck-reclone] BLOCK: %~1 - %~2.
exit /b 0