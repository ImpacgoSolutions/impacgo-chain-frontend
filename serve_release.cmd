@echo off
rem Builds the app in RELEASE mode and opens it at http://localhost:8099 (fast, no "Debug build" banner).
rem Double-click this file. Close the window to stop it.
cd /d "%~dp0"
call flutter build web --release
start "" http://localhost:8099
python tools\serve_release.py 8099 build\web
