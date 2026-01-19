@echo off
echo FixMo Quick Run
echo ===============

REM Force change to the correct directory
cd /d "D:\AI\MAU Municipality\frontend\fixmo_app"

REM Show current directory
echo Current directory: %CD%

REM Check if pubspec.yaml exists
if exist pubspec.yaml (
    echo ✓ pubspec.yaml found
) else (
    echo ✗ pubspec.yaml NOT found - wrong directory!
    pause
    exit
)

REM Check devices
echo Checking devices...
C:\Users\yashb\flutter2\bin\flutter.bat devices

REM Run the app
echo Starting FixMo app...
C:\Users\yashb\flutter2\bin\flutter.bat run -d emulator-5554

pause 