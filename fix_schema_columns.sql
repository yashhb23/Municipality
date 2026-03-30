-- Fix Schema: Add missing columns for new UI features
-- Run this in Supabase SQL Editor

-- 1. Add 'subcategory' column (Critical for Upload)
ALTER TABLE public.reports 
ADD COLUMN IF NOT EXISTS subcategory VARCHAR(100);

-- 2. Add 'priority' column (Critical for Sorting/Upload)
ALTER TABLE public.reports 
ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 1;

-- 3. Add 'reporter_' columns if they were missed previously
ALTER TABLE public.reports 
ADD COLUMN IF NOT EXISTS reporter_name VARCHAR(100) DEFAULT 'Anonymous',
ADD COLUMN IF NOT EXISTS reporter_email VARCHAR(255),
ADD COLUMN IF NOT EXISTS reporter_avatar VARCHAR(500),
ADD COLUMN IF NOT EXISTS is_current_user BOOLEAN DEFAULT false; -- For simulated user ownership

-- 4. Refresh schema cache
NOTIFY pgrst, 'reload schema';

-- 5. Verification
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'reports' 
AND column_name IN ('subcategory', 'priority', 'reporter_name');
