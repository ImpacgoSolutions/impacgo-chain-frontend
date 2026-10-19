@echo off
rem Wrapper used by this project's editor terminal (see .vscode/settings.json).
rem "flutter run ..." is started in RELEASE mode (fast). The plain debug mode on the web is many times slower.
rem Use  flutter run --debug ...  when you really want debug (hot reload).  Every other flutter command is unchanged.
setlocal
set "REAL=C:\Users\saisu\Downloads\flutter\bin\flutter.bat"
if /i "%~1"=="run" (
  echo %* | findstr /i /c:"--release" /c:"--profile" /c:"--debug" >nul
  if errorlevel 1 (
    echo [IMPACGO] Starting in RELEASE mode - fast. Add --debug only if you need hot reload.
    if defined IMPACGO_DRYRUN ( echo WOULD RUN: flutter run --release %2 %3 %4 %5 %6 %7 %8 %9 & exit /b 0 )
    call "%REAL%" run --release %2 %3 %4 %5 %6 %7 %8 %9
    exit /b %errorlevel%
  )
)
if defined IMPACGO_DRYRUN ( echo WOULD RUN: flutter %* & exit /b 0 )
call "%REAL%" %*
exit /b %errorlevel%
