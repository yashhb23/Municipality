# FixMo — Technical Specification

> Comprehensive technical spec for the FixMo civic-reporting mobile app.
> This document is intended as a single-source-of-truth that another developer (or AI) can use to fully understand, audit, and rebuild the application.

---

## 1. App Overview

| Field | Value |
|---|---|
| **Name** | FixMo |
| **Subtitle** | AI-Powered Civic Reporting for Mauritius |
| **Version** | 1.3.0+5 |
| **Organization** | com.fixmo.mauritius |
| **Framework** | Flutter 3.x (Dart SDK ^3.8.1) |
| **Platforms** | Android (primary), iOS (secondary) |
| **State management** | Provider |
| **Backend** | Supabase (PostgreSQL + Storage + Auth) |
| **Maps** | Google Maps Flutter |

### Purpose

FixMo enables citizens of Mauritius to report civic problems (potholes, broken lights, waste, flooding, etc.) directly to their municipality. Reports include GPS location, optional photo evidence, and a structured multi-level category. All data is stored in Supabase.

---

## 2. Architecture

```
┌──────────────────────────────────────────────────┐
│                    main.dart                       │
│  Supabase.initialize → Providers → MaterialApp   │
└───────────────────────┬──────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        │               │               │
   ThemeProvider   AppStateProvider  Services
   (ChangeNotifier) (ChangeNotifier)    │
        │                           ┌───┴────────────┐
        │                           │                │
  Light/Dark theme         SupabaseService   LocationService
  via ColorScheme          ReportsService    MapMarkerService
        │
   All Screens & Widgets
   read Theme.of(context)
```

### Provider-Based State

| Provider | Type | Purpose |
|---|---|---|
| `ThemeProvider` | `ChangeNotifier` | Manages light/dark theme; persists choice to `SharedPreferences` |
| `AppStateProvider` | `ChangeNotifier` | Holds current GPS position, selected municipality, permission state |
| `LocationService` | `Provider` | Wraps `geolocator`, detects location, reverse-geocodes municipality |
| `SupabaseService` | `Provider` | All Supabase DB + Storage operations (CRUD, image upload) |
| `ReportsService` | `Provider` (singleton) | In-memory report list, sample data init, stream for live updates |

### Service Layer

Services are injected via `MultiProvider` in `main.dart` and consumed in widgets with `context.read<T>()` or `context.watch<T>()`.

---

## 3. Directory Structure

```
frontend/fixmo_app/
├── lib/
│   ├── main.dart                          # Entry point, Supabase init, provider setup
│   ├── config/
│   │   └── app_config.dart                # API keys (dart-define), colors, constants
│   ├── models/
│   │   └── report_model.dart              # ReportModel with toJson/fromJson
│   ├── providers/
│   │   ├── app_state_provider.dart        # GPS state, selected municipality
│   │   └── theme_provider.dart            # Light/Dark ThemeData, Poppins text theme
│   ├── screens/
│   │   ├── splash_screen.dart             # Animated splash → /home
│   │   ├── home_screen.dart               # Google Map + FABs + bottom sheet + nav bar
│   │   ├── report_screen.dart             # Multi-step report creation wizard
│   │   ├── history_screen.dart            # List of past reports
│   │   └── settings_screen.dart           # Theme toggle, location, notifications, about
│   ├── services/
│   │   ├── supabase_service.dart          # DB CRUD + Storage upload with retry
│   │   ├── location_service.dart          # GPS, permissions, geocoding, Mauritius bounds
│   │   ├── reports_service.dart           # In-memory report store + sample data
│   │   └── map_marker_service.dart        # Custom BitmapDescriptor markers
│   ├── utils/
│   │   └── app_logger.dart                # Debug/warn/error logging (debug-only)
│   └── widgets/
│       ├── bottom_sheet_incident_detail.dart  # Draggable sheet with report summary
│       ├── category_chips.dart               # Horizontal filter chips
│       ├── report_detail_card.dart           # Full report card with image
│       ├── upload_progress_overlay.dart       # Minimal progress ring + success anim
│       ├── shimmer_loading.dart              # Skeleton loader
│       ├── platform_image.dart               # File/Bytes image (mobile/web)
│       ├── quick_report_modal.dart           # Navigates to /report
│       ├── municipality_selector.dart        # Municipality dropdown
│       └── full_screen_map.dart              # Standalone map viewer
└── assets/
    ├── data/
    │   └── mauritius_municipalities.json  # Preloaded municipality list
    ├── map_styles/
    │   └── dark_map_style.json            # Google Maps dark style (applied when theme is dark)
    ├── images/                            # App images
    └── icons/                             # Custom icons
```

