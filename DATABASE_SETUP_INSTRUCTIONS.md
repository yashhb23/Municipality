# FixMo Database Setup Instructions

## Step 1: Access Your Supabase Project

1. Go to https://supabase.com/dashboard
2. Sign in to your account
3. Select your FixMo project (or create a new one)
4. Note your project URL and anon key

## Step 2: Run the Complete Database Setup

### Option A: Copy and Paste SQL (Recommended)

1. Go to **SQL Editor** in your Supabase dashboard
2. Click **New Query**
3. Copy the entire contents of `complete_database_setup.sql`
4. Paste it into the SQL editor
5. Click **Run** to execute

### Option B: Manual Setup

If you prefer to set up step by step:

#### Create Storage Bucket
1. Go to **Storage** in Supabase dashboard
2. Click **Create a new bucket**
3. Name: `reportimages`
4. Set as **Public bucket**: ✅
5. File size limit: `5MB`
6. Allowed MIME types: `image/jpeg, image/png, image/webp, image/gif`

#### Set Storage Policies
Go to **Storage** > **Policies** and create these policies for `reportimages`:

**1. Enable read access for all users (SELECT)**
```sql
bucket_id = 'reportimages'
```

**2. Enable insert for authenticated users only (INSERT)**  
```sql
bucket_id = 'reportimages'
```

**3. Enable update for users based on user_id (UPDATE)**
```sql
bucket_id = 'reportimages' AND auth.uid()::text = owner
```

**4. Enable delete for users based on user_id (DELETE)**
```sql
bucket_id = 'reportimages' AND auth.uid()::text = owner
```

## Step 3: Verify Setup

### Check Tables
Run these queries in the SQL Editor to verify:

```sql
-- Check reports table
SELECT COUNT(*) as total_reports FROM public.reports;

-- Check municipalities table  
SELECT COUNT(*) as total_municipalities FROM public.municipalities;

-- Check storage bucket
SELECT name, public FROM storage.buckets WHERE id = 'reportimages';

-- Check sample data
SELECT title, municipality, status FROM public.reports LIMIT 5;
```

### Expected Results
- **reports table**: Should exist with sample data (3-4 records)
- **municipalities table**: Should have 10 Mauritius municipalities
- **reportimages bucket**: Should exist and be public
- **Storage policies**: Should allow read for all, insert/update/delete for authenticated users

## Step 4: Update App Configuration

Verify your `frontend/fixmo_app/lib/config/app_config.dart` has correct credentials:

```dart
class AppConfig {
  // Update these with YOUR Supabase project details
  static const String supabaseUrl = 'https://YOUR_PROJECT_REF.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
  
  // ... rest of config
}
```

## Step 5: Test the Setup

Run the test script:
```bash
test_fixmo_complete.bat
```

## Troubleshooting

### Common Issues:

**1. "Permission denied" errors**
- Check that RLS policies are set correctly
- Verify bucket is public for read access

**2. "Bucket not found" errors**  
- Ensure bucket name is exactly `reportimages` (no hyphens)
- Check bucket is created and public

**3. "Table doesn't exist" errors**
- Run the complete SQL setup script
- Check table names are correct (public.reports, public.municipalities)

**4. Image upload fails**
- Verify storage policies are set
- Check file size is under 5MB
- Ensure MIME type is supported

### Test Queries

```sql
-- Test connection
SELECT NOW() as current_time;

-- Test reports table
SELECT title, municipality FROM reports LIMIT 3;

-- Test municipalities table
SELECT name, coordinates FROM municipalities LIMIT 3;

-- Test storage bucket
SELECT * FROM storage.buckets WHERE id = 'reportimages';

-- Test policies
SELECT * FROM pg_policies WHERE tablename = 'reports';
```

## Database Schema Overview

### Reports Table
- `id`: UUID primary key
- `title`: Report title (required)
- `description`: Detailed description
- `category`: Issue category (Potholes, Street Lights, etc.)
- `municipality`: Which municipality (required)
- `latitude`/`longitude`: Exact location (required)
- `address`: Human-readable address
- `image_url`: Photo URL from storage
- `status`: pending/in_progress/resolved
- `created_at`/`updated_at`: Timestamps

### Municipalities Table
- `id`: Short municipality ID
- `name`: English name
- `name_fr`: French name
- `name_kreol`: Kreol name
- `coordinates`: JSON with lat/lng
- `email`: Municipal contact email
- `phone`: Municipal contact phone

### Storage Bucket: reportimages
- Public read access for viewing photos
- Authenticated upload/update/delete
- 5MB file size limit
- Image formats: JPEG, PNG, WebP, GIF

## Success Indicators

✅ All SQL commands execute without errors
✅ Sample data appears in reports table
✅ 10 municipalities loaded successfully
✅ Storage bucket is created and public
✅ App can connect to database
✅ Image upload works correctly
✅ No permission errors in app logs

After setup is complete, your FixMo app should be fully functional with Supabase backend! 