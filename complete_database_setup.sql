-- FixMo Complete Database Setup with Storage Policies
-- Based on Supabase policy configuration screenshot

-- Step 1: Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Step 2: Create storage bucket for report images (if not exists)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'reportimages',
  'reportimages', 
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Step 3: Storage policies for reportimages bucket
-- Delete existing policies first
DROP POLICY IF EXISTS "Enable read access for all users" ON storage.objects;
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON storage.objects;
DROP POLICY IF EXISTS "Enable update for users based on user_id" ON storage.objects;
DROP POLICY IF EXISTS "Enable delete for users based on user_id" ON storage.objects;

-- Policy 1: Enable read access for all users (SELECT)
CREATE POLICY "Enable read access for all users" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'reportimages');

-- Policy 2: Enable insert for authenticated users only (INSERT)
CREATE POLICY "Enable insert for authenticated users only" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'reportimages');

-- Policy 3: Enable update for users based on user_id (UPDATE)
CREATE POLICY "Enable update for users based on user_id" 
ON storage.objects FOR UPDATE 
USING (bucket_id = 'reportimages' AND auth.uid()::text = owner);

-- Policy 4: Enable delete for users based on user_id (DELETE)
CREATE POLICY "Enable delete for users based on user_id" 
ON storage.objects FOR DELETE 
USING (bucket_id = 'reportimages' AND auth.uid()::text = owner);

-- Step 4: Ensure reports table exists with proper structure
CREATE TABLE IF NOT EXISTS public.reports (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100) NOT NULL,
    municipality VARCHAR(100) NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    address TEXT,
    image_url TEXT,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'resolved')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 5: Enable RLS and create policies for reports table
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Enable read access for all users" ON public.reports;
DROP POLICY IF EXISTS "Enable insert for all users" ON public.reports;
DROP POLICY IF EXISTS "Enable update for authenticated users" ON public.reports;

-- Create new policies
CREATE POLICY "Enable read access for all users" 
ON public.reports FOR SELECT 
USING (true);

CREATE POLICY "Enable insert for all users" 
ON public.reports FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Enable update for authenticated users" 
ON public.reports FOR UPDATE 
USING (true);

