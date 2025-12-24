@echo off
echo ========================================
echo Building Pythia Package (Silent MSBuild)
echo ========================================
cd /d "d:\dev\delphi\pythia2"

del build.log 2>nul

echo Building pythia.dproj...
echo.

REM Use .NET Framework MSBuild for silent headless build (no IDE popups)
set MSBUILD=%SystemRoot%\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe
if not exist "%MSBUILD%" (
    echo ERROR: MSBuild not found at %MSBUILD%
    exit /b 1
)

"%MSBUILD%" pythia.dproj /t:Build /p:Config=Debug /p:Platform=Win32 /nologo /verbosity:minimal > build.log 2>&1

echo Exit code: %ERRORLEVEL%
echo.

if exist build.log (
    echo ========== Build Log ==========
    type build.log
    echo ========== End Log ==========
    echo.
)

set BPL_PATH=C:\Users\Public\Documents\Embarcadero\Studio\23.0\Bpl\pythia.bpl
if exist "%BPL_PATH%" (
    echo SUCCESS! Package built successfully
    dir "%BPL_PATH%"
    echo.
    echo ========================================
    echo Installation Instructions:
    echo ========================================
    echo 1. Open Delphi IDE
    echo 2. Component ^> Install Packages
    echo 3. Add ^> Browse to: %BPL_PATH%
    echo 4. Click OK and restart IDE
    echo 5. Access via Tools ^> Pythia AI Chat (Ctrl+Shift+P)
    echo.
    echo Package location: %BPL_PATH%
) else (
    echo ERROR: pythia.bpl not found!
    echo Expected location: %BPL_PATH%
    echo Check build log above for errors
    exit /b 1
)
