-- Migration to add reporter_email column to reports table

-- 1. Add column if not exists
ALTER TABLE public.reports 
ADD COLUMN IF NOT EXISTS reporter_email VARCHAR(255),
ADD COLUMN IF NOT EXISTS reporter_name VARCHAR(100) DEFAULT 'Anonymous',
ADD COLUMN IF NOT EXISTS reporter_avatar VARCHAR(500);

-- 2. Force refresh of schema cache (sometimes needed for Supabase UI)
NOTIFY pgrst, 'reload schema';

-- 3. Verify it exists
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'reports' AND column_name = 'reporter_email';