---

## 4. Data Flow — Report Creation Pipeline

```
User taps "+" FAB on nav bar
  └─> QuickReportModal.show() → Navigator.pushNamed('/report')
        └─> ReportScreen
              1. Take Photo (Camera or Gallery via image_picker)
              2. Select Category → Subcategory → Specific Issue
              3. Optional: Description, specific location text
              4. Tap "Submit Report"
                 ├─ _compressImage() — flutter_image_compress (85% quality, max 1920×1080)
                 ├─ _uploadImage() — SupabaseService.uploadImage()
                 │   └─ Uploads to 'reportimages' bucket at path reports/<reportId>_<uuid>.jpg
                 │   └─ Returns public URL
                 ├─ _createReport() — SupabaseService.createReport()
                 │   └─ Inserts row into 'reports' table with all fields
                 └─ Show UploadProgressOverlay (0%→100% arc, stage dots)
                    └─ On success → scale-in check icon → navigate to ReportSuccessScreen
```

---

## 5. Backend — Supabase

### Project

| Property | Value |
|---|---|
| Project URL | `https://iexhralidwrmfrggxtrh.supabase.co` |
| Region | (check Supabase dashboard) |
| Auth | Anonymous access via anon key (no user auth implemented) |

### Tables

#### `reports`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid (PK) | Auto-generated |
| `title` | text | Report title |
| `description` | text | User-provided description |
| `category` | text | Top-level category |
| `subcategory` | text | Second-level category |
| `status` | text | `pending`, `in_progress`, `resolved` |
| `latitude` | double | GPS latitude |
| `longitude` | double | GPS longitude |
| `municipality` | text | Resolved municipality name |
| `address` | text | Reverse-geocoded address string |
| `image_urls` | text[] | Array of public storage URLs |
| `reporter_name` | text | Display name (anonymous by default) |
| `user_id` | text | Device or session ID (no auth) |
| `priority` | int | 1-3 (low to high) |
| `created_at` | timestamptz | Auto-set |
| `updated_at` | timestamptz | Updated on status change |

#### `municipalities`

| Column | Type | Notes |
|---|---|---|
| `id` | uuid (PK) | |
| `name` | text | Municipality display name |
| Other fields | varies | Coordinates, district info, etc. |

### Storage

| Bucket | Name | Access |
|---|---|---|
| Report images | `reportimages` | Public read, anon write (via policy) |

Path pattern: `reports/<reportId>_<uuid>.jpg`

### Row-Level Security (RLS)

**Current state**: RLS rules are unknown / minimal. The anon key grants broad access. See Vulnerabilities section.

---

## 6. Theme System

### ThemeProvider

`ThemeProvider` (extends `ChangeNotifier`) manages the active theme. It persists the choice (`light` or `dark`) to `SharedPreferences` under key `selected_theme`.

### AppTheme Enum

```dart
enum AppTheme {
  light('Light', Icons.light_mode, Color(0xFF00B386)),
  dark('Dark', Icons.dark_mode, Color(0xFF00D9A3));
}
```

### Color Palette

| Token | Dark Value | Light Value | CSS |
|---|---|---|---|
| primary | `#00D9A3` | `#00B386` | Green accent |
| onPrimary | `#FFFFFF` | `#FFFFFF` | |
| surface | `#1A1A1A` | `#FFFFFF` | Card/container bg |
| scaffoldBackground | `#0A0A0A` | `#F5F5F5` | Page bg |
| onSurface | `#E2E8F0` | `#1E293B` | Primary text |
| onSurface (secondary) | `#94A3B8` | `#64748B` | Subtitle text |
| error | `#EF4444` | `#EF4444` | |

### How Screens Consume Theme

All screens and widgets obtain colors via:

```dart
final cs = Theme.of(context).colorScheme;
final tt = Theme.of(context).textTheme;
```

No file uses hardcoded `Color(0x...)` constants for structural colors. Functional/semantic colors (status badge red/green, priority dots) remain fixed.

### Typography

All text uses **Poppins** (via `google_fonts` package). The full `TextTheme` is built in `ThemeProvider._poppinsTextTheme()`.

### Map Style

