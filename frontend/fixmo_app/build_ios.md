# Building IPA for iPhone Distribution

## Prerequisites
- **Mac computer** (required for iOS builds)
- **Xcode** installed from Mac App Store
- **Apple Developer Account** (free or paid)
- **Flutter SDK** installed on Mac

## Step 1: Setup on Mac

### Install Flutter on Mac:
```bash
# Download Flutter SDK for macOS
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.24.5-stable.zip
unzip flutter_macos_3.24.5-stable.zip
export PATH="$PATH:`pwd`/flutter/bin"

# Verify installation
flutter doctor
```

### Install Xcode:
```bash
# Install from Mac App Store (free)
# Then install command line tools:
sudo xcode-select --install
sudo xcodebuild -license accept
```

## Step 2: Prepare Project for iOS

### Copy project to Mac:
```bash
# Transfer your project folder to Mac
# Navigate to project directory
cd path/to/fixmo_app

# Get dependencies
flutter pub get

# Check iOS setup
flutter doctor
```

### Configure iOS Bundle ID:
```bash
# Open iOS project in Xcode
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select Runner project
# 2. Go to Signing & Capabilities
# 3. Set Bundle Identifier: com.fixmo.mauritius.fixmo_app
# 4. Select your Apple Developer Team
```

## Step 3: Build IPA File

### Method 1: Using Flutter (Recommended)
```bash
# Build for iOS release
flutter build ios --release

# Create IPA using Xcode
# This opens Xcode with the built project
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select "Any iOS Device" as target
# 2. Product > Archive
# 3. When archive completes, click "Distribute App"
# 4. Choose "Ad Hoc" or "Development" for testing
# 5. Follow the wizard to create IPA
```

### Method 2: Using Xcode Build
```bash
# Alternative: Build directly in Xcode
open ios/Runner.xcworkspace

# In Xcode:
# 1. Select Runner scheme
# 2. Select "Any iOS Device"
# 3. Product > Build For > Running
# 4. Product > Archive
# 5. Distribute as IPA
```

## Step 4: Install IPA on iPhone

### Method 1: Using Xcode (Easiest)
```bash
# Connect iPhone to Mac via USB
# In Xcode:
# 1. Window > Devices and Simulators
# 2. Select your iPhone
# 3. Click "+" and select the IPA file
# 4. App will install directly
```

### Method 2: Using TestFlight
```bash
# Upload to App Store Connect
# 1. In Xcode Organizer, select "Distribute App"
# 2. Choose "App Store Connect"
# 3. Upload the build
# 4. In App Store Connect, add to TestFlight
# 5. Send TestFlight invite to your email
# 6. Install TestFlight app on iPhone
# 7. Accept invite and install app
```

### Method 3: Using Third-party Tools
```bash
# Using AltStore (requires AltServer on Mac)
# 1. Install AltStore on iPhone
# 2. Install AltServer on Mac
# 3. Use AltStore to sideload IPA

# Using 3uTools or similar
# 1. Install 3uTools on Mac
# 2. Connect iPhone
# 3. Use "Install IPA" feature
```

## Step 5: Wireless Installation (Advanced)

### Using Apple Configurator 2:
```bash
# Install Apple Configurator 2 from Mac App Store
# 1. Connect iPhone initially via USB
# 2. Enable "Connect via network" in Configurator
# 3. Future installations can be wireless
```

## Alternative: Cloud Build Services

### If you don't have a Mac:

#### 1. Codemagic (Recommended)
```bash
# Visit: https://codemagic.io
# 1. Connect your GitHub repository
# 2. Configure iOS build workflow
# 3. Add Apple Developer certificates
# 4. Build automatically creates IPA
# 5. Download IPA or distribute via TestFlight
```

#### 2. GitHub Actions with macOS Runner
```yaml
# .github/workflows/ios.yml
name: iOS Build
on: [push]
jobs:
  build:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v2
    - uses: subosito/flutter-action@v2
    - run: flutter build ios --release --no-codesign
    - name: Archive IPA
      run: |
        cd ios
        xcodebuild -workspace Runner.xcworkspace \
                   -scheme Runner \
                   -configuration Release \
                   -archivePath Runner.xcarchive \
                   archive
```

#### 3. Bitrise
```bash
# Visit: https://bitrise.io
# Similar to Codemagic but with different pricing
```

## Troubleshooting

### Common Issues:
1. **Code signing errors**: Ensure Apple Developer account is properly configured
2. **Bundle ID conflicts**: Use unique bundle identifier
3. **Provisioning profile issues**: Create new profiles in Apple Developer portal
4. **Xcode version**: Use latest Xcode version
5. **Flutter iOS requirements**: Run `flutter doctor` to check setup

### Location Issues on Virtual Device:
- Virtual devices use simulated location
- Real device will show actual GPS coordinates
- Test location features on physical iPhone for accurate results

## Quick Commands Summary:
```bash
# Full iOS build process
flutter clean
flutter pub get
flutter build ios --release
open ios/Runner.xcworkspace
# Then archive in Xcode
``` 