# FixMo Security Checklist

Server-side and infrastructure hardening steps that must be applied manually.  
Client-side changes (env vars, logging, permissions, signing) are already implemented.

---

## 1. Supabase Row Level Security (RLS)

The current `reports` table has wide-open policies (`USING (true)` on SELECT, INSERT, UPDATE).  
Run these SQL statements in the **Supabase SQL Editor** to tighten them.

### Keep public read (civic data is public)

```sql
-- No change needed for SELECT — keep USING (true)
```

### Restrict INSERT to prevent abuse

If you use authentication:

```sql
DROP POLICY IF EXISTS "Allow insert" ON reports;
CREATE POLICY "Authenticated users can insert reports"
  ON reports FOR INSERT
  TO authenticated
  WITH CHECK (true);
```

If you allow anonymous submissions (current behavior), keep the existing policy but add rate limiting via a Supabase Edge Function or add a `reporter_device_id` column for abuse tracking.

### Restrict UPDATE to report owners only

```sql
DROP POLICY IF EXISTS "Allow update" ON reports;
CREATE POLICY "Users can update their own reports"
  ON reports FOR UPDATE
  TO authenticated
  USING (auth.uid()::text = user_id::text)
  WITH CHECK (auth.uid()::text = user_id::text);
```

### Add DELETE policy (currently missing)

```sql
CREATE POLICY "Users can delete their own reports"
  ON reports FOR DELETE
  TO authenticated
  USING (auth.uid()::text = user_id::text);
```

---

## 2. Supabase Storage Bucket Policies

The current INSERT policy on `reportimages` has no auth check.

### For authenticated-only uploads

```sql
DROP POLICY IF EXISTS "Allow upload" ON storage.objects;
CREATE POLICY "Authenticated users can upload images"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'reportimages'
    AND (storage.foldername(name))[1] = 'reports'
  );
```

### For anonymous uploads (current behavior)

Keep the existing policy but enforce:
- **File size limit:** Already 5 MB in app (check bucket settings too)
- **Content type:** Restrict to `image/jpeg`, `image/png` via bucket configuration
- **Rate limiting:** Add an Edge Function proxy that enforces per-IP rate limits

### Read access

```sql
CREATE POLICY "Public read access to report images"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'reportimages');
```

---

## 3. Google Maps API Key Restriction

The Maps API key shipped in the APK can be extracted. Restrict it:

### Android

1. Go to **Google Cloud Console** → **APIs & Services** → **Credentials**
2. Click your Maps API key → **Application restrictions**
3. Select **Android apps**
4. Add:
   - Package name: `com.fixmo.mauritius.fixmo_app`
   - SHA-1 fingerprint: get it with `keytool -list -v -keystore your-keystore.jks`
5. Under **API restrictions**, select **Maps SDK for Android** only
6. Save

### iOS

1. Same key or create a separate key
2. Restrict by **iOS apps**
3. Add bundle ID: `com.fixmo.mauritius.fixmoApp`
4. Restrict to **Maps SDK for iOS** only

---

## 4. Release Keystore Generation

Generate a release keystore for signing production APKs:

```bash
keytool -genkey -v \
  -keystore fixmo-release.keystore \
  -alias fixmo \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD \
  -dname "CN=FixMo,OU=Mobile,O=FixMo Mauritius,L=Port Louis,ST=Port Louis,C=MU"
```

Then configure `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=fixmo
storeFile=/absolute/path/to/fixmo-release.keystore
```

**IMPORTANT:**
- Back up the keystore securely — losing it means you cannot update the app on Play Store
- Never commit the keystore or `key.properties` to git (both are gitignored)
- Store the keystore password in a password manager or CI secrets

---

## 5. Environment Variables Setup

API keys are now injected via `--dart-define` instead of hardcoded strings.

### Local development

1. Copy `.env.example` to `.env` in `frontend/fixmo_app/`
2. Fill in your Supabase URL, anon key, and Google Maps key
3. Run with `.\run_dev.ps1` (Windows) or source the env and use `flutter run --dart-define=...`

### CI/CD

Pass secrets as environment variables in your pipeline:

```bash
flutter build apk \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY
```

**Note:** `defaultValue` fallbacks are set in `app_config.dart` for development convenience. In production CI, always provide explicit values.

---

## 6. Additional Recommendations

| Area | Recommendation |
|------|---------------|
| **Authentication** | Implement Supabase Auth (email/phone) before public release to enable proper RLS |
| **Rate limiting** | Add a Supabase Edge Function to proxy report creation with IP-based rate limiting |
| **HTTPS pinning** | Consider certificate pinning for the Supabase connection in high-security deployments |
| **Obfuscation** | Enable `--obfuscate --split-debug-info=build/debug-info` for release builds |
| **Crash reporting** | Integrate Sentry or Firebase Crashlytics (the `AppLogger.error` method has a placeholder) |
| **Dependency audit** | Run `flutter pub outdated` periodically and update dependencies |
| **ProGuard rules** | Ensure `proguard-rules.pro` is configured if `isMinifyEnabled = true` causes issues |
