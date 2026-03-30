# FixMo -- Residuals, URLs, and Remaining Work

Last updated: 2026-03-30

---

## ALL URLs IN THE APP

### Live / Production URLs (configured and working)

| Location | URL | Purpose |
|---|---|---|
| `frontend/fixmo_app/dart_define.env` line 1 | `https://cxwayxmkacmywhttgwez.supabase.co` | Supabase project URL |
| `frontend/fixmo_app/dart_define.env` line 4 | `https://municipality-production.up.railway.app` | Railway backend API |
| `backend/.env` line 1 | `https://cxwayxmkacmywhttgwez.supabase.co` | Supabase project URL (backend) |
| `frontend/fixmo_app/lib/config/app_config.dart` line 84 | `https://municipality-production.up.railway.app` | Default fallback backend URL (hardcoded default) |

### Placeholder URLs (NOT YET REAL -- need real domains)

| Location | URL | What it needs |
|---|---|---|
| `frontend/fixmo_app/lib/screens/settings_screen.dart` line 534 | `https://fixmo.mu/terms` | Replace with real Terms of Service page URL once the website exists |
| `frontend/fixmo_app/lib/screens/settings_screen.dart` line 537 | `https://fixmo.mu/privacy` | Replace with real Privacy Policy page URL once the website exists |
| `frontend/fixmo_app/lib/screens/settings_screen.dart` line 547 | `mailto:support@fixmo.mu` | Replace with real support email address |

---

## PLACEHOLDER / INCOMPLETE FEATURES

### Settings Screen (`lib/screens/settings_screen.dart`)

1. **"Saved areas" row** (line ~425) -- marked as "Coming Soon". Needs geofencing/area-saving logic.
2. **"Export my data" row** (line ~515) -- marked as "Coming Soon". GDPR data export not yet implemented.
3. **"Delete account" row** (line ~516) -- marked as "Coming Soon". Supabase account deletion flow not wired.

### Why `SUPABASE_JWT_SECRET` is different from the service role key

- **`SUPABASE_SERVICE_ROLE_KEY`** proves your **server** to Supabase (admin API access). It is **not** used to verify user tokens.
- **`SUPABASE_JWT_SECRET`** is the **signing secret** Supabase Auth uses for **user JWTs** (anon sessions, `Authorization: Bearer …` from the Flutter app).
- The backend’s `requireAuth` middleware ([`backend/src/middleware/auth.js`](backend/src/middleware/auth.js)) calls `jwt.verify(token, SUPABASE_JWT_SECRET)`. Without this variable set in Railway, verification **throws** and protected routes (e.g. `POST /api/v1/reports`) return **401** or fail at startup verification.

You already have `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, and `RESEND_API_KEY` in Railway. **Add one more variable:** `SUPABASE_JWT_SECRET` = value from Supabase Dashboard → **Settings → API → JWT Secret** (not the anon key, not the service role key).

### Backend (`backend/.env`)

4. **`SUPABASE_JWT_SECRET`** (local `.env`) -- Should match Railway. Same source as above.

### Railway Environment Variables

5. The Railway deployment at `municipality-production.up.railway.app` should include:
   - `SUPABASE_URL` = `https://cxwayxmkacmywhttgwez.supabase.co`
   - `SUPABASE_SERVICE_ROLE_KEY` = (service role key)
   - **`SUPABASE_JWT_SECRET`** = (JWT Secret from Supabase API settings — **add this if missing**)
   - `RESEND_API_KEY` = (email, already set)
   - `PORT` = (Railway usually injects)
   - `NODE_ENV` = `production` recommended

---

## API KEYS IN THE APP (build-time)

All injected via `frontend/fixmo_app/dart_define.env` using `--dart-define-from-file`:

| Key | Present? | Source |
|---|---|---|
| `SUPABASE_URL` | YES | Supabase Dashboard |
| `SUPABASE_ANON_KEY` | YES | Supabase Dashboard |
| `GOOGLE_MAPS_API_KEY` | YES | Google Cloud Console |
| `BACKEND_URL` | YES | Railway deployment URL |

---

## WHAT WAS FIXED (2026-03-30)

1. **Upload timeout error** -- `BACKEND_URL` was `http://10.0.2.2:3001` (Android emulator loopback, unreachable from physical device). Changed to `https://municipality-production.up.railway.app`. Added 15s timeout on backend HTTP calls. Added Supabase-direct fallback: if Railway is down, reports insert directly into Supabase.

2. **Alerts tab removed** -- Bottom nav reduced from 5 items (Home, Alerts, +, History, Settings) to 4 items (Home, +, History, Settings). Indices re-mapped: History = 1, Settings = 2. FAB no longer sets a nav index (it only opens the report modal).

3. **Splash screen redesigned** -- Replaced the old 3-controller scale+bounce animation with a single-controller staggered fade+slide animation. Removed `flutter_spinkit` dependency. Uses Material 3 `CircularProgressIndicator`. Cross-fades into the home screen instead of a hard push.

---

## NEXT STEPS

- [ ] Set `SUPABASE_JWT_SECRET` in Railway environment variables so backend JWT auth works
- [ ] Set `SUPABASE_JWT_SECRET` in `backend/.env` for local development
- [ ] Create a real Terms of Service page and update `https://fixmo.mu/terms`
- [ ] Create a real Privacy Policy page and update `https://fixmo.mu/privacy`
- [ ] Set up a real `support@fixmo.mu` email or replace with a working address
- [ ] Implement "Saved areas" feature in Settings
- [ ] Implement "Export my data" (GDPR) feature in Settings
- [ ] Implement "Delete account" feature in Settings
- [ ] Build and deploy updated backend code to Railway (push to GitHub, Railway auto-deploys)
