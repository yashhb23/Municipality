# Supabase Storage Policy Setup for FixMo

## Overview
This guide shows you exactly what to put in the Supabase policy configuration screen shown in your image.

## Step-by-Step Policy Creation

### 1. Access Supabase Storage Policies

1. Go to your Supabase dashboard: https://supabase.com/dashboard
2. Select your FixMo project
3. Navigate to **Storage** in the sidebar
4. Click on **Policies** tab
5. Click **"Add policy to reportimages"** (the button you see in the image)

### 2. Create the Policy (Exact Configuration)

#### Policy Configuration Details:

**Policy name:**
```
Enable read access for all users
```

**Allowed operation:**
- ✅ **SELECT** (checked)
- ❌ INSERT (unchecked)
- ❌ UPDATE (unchecked) 
- ❌ DELETE (unchecked)

**Target roles:**
- Select: **"Defaults to all (public) roles if none selected"** (from dropdown)

**Policy definition:**
```sql
bucket_id = 'reportimages'
```

### 3. Complete Policy Setup

You need to create **4 separate policies** for the `reportimages` bucket:

#### Policy 1: Read Access (SELECT)
```
Policy name: Enable read access for all users
Allowed operation: ✅ SELECT only
Target roles: Defaults to all (public) roles if none selected
Policy definition: bucket_id = 'reportimages'
```

#### Policy 2: Upload Access (INSERT)
```
Policy name: Enable insert for authenticated users only
Allowed operation: ✅ INSERT only  
Target roles: Defaults to all (public) roles if none selected
Policy definition: bucket_id = 'reportimages'
```

#### Policy 3: Update Access (UPDATE)
```
Policy name: Enable update for users based on user_id
Allowed operation: ✅ UPDATE only
Target roles: Defaults to all (public) roles if none selected  
Policy definition: bucket_id = 'reportimages' AND auth.uid()::text = owner
```

#### Policy 4: Delete Access (DELETE)
```
Policy name: Enable delete for users based on user_id
Allowed operation: ✅ DELETE only
Target roles: Defaults to all (public) roles if none selected
Policy definition: bucket_id = 'reportimages' AND auth.uid()::text = owner
```

## What Each Policy Does

- **SELECT Policy**: Allows anyone to view/download images from the bucket
- **INSERT Policy**: Allows anyone to upload new images  
- **UPDATE Policy**: Only allows users to update their own uploaded files
- **DELETE Policy**: Only allows users to delete their own uploaded files

## After Creating Policies

1. Click **"Review"** for each policy to verify the SQL
2. Click **"Save policy"** to activate each one
3. Verify all 4 policies are listed in the Storage Policies view

## Test Your Setup

Run this test command in your SQL Editor:
```sql
-- Verify bucket and policies exist
SELECT 
  b.name as bucket_name,
  b.public,
  COUNT(p.id) as policy_count
FROM storage.buckets b
LEFT JOIN storage.policies p ON p.bucket_id = b.id  
WHERE b.id = 'reportimages'
GROUP BY b.name, b.public;
```

Expected result:
- bucket_name: reportimages
- public: true
- policy_count: 4

## Common Issues & Solutions

### Issue: "Policy doesn't exist" error
**Solution**: Make sure the bucket name is exactly `reportimages` (no hyphens, all lowercase)

### Issue: "Permission denied" when uploading
**Solution**: Verify the INSERT policy exists and bucket_id exactly matches

### Issue: Images not visible in app
**Solution**: Check the SELECT policy allows public access

### Issue: Can't delete old images  
**Solution**: Verify DELETE policy has the `auth.uid()::text = owner` condition

## Verification Checklist

- [ ] reportimages bucket exists and is public
- [ ] SELECT policy allows public read access
- [ ] INSERT policy allows public uploads
- [ ] UPDATE policy restricts to file owners
- [ ] DELETE policy restricts to file owners
- [ ] All 4 policies are active (green checkmarks in dashboard)

## Sample Images in the Bucket

After setup is complete, your app should be able to:
1. ✅ Upload photos from the camera/gallery
2. ✅ Display images in the app
3. ✅ Store images permanently in Supabase
4. ✅ Access images from any device

Your storage bucket structure will look like:
```
reportimages/
  reports/
    1234567890_abc123.jpg
    1234567891_def456.jpg
    1234567892_ghi789.jpg
```

Each image filename format: `{reportId}_{uuid}.jpg`

## Success! 🎉

Once all policies are configured correctly, your FixMo app will have full image storage capabilities with proper security permissions. 