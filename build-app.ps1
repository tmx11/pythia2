# Build Pythia Standalone App
# Quick testing without IDE package installation

$ErrorActionPreference = "Stop"

Write-Host "Building Pythia Standalone Application..." -ForegroundColor Cyan

# Find Delphi installation
$DelphiPath = "C:\Program Files (x86)\Embarcadero\Studio\23.0"
if (-not (Test-Path $DelphiPath)) {
    Write-Host "Error: Delphi 12 not found at $DelphiPath" -ForegroundColor Red
    exit 1
}

$MSBuild = "$DelphiPath\bin\rsvars.bat"
$ProjectFile = "PythiaApp.dproj"

Write-Host "Cleaning previous build..." -ForegroundColor Yellow
if (Test-Path "Win32\Debug\PythiaApp.exe") {
    Remove-Item "Win32\Debug\PythiaApp.exe" -Force
}

Write-Host "Building $ProjectFile..." -ForegroundColor Yellow

# Use MSBuild (Community Edition compatible)
& "$DelphiPath\bin\msbuild.exe" $ProjectFile /t:Build /p:Config=Debug /p:Platform=Win32

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✓ Build successful!" -ForegroundColor Green
    Write-Host "Executable: Win32\Debug\PythiaApp.exe" -ForegroundColor Cyan
    
    # Optionally run it
    if ($args -contains "--run") {
        Write-Host "`nLaunching application..." -ForegroundColor Cyan
        Start-Process "Win32\Debug\PythiaApp.exe"
    }
    else {
        Write-Host "`nRun with: .\build-app.ps1 --run" -ForegroundColor Gray
    }
}
else {
    Write-Host "`n✗ Build failed!" -ForegroundColor Red
    exit 1
}
