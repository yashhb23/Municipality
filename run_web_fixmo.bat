@echo off
echo ==========================================
echo         FixMo Web Testing Script
echo ==========================================
echo.

:: Store the original directory
set ORIGINAL_DIR=%cd%

echo [1/3] Preparing Flutter Web Environment...
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

echo ✅ Found Flutter project

echo.
echo [2/3] Installing Dependencies...
echo ==========================================

:: Clean and get dependencies
flutter clean
flutter pub get

echo.
echo [3/3] Starting FixMo Web App...
echo ==========================================

echo.
echo 🌐 Starting FixMo in Chrome...
echo.
echo 🗺️ Test Features in Browser:
echo    ✓ Map display (Mauritius-focused)
echo    ✓ Municipality markers (blue buildings)
echo    ✓ Sample reports (colored markers)
echo    ✓ Map legend and controls
echo    ✓ Municipality selector
echo    ✓ Report cards and details
echo    ✓ Fullscreen map view
echo.

echo 📝 NOTE: Location services may be limited in web browser
echo     Camera functionality requires HTTPS in production
echo.

:: Run the web app
flutter run -d chrome --hot

:: Return to original directory
cd "%ORIGINAL_DIR%"

echo.
echo ==========================================
echo           Web Testing Complete
echo ==========================================
pause 