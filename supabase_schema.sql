-- ============================================================================
-- FIRESIGHT MOBILE: COMPLETE SUPABASE DATABASE SCHEMA FOR 'INSPECTIONS'
-- ============================================================================
-- Supporting 3 Checklist Types:
--   1. Commercial Fire Safety Inspection ('commercial') - BFP-QSF-FSED-061 Rev 00
--   2. Community Risk & Vulnerability Checklist Urban ('community_urban') - CFPP
--   3. House to House Fire Safety Checklist ('house_to_house')
-- ============================================================================

-- Step 1: Create or Redo the 'inspections' table
CREATE TABLE IF NOT EXISTS public.inspections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    inspector_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    establishment_id UUID,
    checklist_type VARCHAR(50) NOT NULL DEFAULT 'commercial', -- 'commercial', 'community_urban', 'house_to_house'
    inspection_order_no VARCHAR(100),
    date_issued DATE DEFAULT CURRENT_DATE,
    date_inspected TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    business_name VARCHAR(255),
    address TEXT,
    overall_status VARCHAR(50) DEFAULT 'Completed', -- 'Pending', 'In Progress', 'Completed'
    compliance_status VARCHAR(100), -- 'Compliant', 'Non-Compliant', Vulnerability Rating, Safety Interpretation
    recommendation TEXT, -- Notice to Comply, Closure Order, Suggestions, etc.
    risk_level VARCHAR(50) DEFAULT 'Medium', -- 'High', 'Medium', 'Low'
    score INTEGER DEFAULT 0, -- Vulnerability score or Total YES points count
    rating VARCHAR(100), -- Rating description badge
    checklist_data JSONB DEFAULT '{}'::jsonb, -- Full structured response JSON
    hazard_photo_urls JSONB DEFAULT '[]'::jsonb, -- Array of photo URL strings
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 2: Ensure all columns exist if updating an existing table
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS establishment_id UUID;
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS checklist_type VARCHAR(50) DEFAULT 'commercial';
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS inspection_order_no VARCHAR(100);
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS date_issued DATE DEFAULT CURRENT_DATE;
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS date_inspected TIMESTAMP WITH TIME ZONE DEFAULT NOW();
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS business_name VARCHAR(255);
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS overall_status VARCHAR(50) DEFAULT 'Completed';
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS compliance_status VARCHAR(100);
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS recommendation TEXT;
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS risk_level VARCHAR(50) DEFAULT 'Medium';
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS score INTEGER DEFAULT 0;
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS rating VARCHAR(100);
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS checklist_data JSONB DEFAULT '{}'::jsonb;
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS hazard_photo_urls JSONB DEFAULT '[]'::jsonb;
ALTER TABLE public.inspections ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Step 3: Create Performance Indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_inspections_inspector_id ON public.inspections(inspector_id);
CREATE INDEX IF NOT EXISTS idx_inspections_checklist_type ON public.inspections(checklist_type);
CREATE INDEX IF NOT EXISTS idx_inspections_overall_status ON public.inspections(overall_status);
CREATE INDEX IF NOT EXISTS idx_inspections_created_at ON public.inspections(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_inspections_composite ON public.inspections(inspector_id, overall_status, checklist_type);

-- Step 4: Automatic 'updated_at' Timestamp Trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_inspections_updated_at ON public.inspections;
CREATE TRIGGER set_inspections_updated_at
BEFORE UPDATE ON public.inspections
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Step 5: Enable Row Level Security (RLS) & Policies
ALTER TABLE public.inspections ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if re-running
DROP POLICY IF EXISTS "Inspectors can view their own inspections" ON public.inspections;
DROP POLICY IF EXISTS "Inspectors can insert their own inspections" ON public.inspections;
DROP POLICY IF EXISTS "Inspectors can update their own inspections" ON public.inspections;
DROP POLICY IF EXISTS "Inspectors can delete their own inspections" ON public.inspections;
DROP POLICY IF EXISTS "FSIC Officers and Station Officers can manage inspections" ON public.inspections;

-- Allow station_officer and fire_inspector to view/manage inspections
CREATE POLICY "FSIC Officers and Station Officers can manage inspections" 
ON public.inspections FOR ALL 
USING (
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role IN ('station_officer', 'fire_inspector')
  )
);

-- ============================================================================
-- PROFILES TABLE & ROLE-BASED ACCESS CONTROL (RBAC) SCHEMA
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role VARCHAR(50) NOT NULL DEFAULT 'fire_inspector' CHECK (role IN ('station_officer', 'fire_inspector', 'community_risk_officer', 'public_guest')),
    full_name VARCHAR(255),
    badge_number VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view their own profile" ON public.profiles;
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Station Officers can manage profiles" ON public.profiles;
CREATE POLICY "Station Officers can manage profiles" ON public.profiles FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'station_officer'
  )
);

