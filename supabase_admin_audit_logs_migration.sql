-- ============================================================================
-- FIRESIGHT MOBILE: AUDIT LOGS TABLE & PROFILES IS_ACTIVE MIGRATION SCRIPT
-- ============================================================================

-- Step 1: Ensure 'is_active' column exists on public.profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;

-- Step 2: Create 'audit_logs' table for tracking administrative & officer actions
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

-- Step 3: Indexes for high-performance log querying and filtering
CREATE INDEX IF NOT EXISTS idx_audit_logs_action_type ON public.audit_logs(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON public.audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor_id ON public.audit_logs(actor_id);

-- Step 4: Enable Row Level Security (RLS) & Policies
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

-- Allow Station Officers to view all audit logs
DROP POLICY IF EXISTS "Station Officers can view audit logs" ON public.audit_logs;
CREATE POLICY "Station Officers can view audit logs"
ON public.audit_logs FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'station_officer'
    )
);

-- Allow authenticated officers to write audit log entries
DROP POLICY IF EXISTS "Authenticated users can insert audit logs" ON public.audit_logs;
CREATE POLICY "Authenticated users can insert audit logs"
ON public.audit_logs FOR INSERT
WITH CHECK (auth.role() = 'authenticated');
