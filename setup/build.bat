@echo off
rem Builds dist\DeltaSponge-Setup.exe and dist\DeltaSponge-Tool-v1.0.zip
rem Needs only Windows (uses the .NET Framework 4 C# compiler that ships with it).
setlocal
cd /d "%~dp0"

set VERSION=1.0
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
    echo C# compiler not found.
    exit /b 1
)

if not exist ..\dist mkdir ..\dist

"%CSC%" /nologo /target:winexe /optimize+ /platform:anycpu ^
  /out:..\dist\DeltaSponge-Setup.exe ^
  /win32manifest:app.manifest ^
  /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll ^
  /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll ^
  /resource:..\mod\DeltaSponge_Install.csx,DeltaSponge_Install.csx ^
  /resource:..\mod\gml\Create.gml,gml/Create.gml ^
  /resource:..\mod\gml\BeginStep.gml,gml/BeginStep.gml ^
  /resource:..\mod\gml\Step.gml,gml/Step.gml ^
  /resource:..\mod\gml\DrawGUI.gml,gml/DrawGUI.gml ^
  Setup.cs
if errorlevel 1 exit /b 1

rem Release zip: setup + mod files (for manual install) + readme
powershell -NoProfile -Command ^
  "$z='..\dist\DeltaSponge-Tool-v%VERSION%.zip'; if (Test-Path $z) { Remove-Item $z };" ^
  "Compress-Archive -Path '..\dist\DeltaSponge-Setup.exe','..\mod','..\README.md','..\LICENSE' -DestinationPath $z"
if errorlevel 1 exit /b 1

echo.
echo Built: dist\DeltaSponge-Setup.exe
echo Built: dist\DeltaSponge-Tool-v%VERSION%.zip
