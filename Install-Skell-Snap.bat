@echo off
setlocal
set "SOURCE=%~dp0Skell-Snap.vst3"
set "DEST=%LOCALAPPDATA%\Programs\Common Files\VST3\Skell-Snap.vst3"

if not exist "%SOURCE%\Contents\moduleinfo.json" if not exist "%SOURCE%\Contents\Resources\moduleinfo.json" (
  echo ERROR: Skell-Snap.vst3 bundle was not found beside this installer.
  echo Extract the entire ZIP before running this file.
  pause
  exit /b 2
)

if not exist "%LOCALAPPDATA%\Programs\Common Files\VST3" (
  mkdir "%LOCALAPPDATA%\Programs\Common Files\VST3"
  if errorlevel 1 (
    echo ERROR: Could not create your per-user VST3 folder.
    pause
    exit /b 3
  )
)

robocopy "%SOURCE%" "%DEST%" /E /R:2 /W:1
set "ROBOCOPY_RESULT=%ERRORLEVEL%"
if %ROBOCOPY_RESULT% GEQ 8 (
  echo ERROR: Copy failed with Robocopy exit code %ROBOCOPY_RESULT%.
  pause
  exit /b %ROBOCOPY_RESULT%
)

echo.
echo Skell-Snap VST3 installed successfully:
echo %DEST%
echo.
echo Close and reopen your DAW, then rescan VST3 plug-ins.
pause
exit /b 0