The dark Google Maps style JSON (`assets/map_styles/dark_map_style.json`) is applied conditionally:

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
_mapController.setMapStyle(isDark ? _darkMapStyleJson : null);
```

---

## 7. Dependencies

### Runtime (`dependencies`)

| Package | Version | Purpose |
|---|---|---|
| `flutter` | SDK | Framework |
| `cupertino_icons` | ^1.0.8 | iOS-style icons |
| `google_maps_flutter` | ^2.9.0 | Map widget with markers |
| `geolocator` | ^13.0.1 | GPS position, distance calculations |
| `geocoding` | ^3.0.0 | Address ↔ coordinates |
| `location` | ^7.0.0 | Location service (used alongside geolocator) |
| `url_launcher` | ^6.3.1 | Open URLs / app settings |
| `image_picker` | ^1.1.2 | Camera + gallery image selection |
| `camera` | ^0.11.0+2 | Direct camera control |
| `path_provider` | ^2.1.4 | Temp directory access |
| `path` | ^1.9.0 | Path manipulation |
| `image` | ^4.1.7 | Image processing |
| `flutter_image_compress` | ^2.3.0 | JPEG compression before upload |
| `supabase_flutter` | ^2.6.0 | Supabase client (DB + Storage + Auth) |
| `http` | ^1.2.2 | HTTP client |
| `provider` | ^6.1.2 | State management |
| `uuid` | ^4.5.1 | Unique ID generation |
| `shared_preferences` | ^2.3.2 | Local key-value persistence |
| `permission_handler` | ^11.3.1 | Runtime permission requests |
| `flutter_spinkit` | ^5.2.1 | Loading spinners |
| `flutter_staggered_animations` | ^1.1.1 | List animations |
| `cached_network_image` | ^3.4.1 | Image caching |
| `google_fonts` | ^6.0.0 | Poppins font |
| `phosphor_flutter` | ^2.0.0 | Icon set |

### Dev (`dev_dependencies`)

| Package | Version |
|---|---|
| `flutter_test` | SDK |
| `flutter_lints` | ^5.0.0 |

---

## 8. Environment Variables

All secrets are injected at build time via `--dart-define`. In `app_config.dart`, each reads from `String.fromEnvironment` with a **fallback default** (see Vulnerabilities).

| Variable | Purpose |
|---|---|
| `SUPABASE_URL` | Supabase project REST URL |
| `SUPABASE_ANON_KEY` | Supabase anonymous JWT |
| `GOOGLE_MAPS_API_KEY` | Google Maps Platform key |

### Build Command

```bash
cd frontend/fixmo_app
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key \
  --dart-define=GOOGLE_MAPS_API_KEY=your-maps-key
```

Without `--dart-define`, the app falls back to the hardcoded defaults in `app_config.dart`.

---

## 9. Build Instructions

### Prerequisites

- Flutter SDK >= 3.8.1
- Android SDK (API 33+)
- A Google Maps API key with Maps SDK for Android/iOS enabled
- A Supabase project with the `reports` and `municipalities` tables, and `reportimages` storage bucket

### Steps

```bash
# 1. Clone and enter the Flutter app
cd frontend/fixmo_app

# 2. Install dependencies
flutter pub get

# 3. Run in development
flutter run

# 4. Build release APK
flutter build apk --release \
  --dart-define=SUPABASE_URL=<url> \
  --dart-define=SUPABASE_ANON_KEY=<key> \
  --dart-define=GOOGLE_MAPS_API_KEY=<key>

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Android Specifics

