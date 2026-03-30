# Database Migrations

## 001_schema_v2.sql

Complete FixMo v2.0 database schema for Supabase PostgreSQL.

### How to apply

1. Open Supabase Dashboard → SQL Editor
2. Paste the contents of `001_schema_v2.sql`
3. Run the script

The script is **idempotent** — safe to run multiple times. It uses:
- `CREATE TABLE IF NOT EXISTS` for all tables
- `IF NOT EXISTS` for all indexes
- `CREATE OR REPLACE` for functions
- `ON CONFLICT DO NOTHING` for seed data
- `ADD COLUMN IF NOT EXISTS` for migration columns

### What it creates

- 16+ tables (reports, profiles, categories, subcategories, alerts, audit_logs, etc.)
- Enums for status, category, alert type, priority, roles
- Comprehensive RLS policies (restrictive by default)
- Triggers for reference number generation, timestamps
- Seed data for 10 Mauritius municipalities and 6 categories with subcategories
- Migration path for existing v1.x data

### Prerequisites

- Enable the `uuid-ossp` and `pgcrypto` extensions (the script does this)
- Enable "Allow anonymous sign-ins" in Authentication → Providers (for the mobile app)
