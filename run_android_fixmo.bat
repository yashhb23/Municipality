@echo off
echo ==========================================
echo        FixMo Android Testing Script
echo ==========================================
echo.

:: Store the original directory
set ORIGINAL_DIR=%cd%

echo [1/4] Checking Android Emulator Setup...
echo ==========================================

:: Check available AVDs
echo Available Android Virtual Devices:
emulator -list-avds
echo.

:: Check if Pixel_7a AVD exists
emulator -list-avds | findstr "Pixel_7a" >nul
if errorlevel 1 (
    echo ❌ ERROR: Pixel_7a AVD not found
    echo Please create an AVD named 'Pixel_7a' in Android Studio
    echo Or modify this script to use your AVD name
    pause
    exit /b 1
) else (
    echo ✅ Pixel_7a AVD found
)

echo.
echo [2/4] Starting Android Emulator...
echo ==========================================

:: Kill any existing emulator processes
taskkill /f /im "qemu-system-x86_64.exe" >nul 2>&1
taskkill /f /im "emulator.exe" >nul 2>&1

:: Wait a moment for cleanup
timeout /t 2 /nobreak >nul

:: Start emulator in background
echo Starting Pixel_7a emulator...
start /b emulator -avd Pixel_7a -no-snapshot-load -wipe-data

:: Wait for emulator to boot
echo Waiting for emulator to boot (30 seconds)...
timeout /t 30 /nobreak

echo.
echo [3/4] Checking Device Connection...
echo ==========================================

:: Wait for device to be ready
:check_device
adb devices | findstr "emulator" >nul
if errorlevel 1 (
    echo Waiting for emulator to connect...
    timeout /t 5 /nobreak >nul
    goto check_device
) else (
    echo ✅ Emulator connected successfully
)

echo.
echo [4/4] Running FixMo App...
echo ==========================================

:: Navigate to Flutter app directory
cd "%ORIGINAL_DIR%\frontend\fixmo_app"

:: Check if we're in the right directory
if not exist "pubspec.yaml" (
    echo ❌ ERROR: Cannot find pubspec.yaml
    echo Make sure we're in the correct Flutter project directory
    pause
    exit /b 1
)

:: Clean and get dependencies
echo Installing dependencies...
flutter clean
flutter pub get

:: Run the app
echo.
echo 🚀 Starting FixMo on Android...
echo.
echo 📱 Test Features:
echo    ✓ Location permission dialog
echo    ✓ Red user location marker
echo    ✓ Blue municipality markers  
echo    ✓ Colored report markers
echo    ✓ Map legend and controls
echo    ✓ Fullscreen map view
echo    ✓ Camera functionality
echo    ✓ Report submission
echo.

flutter run -d android --hot --dart-define-from-file=dart_define.env

:: Return to original directory
cd "%ORIGINAL_DIR%"

echo.
echo ==========================================
echo          Android Testing Complete
echo ==========================================
pause 