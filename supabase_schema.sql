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

-- Allow logged-in inspectors to view their inspections
CREATE POLICY "Inspectors can view their own inspections" 
ON public.inspections FOR SELECT 
USING (auth.uid() = inspector_id);

-- Allow logged-in inspectors to insert new inspection records
CREATE POLICY "Inspectors can insert their own inspections" 
ON public.inspections FOR INSERT 
WITH CHECK (auth.uid() = inspector_id);

-- Allow logged-in inspectors to update their inspection records
CREATE POLICY "Inspectors can update their own inspections" 
ON public.inspections FOR UPDATE 
USING (auth.uid() = inspector_id);

-- Allow logged-in inspectors to delete their inspection records
CREATE POLICY "Inspectors can delete their own inspections" 
ON public.inspections FOR DELETE 
USING (auth.uid() = inspector_id);

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

