@echo off
echo ========================================
echo Building Pythia Standalone App
echo ========================================
cd /d "d:\dev\delphi\pythia2"

del build-app.log 2>nul

echo Building PythiaApp.dproj...
"d:\program files (x86)\embarcadero\studio\23.0\bin\bds.exe" -ns -b "PythiaApp.dproj" -obuild-app.log

timeout /t 3 >nul

echo.
echo Exit code: %ERRORLEVEL%
echo.

if exist build-app.log (
    echo ========== Build Log ==========
    type build-app.log
    echo ========== End Log ==========
    echo.
)

set EXE_PATH=Win32\Debug\PythiaApp.exe
if exist "%EXE_PATH%" (
    echo SUCCESS! Application built successfully
    dir "%EXE_PATH%"
    echo.
    echo Starting PythiaApp.exe...
    start "" "%EXE_PATH%"
) else (
    echo ERROR: PythiaApp.exe not found!
    echo Expected location: %EXE_PATH%
    echo Check build log above for errors
    exit /b 1
)
