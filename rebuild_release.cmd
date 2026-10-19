@echo off
rem Rebuilds the fast release copy after code changes. The page on http://localhost:8099 shows the new version after a hard refresh (Ctrl+Shift+R).
cd /d "%~dp0"
call flutter build web --release
echo.
echo Done. Open http://localhost:8099 and press Ctrl+Shift+R.
pause