- `minSdkVersion`: Check `android/app/build.gradle` (typically 21+)
- Google Maps API key must also be set in `android/app/src/main/AndroidManifest.xml` under `<meta-data android:name="com.google.android.geo.API_KEY" ...>`
- Permissions: `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `INTERNET`, `READ_EXTERNAL_STORAGE`

---

## 10. Current Vulnerabilities

### CRITICAL

#### V1: Hardcoded Supabase Credentials in Source
- **File**: `frontend/fixmo_app/lib/config/app_config.dart` lines 7-13
- **Detail**: `supabaseUrl` and `supabaseAnonKey` have hardcoded `defaultValue` strings containing the real project URL and a valid JWT. These are committed to git.
- **Impact**: Anyone with repo access (or the APK) can extract the Supabase URL and anon key, enabling unauthenticated reads/writes depending on RLS.
- **Remediation**: Remove default values entirely. Require `--dart-define` at build time. Add a compile-time assertion: `assert(supabaseUrl.isNotEmpty, 'SUPABASE_URL must be set via --dart-define')`.

#### V2: Hardcoded Google Maps API Key in Source
- **File**: `frontend/fixmo_app/lib/config/app_config.dart` line 23-26
- **File**: `frontend/fixmo_app/android/app/src/main/AndroidManifest.xml`
- **Detail**: The Google Maps API key is hardcoded as a default value and also embedded in `AndroidManifest.xml`.
- **Impact**: Key abuse (quota theft, billing). Keys can be extracted from APK strings.
- **Remediation**: Restrict the key in Google Cloud Console (Android app restriction, API restriction). Remove the defaultValue. Use `--dart-define` or a secrets management solution.

#### V3: Secrets in Git History
- **Detail**: Even if current code is cleaned, the keys exist in prior commits.
- **Remediation**: Rotate ALL keys immediately. Treat all previously committed keys as compromised.

### HIGH

#### V4: No Image Size Validation (Enforced)
- **Detail**: `maxImageSizeBytes = 5MB` is defined but never checked before upload.
- **Remediation**: Add a size check after compression. Reject or re-compress images exceeding the limit.

#### V5: No Image MIME Type Validation
- **Detail**: `contentType: 'image/jpeg'` is hardcoded. No magic-byte validation.
- **Remediation**: Validate the first bytes of the file. Reject non-image uploads.

#### V6: No Description Length Validation (Enforced)
- **Detail**: `maxReportDescriptionLength = 500` is defined but never enforced.
- **Remediation**: Set `maxLength: 500` on the TextField and validate server-side.

#### V7: No User Authentication
- **Detail**: All reports are anonymous. No accountability or abuse tracking.
- **Remediation**: Implement Supabase Auth. Associate reports with authenticated user IDs.

#### V8: `hasInternetConnection()` Returns `true` on Error
- **File**: `frontend/fixmo_app/lib/services/supabase_service.dart` lines 18-41
- **Detail**: The catch block returns `true` even when the connection check fails.
- **Remediation**: Return `false` in the catch block.

### MEDIUM

#### V9: No Input Sanitization Before DB Insert
- **Remediation**: Strip HTML tags, limit character sets, enforce length limits.

#### V10: Client-Side `deleteReport` / `updateReportStatus` Unprotected
- **Remediation**: Implement RLS policies requiring `auth.uid() = user_id`.

#### V11: `getAllReports` Fetches 100 Reports with No Auth
- **Remediation**: Require authentication. Implement pagination. Scope to municipality.

### LOW

#### V12: `debugPrint` Statements in Production
- **Remediation**: Replace all bare `print`/`debugPrint` with `AppLogger`.

#### V13: `.gitignore` Missing `.env` Entries
- **Remediation**: Add `.env*` to `.gitignore`.

#### V14: Outdated `supabase_flutter` Dependency
- **Remediation**: Upgrade to latest stable.

#### V15: Redundant Location Packages
- **Remediation**: Consolidate to `geolocator` only.

---

## 11. Recommendations Summary

| Priority | Action |
|---|---|
| **CRITICAL** | Rotate all API keys immediately |
| **CRITICAL** | Remove default values from `app_config.dart` |
| **CRITICAL** | Add API key restrictions in Google Cloud Console |
| **HIGH** | Implement Supabase Auth |
| **HIGH** | Add RLS policies on `reports` and `municipalities` |
| **HIGH** | Validate image size + MIME type before upload |
| **HIGH** | Enforce `maxLength` on text fields |
| **HIGH** | Fix `hasInternetConnection()` to return `false` on error |

---

## 12. Rebuild Checklist

1. Create Flutter project with `flutter create --org com.fixmo fixmo_app`
2. Add all dependencies from Section 7
3. Set up Supabase project with tables from Section 5
4. Create `app_config.dart` — use `String.fromEnvironment` WITHOUT default values
5. Implement `ThemeProvider` with light/dark themes
6. Implement services — SupabaseService, LocationService, ReportsService, MapMarkerService
7. Build screens — Splash → Home (map + nav) → Report (wizard) → History → Settings
8. Build widgets — Bottom sheet, category chips, report detail card, upload overlay, shimmer
9. Wire providers in `main.dart` via MultiProvider
10. Add assets — municipality JSON, dark map style JSON
11. Configure Android — API key in manifest, permissions, min SDK
12. Address ALL vulnerabilities from Section 10 before production deployment

---

*Generated: March 2026 | FixMo v1.3.0*
