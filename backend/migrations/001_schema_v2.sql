-- ============================================================================
-- FIXMO DATABASE SCHEMA v2.0
-- Complete Supabase PostgreSQL schema for FixMo civic reporting platform
-- Generated: March 2026
-- 
-- MIGRATION STRATEGY:
-- 1. Run this script on a NEW Supabase project, OR
-- 2. Run the migration section at the bottom to upgrade existing schema
-- 
-- This script is idempotent — safe to run multiple times.
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- ENUMS
-- ============================================================================

-- Report status lifecycle
DO $$ BEGIN
  CREATE TYPE report_status AS ENUM (
    'draft',
    'submitted',
    'accepted',
    'rejected',
    'triaged',
    'in_review',
    'assigned',
    'info_needed',
    'in_progress',
    'resolved',
    'reopened',
    'duplicate',
    'archived'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Report category
DO $$ BEGIN
  CREATE TYPE report_category AS ENUM (
    'roads_transport',
    'water_drainage',
    'waste_management',
    'public_facilities',
    'street_lighting',
    'environment'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Alert types
DO $$ BEGIN
  CREATE TYPE alert_type AS ENUM (
    'status_update',
    'resolution',
    'info_needed',
    'duplicate',
    'service_alert',
    'emergency',
    'nearby_issue',
    'moderation',
    'welcome',
    'system'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Alert priority
DO $$ BEGIN
  CREATE TYPE alert_priority AS ENUM (
    'critical',
    'high',
    'normal',
    'low'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- User roles
DO $$ BEGIN
  CREATE TYPE user_role AS ENUM (
    'citizen',
    'staff',
    'municipal_admin',
    'platform_admin'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Moderation status
DO $$ BEGIN
  CREATE TYPE moderation_status AS ENUM (
    'pending',
    'approved',
    'rejected',
    'manual_review'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- Sync status (for tracking offline submissions)
DO $$ BEGIN
  CREATE TYPE sync_status AS ENUM (
    'pending',
    'synced',
    'failed'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- CORE DOMAIN TABLES
-- ============================================================================

-- --------------------------------------------------------------------------
-- MUNICIPALITIES (reference data)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS municipalities (
  id            VARCHAR(50) PRIMARY KEY,
  name          VARCHAR(100) NOT NULL,
  name_fr       VARCHAR(100),
  name_kreol    VARCHAR(100),
  district      VARCHAR(100),
  region        VARCHAR(100),
  coordinates   JSONB,          -- { "lat": -20.xx, "lng": 57.xx }
  boundaries    JSONB,          -- { "north": x, "south": x, "east": x, "west": x }
  keywords      TEXT[],
  email         VARCHAR(255),   -- Official municipality email
  phone         VARCHAR(50),
  website       VARCHAR(255),
  sla_config    JSONB DEFAULT '{}', -- Per-municipality SLA overrides
  is_active     BOOLEAN DEFAULT true,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------------
-- CATEGORIES (taxonomy — moved from hardcoded)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS categories (
  id              VARCHAR(50) PRIMARY KEY,
  name            VARCHAR(100) NOT NULL,
  name_fr         VARCHAR(100),
  name_kreol      VARCHAR(100),
  icon            VARCHAR(50),          -- Icon identifier for client
  default_priority INTEGER DEFAULT 3 CHECK (default_priority BETWEEN 1 AND 4),
  sort_order      INTEGER DEFAULT 0,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS subcategories (
  id              VARCHAR(50) PRIMARY KEY,
  category_id     VARCHAR(50) NOT NULL REFERENCES categories(id),
  name            VARCHAR(100) NOT NULL,
  name_fr         VARCHAR(100),
  name_kreol      VARCHAR(100),
  sort_order      INTEGER DEFAULT 0,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS specific_issues (
  id              VARCHAR(100) PRIMARY KEY,
  subcategory_id  VARCHAR(50) NOT NULL REFERENCES subcategories(id),
  name            VARCHAR(200) NOT NULL,
  name_fr         VARCHAR(200),
  name_kreol      VARCHAR(200),
  priority_override INTEGER CHECK (priority_override BETWEEN 1 AND 4),
  sort_order      INTEGER DEFAULT 0,
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------------
-- REPORTS (core entity — expanded from current schema)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS reports (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- Identity
  reference_number  VARCHAR(20) UNIQUE,  -- FXM-2026-00001
  user_id           UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  device_id         UUID,                -- Anonymous device tracking
  
  -- Classification
  category          VARCHAR(100) NOT NULL,
  subcategory       VARCHAR(100),
  specific_issue    VARCHAR(200),
  
  -- Content
  title             VARCHAR(255) NOT NULL,
  description       TEXT CHECK (char_length(description) <= 2000),
  
  -- Location
  latitude          DOUBLE PRECISION NOT NULL,
  longitude         DOUBLE PRECISION NOT NULL,
  address           TEXT CHECK (char_length(address) <= 500),
  municipality      VARCHAR(100) NOT NULL,
  geohash           VARCHAR(12),         -- For dedup and proximity queries
  
  -- Media
  image_urls        TEXT[] DEFAULT '{}',
  thumbnail_urls    TEXT[] DEFAULT '{}',
  
  -- Status & Lifecycle
  status            VARCHAR(20) DEFAULT 'submitted' 
                    CHECK (status IN ('draft','submitted','accepted','rejected',
                           'triaged','in_review','assigned','info_needed',
                           'in_progress','resolved','reopened','duplicate','archived')),
  
  -- Priority & SLA
  priority          INTEGER DEFAULT 3 CHECK (priority BETWEEN 1 AND 4),
  priority_override INTEGER CHECK (priority_override BETWEEN 1 AND 4),
  sla_deadline      TIMESTAMPTZ,
  sla_breached      BOOLEAN DEFAULT false,
  
  -- Assignment
  assigned_to       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  municipality_id   VARCHAR(50) REFERENCES municipalities(id),
  
  -- Deduplication
  duplicate_of      UUID REFERENCES reports(id) ON DELETE SET NULL,
  duplicate_score   INTEGER DEFAULT 0,
  idempotency_key   UUID UNIQUE,
  content_hash      VARCHAR(64),         -- SHA-256 for dedup
  
  -- Anti-abuse
  abuse_score       INTEGER DEFAULT 0 CHECK (abuse_score BETWEEN 0 AND 100),
  ip_address        INET,
  user_agent        TEXT,
  
  -- Moderation
  moderation_status VARCHAR(20) DEFAULT 'pending'
                    CHECK (moderation_status IN ('pending','approved','rejected','manual_review')),
  
  -- Metadata
  reporter_name     VARCHAR(255) DEFAULT 'Anonymous',
  reporter_email    VARCHAR(255),
  is_offline_submission BOOLEAN DEFAULT false,
  
  -- Timestamps
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW(),
  resolved_at       TIMESTAMPTZ,
  archived_at       TIMESTAMPTZ
);

-- --------------------------------------------------------------------------
-- REPORT STATUS HISTORY (audit trail — immutable)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS report_status_history (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  report_id       UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  old_status      VARCHAR(20),
  new_status      VARCHAR(20) NOT NULL,
  changed_by      UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  changed_by_role VARCHAR(20),
  reason          TEXT CHECK (char_length(reason) <= 500),
  metadata        JSONB DEFAULT '{}',
  is_system_action BOOLEAN DEFAULT false,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------------
-- REPORT NOTES (staff internal notes + citizen public comments)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS report_notes (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  report_id       UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  author_id       UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  author_role     VARCHAR(20),
  content         TEXT NOT NULL CHECK (char_length(content) <= 2000),
  is_internal     BOOLEAN DEFAULT false,  -- true = staff-only, false = visible to citizen
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------------
-- REPORT EVIDENCE (images and attachments)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS report_evidence (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  report_id       UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  uploaded_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  file_url        TEXT NOT NULL,
  thumbnail_url   TEXT,
  file_type       VARCHAR(20) DEFAULT 'image',  -- image, document
  file_size_bytes INTEGER,
  mime_type       VARCHAR(50),
  moderation_status VARCHAR(20) DEFAULT 'pending'
                  CHECK (moderation_status IN ('pending','approved','rejected','manual_review')),
  is_primary      BOOLEAN DEFAULT false,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------------
-- REPORT DUPLICATES (linkage table)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS report_duplicates (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  original_id     UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  duplicate_id    UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  similarity_score INTEGER CHECK (similarity_score BETWEEN 0 AND 100),
  confirmed_by    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(original_id, duplicate_id)
);

-- ============================================================================
-- USER DOMAIN TABLES
-- ============================================================================

-- --------------------------------------------------------------------------
-- PROFILES (extended user data)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name    VARCHAR(100),
  email           VARCHAR(255),
  phone           VARCHAR(20),
  role            VARCHAR(20) DEFAULT 'citizen'
                  CHECK (role IN ('citizen','staff','municipal_admin','platform_admin')),
  municipality_id VARCHAR(50) REFERENCES municipalities(id),  -- For staff: assigned municipality
  avatar_url      TEXT,
  preferred_language VARCHAR(5) DEFAULT 'en',
  preferred_municipality VARCHAR(50),
  is_active       BOOLEAN DEFAULT true,
  abuse_score     INTEGER DEFAULT 0 CHECK (abuse_score BETWEEN 0 AND 100),
  report_count    INTEGER DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------------
-- DEVICE REGISTRATIONS (anonymous device tracking)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS device_registrations (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  device_id       UUID NOT NULL UNIQUE,  -- Installation UUID from client
  user_id         UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  platform        VARCHAR(20),           -- android, ios
  app_version     VARCHAR(20),
  os_version      VARCHAR(20),
  abuse_score     INTEGER DEFAULT 0 CHECK (abuse_score BETWEEN 0 AND 100),
  report_count    INTEGER DEFAULT 0,
  last_report_at  TIMESTAMPTZ,
  first_seen_at   TIMESTAMPTZ DEFAULT NOW(),
  last_seen_at    TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------------
-- PUSH TOKENS (FCM device tokens)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS push_tokens (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id       UUID,
  token           TEXT NOT NULL,
  platform        VARCHAR(20),           -- android, ios
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(token)
);

-- ============================================================================
-- ORGANIZATION DOMAIN TABLES
-- ============================================================================

-- --------------------------------------------------------------------------
-- STAFF ASSIGNMENTS (staff-to-municipality with roles)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS staff_assignments (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  municipality_id VARCHAR(50) NOT NULL REFERENCES municipalities(id),
  role            VARCHAR(20) NOT NULL
                  CHECK (role IN ('staff','municipal_admin')),
  assigned_by     UUID REFERENCES auth.users(id),
  is_active       BOOLEAN DEFAULT true,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  deactivated_at  TIMESTAMPTZ,
  UNIQUE(user_id, municipality_id)
);

-- ============================================================================
-- NOTIFICATION DOMAIN TABLES
-- ============================================================================

-- --------------------------------------------------------------------------
-- ALERTS (in-app notifications)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS alerts (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id       UUID,                  -- For anonymous users
  type            VARCHAR(20) NOT NULL
                  CHECK (type IN ('status_update','resolution','info_needed','duplicate',
                         'service_alert','emergency','nearby_issue','moderation','welcome','system')),
  priority        VARCHAR(10) DEFAULT 'normal'
                  CHECK (priority IN ('critical','high','normal','low')),
  title           VARCHAR(200) NOT NULL,
  body            TEXT CHECK (char_length(body) <= 500),
  metadata        JSONB DEFAULT '{}',    -- { report_id, deep_link, action_required, etc. }
  is_read         BOOLEAN DEFAULT false,
  read_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  expires_at      TIMESTAMPTZ
);

-- --------------------------------------------------------------------------
-- ALERT PREFERENCES (per-user notification settings)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS alert_preferences (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  alert_type      VARCHAR(20) NOT NULL,
  push_enabled    BOOLEAN DEFAULT true,
  in_app_enabled  BOOLEAN DEFAULT true,
  email_enabled   BOOLEAN DEFAULT false,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  updated_at      TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, alert_type)
);

-- ============================================================================
-- SYSTEM DOMAIN TABLES
-- ============================================================================

-- --------------------------------------------------------------------------
-- AUDIT LOGS (comprehensive, immutable)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_logs (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  action          VARCHAR(100) NOT NULL,  -- e.g., 'report.create', 'report.status_change'
  entity_type     VARCHAR(50),            -- e.g., 'report', 'profile', 'staff_assignment'
  entity_id       UUID,
  actor_id        UUID,                   -- User who performed the action
  actor_role      VARCHAR(20),
  ip_address      INET,
  user_agent      TEXT,
  metadata        JSONB DEFAULT '{}',     -- Additional context
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------------
-- IDEMPOTENCY KEYS (request deduplication)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS idempotency_keys (
  key             UUID PRIMARY KEY,
  endpoint        VARCHAR(100) NOT NULL,
  response_status INTEGER,
  response_body   JSONB,
  created_at      TIMESTAMPTZ DEFAULT NOW(),
  expires_at      TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '24 hours')
);

-- --------------------------------------------------------------------------
-- RATE LIMIT COUNTERS (per-device/IP tracking)
-- --------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS rate_limit_counters (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  identifier      VARCHAR(100) NOT NULL,  -- device_id or IP address
  identifier_type VARCHAR(20) NOT NULL,   -- 'device' or 'ip'
  endpoint        VARCHAR(100) NOT NULL,
  window_start    TIMESTAMPTZ NOT NULL,
  request_count   INTEGER DEFAULT 1,
  UNIQUE(identifier, identifier_type, endpoint, window_start)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Reports indexes
CREATE INDEX IF NOT EXISTS idx_reports_user_id ON reports(user_id);
CREATE INDEX IF NOT EXISTS idx_reports_device_id ON reports(device_id);
CREATE INDEX IF NOT EXISTS idx_reports_municipality ON reports(municipality);
CREATE INDEX IF NOT EXISTS idx_reports_municipality_id ON reports(municipality_id);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_category ON reports(category);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_updated_at ON reports(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_coordinates ON reports(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_reports_geohash ON reports(geohash);
CREATE INDEX IF NOT EXISTS idx_reports_assigned_to ON reports(assigned_to);
CREATE INDEX IF NOT EXISTS idx_reports_priority ON reports(priority);
CREATE INDEX IF NOT EXISTS idx_reports_sla_deadline ON reports(sla_deadline) WHERE sla_breached = false;
CREATE INDEX IF NOT EXISTS idx_reports_content_hash ON reports(content_hash);
CREATE INDEX IF NOT EXISTS idx_reports_reference ON reports(reference_number);

-- Status history indexes
CREATE INDEX IF NOT EXISTS idx_status_history_report ON report_status_history(report_id, created_at);

-- Notes indexes
CREATE INDEX IF NOT EXISTS idx_notes_report ON report_notes(report_id, created_at);

-- Evidence indexes
CREATE INDEX IF NOT EXISTS idx_evidence_report ON report_evidence(report_id);

-- Alerts indexes
CREATE INDEX IF NOT EXISTS idx_alerts_user ON alerts(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_device ON alerts(device_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_alerts_unread ON alerts(user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_alerts_type ON alerts(type);
CREATE INDEX IF NOT EXISTS idx_alerts_expires ON alerts(expires_at) WHERE expires_at IS NOT NULL;

-- Audit logs indexes
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at DESC);

-- Device registrations indexes
CREATE INDEX IF NOT EXISTS idx_device_reg_device ON device_registrations(device_id);
CREATE INDEX IF NOT EXISTS idx_device_reg_user ON device_registrations(user_id);

-- Push tokens indexes
CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON push_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_device ON push_tokens(device_id);

-- Rate limit indexes
CREATE INDEX IF NOT EXISTS idx_rate_limit_lookup ON rate_limit_counters(identifier, identifier_type, endpoint, window_start);

-- Idempotency key expiry
CREATE INDEX IF NOT EXISTS idx_idempotency_expires ON idempotency_keys(expires_at);

-- Staff assignments
CREATE INDEX IF NOT EXISTS idx_staff_municipality ON staff_assignments(municipality_id) WHERE is_active = true;

-- ============================================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
DROP TRIGGER IF EXISTS update_reports_updated_at ON reports;
CREATE TRIGGER update_reports_updated_at
  BEFORE UPDATE ON reports
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_municipalities_updated_at ON municipalities;
CREATE TRIGGER update_municipalities_updated_at
  BEFORE UPDATE ON municipalities
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_notes_updated_at ON report_notes;
CREATE TRIGGER update_notes_updated_at
  BEFORE UPDATE ON report_notes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Generate reference number on report insert
CREATE OR REPLACE FUNCTION generate_reference_number()
RETURNS TRIGGER AS $$
DECLARE
  year_str TEXT;
  seq_num INTEGER;
BEGIN
  year_str := EXTRACT(YEAR FROM NOW())::TEXT;
  SELECT COALESCE(MAX(
    CAST(SUBSTRING(reference_number FROM 10) AS INTEGER)
  ), 0) + 1
  INTO seq_num
  FROM reports
  WHERE reference_number LIKE 'FXM-' || year_str || '-%';
  
  NEW.reference_number := 'FXM-' || year_str || '-' || LPAD(seq_num::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS generate_report_reference ON reports;
CREATE TRIGGER generate_report_reference
  BEFORE INSERT ON reports
  FOR EACH ROW
  WHEN (NEW.reference_number IS NULL)
  EXECUTE FUNCTION generate_reference_number();

-- Auto-set resolved_at when status changes to resolved
CREATE OR REPLACE FUNCTION set_resolved_at()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'resolved' AND OLD.status != 'resolved' THEN
    NEW.resolved_at = NOW();
  END IF;
  IF NEW.status = 'archived' AND OLD.status != 'archived' THEN
    NEW.archived_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_report_resolved_at ON reports;
CREATE TRIGGER set_report_resolved_at
  BEFORE UPDATE ON reports
  FOR EACH ROW EXECUTE FUNCTION set_resolved_at();

-- Clean up expired idempotency keys (run via pg_cron or scheduled function)
CREATE OR REPLACE FUNCTION cleanup_expired_idempotency_keys()
RETURNS void AS $$
BEGIN
  DELETE FROM idempotency_keys WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- Clean up expired alerts
CREATE OR REPLACE FUNCTION cleanup_expired_alerts()
RETURNS void AS $$
BEGIN
  UPDATE alerts SET is_read = true WHERE expires_at < NOW() AND is_read = false;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE report_duplicates ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE municipalities ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE subcategories ENABLE ROW LEVEL SECURITY;
ALTER TABLE specific_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE alert_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE idempotency_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE rate_limit_counters ENABLE ROW LEVEL SECURITY;

-- ---- REPORTS ----

-- Public read (map data) — all users can see reports
CREATE POLICY "reports_select_public" ON reports
  FOR SELECT USING (true);

-- Authenticated users can insert (anonymous auth minimum)
CREATE POLICY "reports_insert_authenticated" ON reports
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) IS NOT NULL);

-- Citizens can update own reports within 30 minutes of creation
CREATE POLICY "reports_update_own_recent" ON reports
  FOR UPDATE TO authenticated
  USING (
    (SELECT auth.uid()) = user_id
    AND status = 'submitted'
    AND created_at > NOW() - INTERVAL '30 minutes'
  )
  WITH CHECK (
    (SELECT auth.uid()) = user_id
    AND status = 'submitted'
  );

-- No client-side delete
CREATE POLICY "reports_no_delete" ON reports
  FOR DELETE USING (false);

-- ---- REPORT STATUS HISTORY ----

-- Anyone can read status history for visible reports
CREATE POLICY "status_history_select" ON report_status_history
  FOR SELECT USING (true);

-- Only backend (service_role) can insert
CREATE POLICY "status_history_no_client_insert" ON report_status_history
  FOR INSERT WITH CHECK (false);

-- Immutable
CREATE POLICY "status_history_no_update" ON report_status_history
  FOR UPDATE USING (false);

CREATE POLICY "status_history_no_delete" ON report_status_history
  FOR DELETE USING (false);

-- ---- REPORT NOTES ----

-- Public notes visible to all; internal notes only via backend
CREATE POLICY "notes_select_public" ON report_notes
  FOR SELECT USING (is_internal = false);

-- Only backend can insert notes
CREATE POLICY "notes_no_client_insert" ON report_notes
  FOR INSERT WITH CHECK (false);

CREATE POLICY "notes_no_delete" ON report_notes
  FOR DELETE USING (false);

-- ---- REPORT EVIDENCE ----

CREATE POLICY "evidence_select" ON report_evidence
  FOR SELECT USING (true);

CREATE POLICY "evidence_no_client_insert" ON report_evidence
  FOR INSERT WITH CHECK (false);

CREATE POLICY "evidence_no_delete" ON report_evidence
  FOR DELETE USING (false);

-- ---- PROFILES ----

-- Users can read own profile
CREATE POLICY "profiles_select_own" ON profiles
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);

-- Users can update own profile
CREATE POLICY "profiles_update_own" ON profiles
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

-- Users can insert own profile
CREATE POLICY "profiles_insert_own" ON profiles
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = id);

CREATE POLICY "profiles_no_delete" ON profiles
  FOR DELETE USING (false);

-- ---- MUNICIPALITIES (public reference data) ----

CREATE POLICY "municipalities_select_public" ON municipalities
  FOR SELECT USING (true);

CREATE POLICY "municipalities_no_client_write" ON municipalities
  FOR INSERT WITH CHECK (false);

CREATE POLICY "municipalities_no_client_update" ON municipalities
  FOR UPDATE USING (false);

CREATE POLICY "municipalities_no_client_delete" ON municipalities
  FOR DELETE USING (false);

-- ---- CATEGORIES (public reference data) ----

CREATE POLICY "categories_select_public" ON categories
  FOR SELECT USING (true);

CREATE POLICY "categories_no_client_write" ON categories
  FOR INSERT WITH CHECK (false);

CREATE POLICY "subcategories_select_public" ON subcategories
  FOR SELECT USING (true);

CREATE POLICY "subcategories_no_client_write" ON subcategories
  FOR INSERT WITH CHECK (false);

CREATE POLICY "issues_select_public" ON specific_issues
  FOR SELECT USING (true);

CREATE POLICY "issues_no_client_write" ON specific_issues
  FOR INSERT WITH CHECK (false);

-- ---- ALERTS ----

-- Users can read own alerts
CREATE POLICY "alerts_select_own" ON alerts
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- Users can update own alerts (mark as read)
CREATE POLICY "alerts_update_own" ON alerts
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- Only backend can insert alerts
CREATE POLICY "alerts_no_client_insert" ON alerts
  FOR INSERT WITH CHECK (false);

CREATE POLICY "alerts_no_delete" ON alerts
  FOR DELETE USING (false);

-- ---- ALERT PREFERENCES ----

CREATE POLICY "alert_prefs_select_own" ON alert_preferences
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "alert_prefs_upsert_own" ON alert_preferences
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "alert_prefs_update_own" ON alert_preferences
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- ---- PUSH TOKENS ----

CREATE POLICY "push_tokens_select_own" ON push_tokens
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "push_tokens_insert_own" ON push_tokens
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "push_tokens_update_own" ON push_tokens
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

CREATE POLICY "push_tokens_delete_own" ON push_tokens
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

-- ---- DEVICE REGISTRATIONS ----

CREATE POLICY "device_reg_select_own" ON device_registrations
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = user_id OR user_id IS NULL);

CREATE POLICY "device_reg_insert" ON device_registrations
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "device_reg_update_own" ON device_registrations
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id OR user_id IS NULL);

-- ---- AUDIT LOGS (no client access) ----

CREATE POLICY "audit_no_client_select" ON audit_logs
  FOR SELECT USING (false);

CREATE POLICY "audit_no_client_insert" ON audit_logs
  FOR INSERT WITH CHECK (false);

CREATE POLICY "audit_no_update" ON audit_logs
  FOR UPDATE USING (false);

CREATE POLICY "audit_no_delete" ON audit_logs
  FOR DELETE USING (false);

-- ---- STAFF ASSIGNMENTS (no client access) ----

CREATE POLICY "staff_no_client_select" ON staff_assignments
  FOR SELECT USING (false);

CREATE POLICY "staff_no_client_write" ON staff_assignments
  FOR INSERT WITH CHECK (false);

-- ---- IDEMPOTENCY KEYS (no client access) ----

CREATE POLICY "idempotency_no_client" ON idempotency_keys
  FOR SELECT USING (false);

-- ---- RATE LIMIT COUNTERS (no client access) ----

CREATE POLICY "rate_limit_no_client" ON rate_limit_counters
  FOR SELECT USING (false);

-- ============================================================================
-- SEED DATA — MUNICIPALITIES
-- ============================================================================

INSERT INTO municipalities (id, name, name_fr, district, coordinates, boundaries, email)
VALUES
  ('port-louis', 'Port Louis', 'Port-Louis', 'Port Louis District',
   '{"lat": -20.1609, "lng": 57.5012}',
   '{"north": -20.13, "south": -20.19, "east": 57.53, "west": 57.47}',
   NULL),
  ('curepipe', 'Curepipe', 'Curepipe', 'Plaines Wilhems District',
   '{"lat": -20.3162, "lng": 57.5166}',
   '{"north": -20.28, "south": -20.35, "east": 57.55, "west": 57.48}',
   NULL),
  ('quatre-bornes', 'Quatre Bornes', 'Quatre Bornes', 'Plaines Wilhems District',
   '{"lat": -20.2648, "lng": 57.4797}',
   '{"north": -20.24, "south": -20.29, "east": 57.51, "west": 57.45}',
   NULL),
  ('beau-bassin-rose-hill', 'Beau Bassin-Rose Hill', 'Beau Bassin-Rose Hill', 'Plaines Wilhems District',
   '{"lat": -20.2338, "lng": 57.4679}',
   '{"north": -20.21, "south": -20.26, "east": 57.50, "west": 57.43}',
   NULL),
  ('vacoas-phoenix', 'Vacoas-Phoenix', 'Vacoas-Phoenix', 'Plaines Wilhems District',
   '{"lat": -20.2983, "lng": 57.4966}',
   '{"north": -20.27, "south": -20.33, "east": 57.53, "west": 57.46}',
   NULL),
  ('mahebourg', 'Mahébourg', 'Mahébourg', 'Grand Port District',
   '{"lat": -20.4081, "lng": 57.7000}',
   '{"north": -20.38, "south": -20.43, "east": 57.73, "west": 57.67}',
   NULL),
  ('centre-de-flacq', 'Centre de Flacq', 'Centre de Flacq', 'Flacq District',
   '{"lat": -20.1919, "lng": 57.7131}',
   '{"north": -20.17, "south": -20.22, "east": 57.74, "west": 57.68}',
   NULL),
  ('goodlands', 'Goodlands', 'Goodlands', 'Rivière du Rempart District',
   '{"lat": -20.0353, "lng": 57.6506}',
   '{"north": -20.01, "south": -20.06, "east": 57.68, "west": 57.62}',
   NULL),
  ('triolet', 'Triolet', 'Triolet', 'Pamplemousses District',
   '{"lat": -20.0569, "lng": 57.5486}',
   '{"north": -20.03, "south": -20.08, "east": 57.58, "west": 57.52}',
   NULL),
  ('saint-pierre', 'Saint Pierre', 'Saint Pierre', 'Moka District',
   '{"lat": -20.2281, "lng": 57.5253}',
   '{"north": -20.20, "south": -20.26, "east": 57.56, "west": 57.49}',
   NULL)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- SEED DATA — CATEGORIES
-- ============================================================================

INSERT INTO categories (id, name, name_fr, icon, default_priority, sort_order) VALUES
  ('roads_transport', 'Roads & Transport', 'Routes & Transport', 'road', 3, 1),
  ('water_drainage', 'Water & Drainage', 'Eau & Drainage', 'water_drop', 2, 2),
  ('waste_management', 'Waste Management', 'Gestion des Déchets', 'delete', 3, 3),
  ('public_facilities', 'Public Facilities', 'Installations Publiques', 'park', 3, 4),
  ('street_lighting', 'Street Lighting', 'Éclairage Public', 'lightbulb', 2, 5),
  ('environment', 'Environment', 'Environnement', 'eco', 3, 6)
ON CONFLICT (id) DO NOTHING;

INSERT INTO subcategories (id, category_id, name, name_fr, sort_order) VALUES
  ('road_damage', 'roads_transport', 'Road Damage', 'Dommages Routiers', 1),
  ('traffic_issues', 'roads_transport', 'Traffic Issues', 'Problèmes de Circulation', 2),
  ('public_transport', 'roads_transport', 'Public Transport', 'Transport Public', 3),
  ('water_supply', 'water_drainage', 'Water Supply', 'Approvisionnement en Eau', 1),
  ('drainage', 'water_drainage', 'Drainage', 'Drainage', 2),
  ('waste_water', 'water_drainage', 'Waste Water', 'Eaux Usées', 3),
  ('collection', 'waste_management', 'Collection', 'Collecte', 1),
  ('illegal_dumping', 'waste_management', 'Illegal Dumping', 'Décharge Illégale', 2),
  ('recycling', 'waste_management', 'Recycling', 'Recyclage', 3),
  ('parks_recreation', 'public_facilities', 'Parks & Recreation', 'Parcs & Loisirs', 1),
  ('public_buildings', 'public_facilities', 'Public Buildings', 'Bâtiments Publics', 2),
  ('public_toilets', 'public_facilities', 'Public Toilets', 'Toilettes Publiques', 3),
  ('lighting_issues', 'street_lighting', 'Lighting Issues', 'Problèmes d''Éclairage', 1),
  ('electrical', 'street_lighting', 'Electrical', 'Électrique', 2),
  ('pollution', 'environment', 'Pollution', 'Pollution', 1),
  ('green_spaces', 'environment', 'Green Spaces', 'Espaces Verts', 2),
  ('animals', 'environment', 'Animals', 'Animaux', 3)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- MIGRATION FROM EXISTING SCHEMA
-- 
-- Run these statements if upgrading from FixMo v1.x schema.
-- They are safe to run on a fresh database (they check for existence).
-- ============================================================================

-- Add new columns to existing reports table (if upgrading)
DO $$ BEGIN
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS reference_number VARCHAR(20) UNIQUE;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS device_id UUID;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS specific_issue VARCHAR(200);
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS geohash VARCHAR(12);
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS thumbnail_urls TEXT[] DEFAULT '{}';
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS priority_override INTEGER;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS sla_deadline TIMESTAMPTZ;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS sla_breached BOOLEAN DEFAULT false;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS assigned_to UUID;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS municipality_id VARCHAR(50);
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS duplicate_of UUID;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS duplicate_score INTEGER DEFAULT 0;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS idempotency_key UUID;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS content_hash VARCHAR(64);
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS abuse_score INTEGER DEFAULT 0;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS ip_address INET;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS user_agent TEXT;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS moderation_status VARCHAR(20) DEFAULT 'pending';
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS is_offline_submission BOOLEAN DEFAULT false;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ;
  ALTER TABLE reports ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

-- Migrate existing report statuses to new enum values
-- Old: 'pending' → New: 'accepted' (they passed the old flow)
-- Old: 'in_progress' → New: 'in_progress' (same)
-- Old: 'resolved' → New: 'resolved' (same)
-- Old: 'rejected' → New: 'rejected' (same)
UPDATE reports SET status = 'accepted' WHERE status = 'pending' AND reference_number IS NULL;

-- Generate reference numbers for existing reports
-- (The trigger handles new inserts; this backfills existing)
DO $$ 
DECLARE
  r RECORD;
  seq INTEGER := 0;
  yr TEXT;
BEGIN
  yr := EXTRACT(YEAR FROM NOW())::TEXT;
  FOR r IN SELECT id FROM reports WHERE reference_number IS NULL ORDER BY created_at ASC
  LOOP
    seq := seq + 1;
    UPDATE reports SET reference_number = 'FXM-' || yr || '-' || LPAD(seq::TEXT, 5, '0')
    WHERE id = r.id;
  END LOOP;
END $$;

-- Drop columns that are no longer needed (after client code is updated)
-- UNCOMMENT THESE AFTER CLIENT CODE IS UPDATED:
-- ALTER TABLE reports DROP COLUMN IF EXISTS is_current_user;
-- ALTER TABLE reports DROP COLUMN IF EXISTS reporter_avatar;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
