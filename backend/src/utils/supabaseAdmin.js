'use strict';

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceRoleKey) {
  console.error(
    'FATAL: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY environment variables are required.',
  );
  process.exit(1);
}

/** Supabase client with the service_role key — bypasses RLS. */
const supabaseAdmin = createClient(supabaseUrl, supabaseServiceRoleKey);

module.exports = { supabaseAdmin, supabaseUrl };