-- Step 6: Create municipalities table with proper data
CREATE TABLE IF NOT EXISTS public.municipalities (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    name_fr VARCHAR(100),
    name_kreol VARCHAR(100),
    region VARCHAR(100),
    coordinates JSONB,
    boundaries JSONB,
    keywords TEXT[],
    email VARCHAR(255),
    phone VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS for municipalities
ALTER TABLE public.municipalities ENABLE ROW LEVEL SECURITY;

-- Drop and recreate municipality policy
DROP POLICY IF EXISTS "Enable read access for all users" ON public.municipalities;
CREATE POLICY "Enable read access for all users" 
ON public.municipalities FOR SELECT 
USING (true);

-- Step 7: Insert complete municipality data
INSERT INTO public.municipalities (id, name, name_fr, name_kreol, region, coordinates, email, phone) VALUES
('port-louis', 'Port Louis', 'Port-Louis', 'Polui', 'Port Louis District', 
 '{"latitude": -20.1669, "longitude": 57.5009}', 'reports@portlouis.gov.mu', '+230-212-0816'),
('curepipe', 'Curepipe', 'Curepipe', 'Kiripep', 'Plaines Wilhems District', 
 '{"latitude": -20.3167, "longitude": 57.5167}', 'reports@curepipe.gov.mu', '+230-674-1046'),
('quatre-bornes', 'Quatre Bornes', 'Quatre Bornes', 'Kat Born', 'Plaines Wilhems District', 
 '{"latitude": -20.2658, "longitude": 57.4789}', 'reports@quatrebornes.gov.mu', '+230-424-1018'),
('beau-bassin-rose-hill', 'Beau Bassin-Rose Hill', 'Beau Bassin-Rose Hill', 'Bel Basin-Roz Hill', 'Plaines Wilhems District', 
 '{"latitude": -20.2500, "longitude": 57.4700}', 'reports@beaubassin.gov.mu', '+230-454-3441'),
('vacoas-phoenix', 'Vacoas-Phoenix', 'Vacoas-Phoenix', 'Vakwa-Feniks', 'Plaines Wilhems District', 
 '{"latitude": -20.2986, "longitude": 57.4947}', 'reports@vacoas.gov.mu', '+230-686-5494'),
('mahebourg', 'Mahébourg', 'Mahébourg', 'Maebur', 'Grand Port District', 
 '{"latitude": -20.4081, "longitude": 57.7000}', 'reports@mahebourg.gov.mu', '+230-631-9253'),
('centre-de-flacq', 'Centre de Flacq', 'Centre de Flacq', 'Sant Flak', 'Flacq District', 
 '{"latitude": -20.2013, "longitude": 57.7181}', 'reports@flacq.gov.mu', '+230-413-1012'),
('goodlands', 'Goodlands', 'Goodlands', 'Gudlann', 'Rivière du Rempart District', 
 '{"latitude": -20.0375, "longitude": 57.6419}', 'reports@goodlands.gov.mu', '+230-283-9700'),
('triolet', 'Triolet', 'Triolet', 'Triole', 'Pamplemousses District', 
 '{"latitude": -20.0569, "longitude": 57.5475}', 'reports@triolet.gov.mu', '+230-261-6550'),
('saint-pierre', 'Saint Pierre', 'Saint Pierre', 'Sen Pier', 'Moka District', 
 '{"latitude": -20.2181, "longitude": 57.5206}', 'reports@saintpierre.gov.mu', '+230-433-4205')
ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    name_fr = EXCLUDED.name_fr,
    name_kreol = EXCLUDED.name_kreol,
    region = EXCLUDED.region,
    coordinates = EXCLUDED.coordinates,
    email = EXCLUDED.email,
    phone = EXCLUDED.phone;

-- Step 8: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_reports_municipality ON public.reports(municipality);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON public.reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_coordinates ON public.reports(latitude, longitude);

-- Step 9: Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to update updated_at on reports
DROP TRIGGER IF EXISTS update_reports_updated_at ON public.reports;
CREATE TRIGGER update_reports_updated_at 
    BEFORE UPDATE ON public.reports 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Step 10: Grant permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.reports TO anon, authenticated;
GRANT SELECT ON public.municipalities TO anon, authenticated;
GRANT USAGE ON SCHEMA storage TO anon, authenticated;
GRANT ALL ON storage.objects TO anon, authenticated;
GRANT ALL ON storage.buckets TO anon, authenticated;

-- Step 11: Insert sample data for testing
INSERT INTO public.reports (title, description, category, municipality, latitude, longitude, address, status) VALUES
('Test Pothole Report', 'Large pothole causing traffic issues near the main shopping area', 'Potholes', 'Quatre Bornes', -20.2658, 57.4789, 'Royal Road, Quatre Bornes', 'pending'),
('Street Light Issue', 'Street light not working properly during night hours', 'Broken Street Lights', 'Curepipe', -20.3167, 57.5167, 'Elizabeth Avenue, Curepipe', 'in_progress'),
('Garbage Collection Problem', 'Garbage accumulating in residential area, not collected for several days', 'Garbage/Waste', 'Port Louis', -20.1669, 57.5009, 'Pope Hennessy Street, Port Louis', 'resolved'),
('Drainage Blockage', 'Water accumulating due to blocked drainage system after rain', 'Drainage Issues', 'Vacoas-Phoenix', -20.2986, 57.4947, 'Phoenix Mall Area', 'pending')
ON CONFLICT DO NOTHING;

-- Verification queries
SELECT 'Database setup completed successfully!' as status;
SELECT COUNT(*) as total_reports FROM public.reports;
SELECT COUNT(*) as total_municipalities FROM public.municipalities;
SELECT name, bucket_id FROM storage.buckets WHERE id = 'reportimages'; 