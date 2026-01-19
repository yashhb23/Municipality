-- FixMo Database Schema for Supabase
-- Run these commands in the Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create reports table
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

-- Create municipalities table for reference
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

-- Create admin_users table for municipality staff
CREATE TABLE IF NOT EXISTS public.admin_users (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    municipality VARCHAR(100) NOT NULL,
    name VARCHAR(255),
    role VARCHAR(50) DEFAULT 'admin' CHECK (role IN ('admin', 'staff', 'manager')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_reports_municipality ON public.reports(municipality);
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON public.reports(created_at);
CREATE INDEX IF NOT EXISTS idx_reports_coordinates ON public.reports(latitude, longitude);

-- Create storage bucket for report images
INSERT INTO storage.buckets (id, name, public) 
VALUES ('report-images', 'report-images', true)
ON CONFLICT (id) DO NOTHING;

-- Set up Row Level Security (RLS)
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.municipalities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_users ENABLE ROW LEVEL SECURITY;

-- Policy: Allow public to read municipalities
CREATE POLICY "Allow public read access to municipalities" 
ON public.municipalities FOR SELECT 
USING (true);

-- Policy: Allow public to insert and read their own reports
CREATE POLICY "Allow public to insert reports" 
ON public.reports FOR INSERT 
WITH CHECK (true);

CREATE POLICY "Allow public to read reports" 
ON public.reports FOR SELECT 
USING (true);

-- Policy: Allow admins to update reports (in production, implement proper auth)
CREATE POLICY "Allow admin updates to reports" 
ON public.reports FOR UPDATE 
USING (true);

-- Insert sample municipalities data
INSERT INTO public.municipalities (id, name, name_fr, name_kreol, region, coordinates, email) VALUES
('port-louis', 'Port Louis', 'Port-Louis', 'Polui', 'Port Louis District', 
 '{"latitude": -20.1669, "longitude": 57.5009}', 'reports@portlouis.mu'),
('curepipe', 'Curepipe', 'Curepipe', 'Kiripep', 'Plaines Wilhems District', 
 '{"latitude": -20.3167, "longitude": 57.5167}', 'reports@curepipe.mu'),
('quatre-bornes', 'Quatre Bornes', 'Quatre Bornes', 'Kat Born', 'Plaines Wilhems District', 
 '{"latitude": -20.2658, "longitude": 57.4789}', 'reports@quatrebornes.mu'),
('beau-bassin-rose-hill', 'Beau Bassin-Rose Hill', 'Beau Bassin-Rose Hill', 'Bel Basin-Roz Hill', 'Plaines Wilhems District', 
 '{"latitude": -20.2500, "longitude": 57.4700}', 'reports@beaubassin.mu'),
('vacoas-phoenix', 'Vacoas-Phoenix', 'Vacoas-Phoenix', 'Vakwa-Feniks', 'Plaines Wilhems District', 
 '{"latitude": -20.2986, "longitude": 57.4947}', 'reports@vacoas.mu')
ON CONFLICT (id) DO NOTHING;

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to update updated_at on reports
CREATE TRIGGER update_reports_updated_at 
BEFORE UPDATE ON public.reports 
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample report data for demo
INSERT INTO public.reports (title, description, category, municipality, latitude, longitude, address, status) VALUES
('Pothole on Royal Road', 'Large pothole causing traffic issues near Phoenix shopping mall.', 'Potholes', 'Vacoas-Phoenix', -20.2986, 57.4947, 'Royal Road, Phoenix', 'pending'),
('Broken Street Light', 'Street light not working on main street, creating safety concerns.', 'Broken Street Lights', 'Curepipe', -20.3167, 57.5167, 'Elizabeth Avenue, Curepipe', 'in_progress'),
('Garbage Collection Delay', 'Garbage not collected for over a week in residential area.', 'Garbage/Waste', 'Quatre Bornes', -20.2658, 57.4789, 'St Jean Road, Quatre Bornes', 'resolved')
ON CONFLICT DO NOTHING;

-- Create view for report statistics by municipality
CREATE OR REPLACE VIEW public.report_stats AS
SELECT 
    municipality,
    COUNT(*) as total_reports,
    COUNT(*) FILTER (WHERE status = 'pending') as pending_reports,
    COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress_reports,
    COUNT(*) FILTER (WHERE status = 'resolved') as resolved_reports,
    AVG(CASE WHEN status = 'resolved' THEN 
        EXTRACT(EPOCH FROM (updated_at - created_at))/86400 
        ELSE NULL END) as avg_resolution_days
FROM public.reports
GROUP BY municipality;

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON public.reports TO anon, authenticated;
GRANT SELECT ON public.municipalities TO anon, authenticated;
GRANT SELECT ON public.report_stats TO anon, authenticated; 