-- Establishments RLS Policies
ALTER TABLE IF EXISTS public.establishments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "FSIC Officers can manage establishments" ON public.establishments;
CREATE POLICY "FSIC Officers can manage establishments" ON public.establishments FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('station_officer', 'fire_inspector')
  )
);

-- OLP Risk Surveys RLS Policies & Column Migrations
ALTER TABLE IF EXISTS public.fire_risk_surveys ADD COLUMN IF NOT EXISTS acknowledged_by VARCHAR(255);
ALTER TABLE IF EXISTS public.fire_risk_surveys ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "OLP Officers can manage risk surveys" ON public.fire_risk_surveys;
CREATE POLICY "OLP Officers can manage risk surveys" ON public.fire_risk_surveys FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('station_officer', 'community_risk_officer')
  )
);

-- Step 6: Create Storage Bucket for Hazard Photos
INSERT INTO storage.buckets (id, name, public) 
VALUES ('hazard-photos', 'hazard-photos', true)
ON CONFLICT (id) DO NOTHING;

-- Storage Policies for 'hazard-photos'
CREATE POLICY "Allow public read access to hazard photos" 
ON storage.objects FOR SELECT 
USING (bucket_id = 'hazard-photos');

CREATE POLICY "Allow authenticated users to upload hazard photos" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'hazard-photos' AND auth.role() = 'authenticated');

CREATE POLICY "Allow public/anon to upload hazard photos" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id = 'hazard-photos');

-- ============================================================================
-- DEDICATED EMERGENCY REPORTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.emergency_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_name VARCHAR(255),
    reporter_contact VARCHAR(100),
    incident_type VARCHAR(100) NOT NULL,
    barangay VARCHAR(100) NOT NULL,
    address TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    description TEXT,
    photo_url TEXT,
    status VARCHAR(50) DEFAULT 'Unverified', -- 'Unverified', 'Dispatched', 'Resolved', 'False Alarm'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Performance Indexes
CREATE INDEX IF NOT EXISTS idx_emergency_reports_barangay ON public.emergency_reports(barangay);
CREATE INDEX IF NOT EXISTS idx_emergency_reports_status ON public.emergency_reports(status);
CREATE INDEX IF NOT EXISTS idx_emergency_reports_created_at ON public.emergency_reports(created_at DESC);

-- Enable RLS & Policies for public reporting
ALTER TABLE public.emergency_reports ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anyone to insert emergency reports" ON public.emergency_reports;
CREATE POLICY "Allow anyone to insert emergency reports" 
ON public.emergency_reports FOR INSERT 
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anyone to view emergency reports" ON public.emergency_reports;
CREATE POLICY "Allow anyone to view emergency reports" 
ON public.emergency_reports FOR SELECT 
USING (true);

DROP POLICY IF EXISTS "Allow anyone to update emergency reports" ON public.emergency_reports;
CREATE POLICY "Allow anyone to update emergency reports" 
ON public.emergency_reports FOR UPDATE 
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anyone to delete emergency reports" ON public.emergency_reports;
CREATE POLICY "Allow anyone to delete emergency reports" 
ON public.emergency_reports FOR DELETE 
USING (true);

-- Ensure public read access for GIS tables (Barangays, Hydrants, Evacuation Centers)
ALTER TABLE IF EXISTS public.barangays ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public to view barangays" ON public.barangays;
CREATE POLICY "Allow public to view barangays" ON public.barangays FOR SELECT USING (true);

ALTER TABLE IF EXISTS public.hydrants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public to view hydrants" ON public.hydrants;
CREATE POLICY "Allow public to view hydrants" ON public.hydrants FOR SELECT USING (true);

ALTER TABLE IF EXISTS public.evacuation_centers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public to view evacuation_centers" ON public.evacuation_centers;
CREATE POLICY "Allow public to view evacuation_centers" ON public.evacuation_centers FOR SELECT USING (true);

-- ============================================================================
-- AUDIT LOGS TABLE & PROFILES IS_ACTIVE MIGRATION
-- ============================================================================
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    performer_name VARCHAR(255),
    performer_role VARCHAR(100),
    action_type VARCHAR(100) NOT NULL,
    target_entity VARCHAR(255),
    details TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_action_type ON public.audit_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id ON public.audit_logs(actor_id);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Station Officers can view audit logs" ON public.audit_logs;
CREATE POLICY "Station Officers can view audit logs"
ON public.audit_logs FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'station_officer'
    )
);

DROP POLICY IF EXISTS "Authenticated users can insert audit logs" ON public.audit_logs;
CREATE POLICY "Authenticated users can insert audit logs"
ON public.audit_logs FOR INSERT
WITH CHECK (auth.role() = 'authenticated');


