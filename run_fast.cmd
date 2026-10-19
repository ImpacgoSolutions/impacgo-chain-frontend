@echo off
rem Starts the app in RELEASE mode (much faster than the normal "flutter run", which is a slow debug build).
rem Double-click this file, or run it from the project folder.
cd /d "%~dp0"
flutter run -d chrome --release
