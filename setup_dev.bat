@echo off
REM SoulGame Development Environment Setup Script
REM Checks prerequisites and sets up the development environment.

echo ========================================
echo   SoulGame Dev Environment Setup
echo ========================================
echo.

set ERROR_COUNT=0

REM --- Check Godot ---
echo [1/5] Checking Godot 4...
where godot >nul 2>nul
if %errorlevel%==0 (
    for /f "tokens=*" %%i in ('godot --version 2^>nul') do set GODOT_VERSION=%%i
    echo   Godot found: %GODOT_VERSION%
) else (
    echo   WARNING: Godot not found in PATH.
    echo   Download from: https://godotengine.org/download
    echo   Add Godot executable to PATH or use full path.
    set /a ERROR_COUNT+=1
)
echo.

REM --- Check Git ---
echo [2/5] Checking Git...
where git >nul 2>nul
if %errorlevel%==0 (
    for /f "tokens=*" %%i in ('git --version') do set GIT_VERSION=%%i
    echo   Git found: %GIT_VERSION%
) else (
    echo   ERROR: Git not found.
    echo   Download from: https://git-scm.com/downloads
    set /a ERROR_COUNT+=1
)
echo.

REM --- Check Node.js (for backend services) ---
echo [3/5] Checking Node.js...
where node >nul 2>nul
if %errorlevel%==0 (
    for /f "tokens=*" %%i in ('node --version') do set NODE_VERSION=%%i
    echo   Node.js found: %NODE_VERSION%
) else (
    echo   WARNING: Node.js not found.
    echo   Required for running SoulArena/Seed backend services.
    echo   Download from: https://nodejs.org/
    set /a ERROR_COUNT+=1
)
echo.

REM --- Check backend services ---
echo [4/5] Checking backend services...
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:3000/api/souls' -Method GET -TimeoutSec 2 -UseBasicParsing; Write-Host '  SoulArena (:3000): RUNNING' } catch { Write-Host '  SoulArena (:3000): not running' }"
powershell -Command "try { $r = Invoke-WebRequest -Uri 'http://localhost:3001/api/world/status' -Method GET -TimeoutSec 2 -UseBasicParsing; Write-Host '  Seed (:3001): RUNNING' } catch { Write-Host '  Seed (:3001): not running' }"
echo.

REM --- Verify project structure ---
echo [5/5] Verifying project structure...
if exist project.godot (
    echo   project.godot: OK
) else (
    echo   ERROR: project.godot not found
    set /a ERROR_COUNT+=1
)
if exist scripts\autoload (
    echo   scripts/autoload: OK
) else (
    echo   ERROR: scripts/autoload not found
    set /a ERROR_COUNT+=1
)
if exist scripts\core (
    echo   scripts/core: OK
) else (
    echo   ERROR: scripts/core not found
    set /a ERROR_COUNT+=1
)
if exist scripts\sdk (
    echo   scripts/sdk: OK
) else (
    echo   ERROR: scripts/sdk not found
    set /a ERROR_COUNT+=1
)
if exist config (
    echo   config: OK
) else (
    echo   ERROR: config not found
    set /a ERROR_COUNT+=1
)
if exist tests (
    echo   tests: OK
) else (
    echo   ERROR: tests not found
    set /a ERROR_COUNT+=1
)
echo.

REM --- Git status ---
echo Git Status:
git status -sb
echo.

REM --- Summary ---
echo ========================================
if %ERROR_COUNT%==0 (
    echo   Setup complete! All checks passed.
) else (
    echo   Setup complete with %ERROR_COUNT% warning(s).
    echo   See above for details.
)
echo ========================================
echo.
echo Quick commands:
echo   godot --editor              Open Godot editor
echo   godot --headless -s res://tests/TestRunner.gd   Run tests
echo   git pull --rebase           Pull latest changes
echo   git push                    Push changes
echo.
pause
