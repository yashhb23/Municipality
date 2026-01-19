# Supabase Database Setup for FixMo Municipal App

## Overview
This document contains the SQL commands and configurations needed to set up the Supabase database for the FixMo municipal reporting application.

## 1. Database Tables

### Reports Table
Execute the following SQL in your Supabase SQL editor:

```sql
-- Create reports table
CREATE TABLE IF NOT EXISTS reports (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  category VARCHAR(100) NOT NULL,
  subcategory VARCHAR(100),
  municipality VARCHAR(100) NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  address TEXT,
  image_url TEXT,
  status VARCHAR(50) DEFAULT 'pending',
  priority INTEGER DEFAULT 1,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_reports_municipality ON reports(municipality);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_user_id ON reports(user_id);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_reports_updated_at BEFORE UPDATE
  ON reports FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
```

## 2. Storage Configuration

### Create Storage Bucket for Report Images

1. Go to Storage in your Supabase dashboard
2. Create a new bucket named: `report-images`
3. Set the bucket to **Public** (for easier access to images)
4. Set up the following storage policies:

```sql
-- Allow public read access to images
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (bucket_id = 'report-images');

-- Allow authenticated users to upload images
CREATE POLICY "Allow authenticated uploads" ON storage.objects 
FOR INSERT WITH CHECK (bucket_id = 'report-images' AND auth.role() = 'authenticated');

-- Allow users to update their own images (optional)
CREATE POLICY "Allow users to update own images" ON storage.objects 
FOR UPDATE USING (bucket_id = 'report-images' AND auth.uid()::text = owner);
```

## 3. Row Level Security (RLS) Policies

Enable RLS on the reports table and set up policies:

```sql
-- Enable RLS
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read reports (for community transparency)
CREATE POLICY "Anyone can view reports" ON reports FOR SELECT USING (true);

-- Allow anyone to create reports (for anonymous reporting)
CREATE POLICY "Anyone can create reports" ON reports FOR INSERT WITH CHECK (true);

-- Only allow report owners or admins to update reports
CREATE POLICY "Users can update own reports" ON reports FOR UPDATE 
USING (user_id = auth.uid() OR auth.jwt() ->> 'role' = 'admin');

-- Only allow report owners or admins to delete reports
CREATE POLICY "Users can delete own reports" ON reports FOR DELETE 
USING (user_id = auth.uid() OR auth.jwt() ->> 'role' = 'admin');
```

## 4. Supabase Configuration in Flutter App

Make sure your `lib/config/app_config.dart` has the correct Supabase credentials:

```dart
class AppConfig {
  // Supabase Configuration
  static const String supabaseUrl = 'YOUR_SUPABASE_PROJECT_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
  
  // Your other config...
}
```

## 5. Testing the Database

You can test the database setup by running some sample queries:

```sql
-- Insert a test report
INSERT INTO reports (title, description, category, municipality, latitude, longitude, address) 
VALUES (
  'Test Pothole Report',
  'Large pothole causing traffic issues',
  'Roads & Transport',
  'Quatre Bornes',
  -20.2666,
  57.4833,
  'Royal Road, Quatre Bornes'
);

-- Query reports by municipality
SELECT * FROM reports WHERE municipality = 'Quatre Bornes' ORDER BY created_at DESC;

-- Get report statistics
SELECT 
  municipality,
  status,
  COUNT(*) as count
FROM reports 
GROUP BY municipality, status
ORDER BY municipality, status;
```

## 6. Environment Variables (Optional)

For production, consider using environment variables:

```bash
# .env file (don't commit to version control)
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
```

## 7. Image Upload Testing

Test image uploads by checking the `report-images` bucket in your Supabase storage dashboard after submitting a report with a photo through the app.

## Notes

- The app is designed to work with anonymous users initially
- User authentication can be added later for enhanced features
- All reports are public by default to encourage community transparency
- Images are stored in Supabase Storage and referenced by URL in the reports table
- The app includes error handling for offline scenarios and missing images

## Mauritius Municipalities Supported

The app supports the following municipalities:
- Port Louis
- Beau Bassin-Rose Hill
- Vacoas-Phoenix
- Curepipe
- Quatre Bornes
- Triolet
- Goodlands
- Centre de Flacq
- Mahébourg
- Saint Pierre 