-- ============================================================================
-- FIRESIGHT MIGRATION: NOTIFICATIONS & FCM TOKENS FOR INSPECTOR ALERTS
-- ============================================================================

-- 1. Add FCM Token storage to profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS fcm_token_updated_at TIMESTAMPTZ;

-- 2. Create In-App Notifications table
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type VARCHAR(50) DEFAULT 'inspection_scheduled',
  data JSONB DEFAULT '{}'::jsonb,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON public.notifications(user_id, is_read);

-- 3. Enable RLS on notifications table
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read their own notifications" ON public.notifications;
CREATE POLICY "Users can read their own notifications"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own notifications" ON public.notifications;
CREATE POLICY "Users can update their own notifications"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Allow insert notifications" ON public.notifications;
CREATE POLICY "Allow insert notifications"
  ON public.notifications FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- 4. Automatic Database Trigger: Insert in-app notification when an inspection is scheduled/assigned
CREATE OR REPLACE FUNCTION notify_inspector_on_schedule()
RETURNS TRIGGER AS $$
DECLARE
  v_inspector_id UUID;
  v_title TEXT;
  v_body TEXT;
BEGIN
  -- Check if inspector is assigned on INSERT or reassigned on UPDATE
  IF (TG_OP = 'INSERT' AND NEW.inspector_id IS NOT NULL) OR 
     (TG_OP = 'UPDATE' AND NEW.inspector_id IS NOT NULL AND (OLD.inspector_id IS NULL OR OLD.inspector_id != NEW.inspector_id)) THEN
     
     v_inspector_id := NEW.inspector_id;
     v_title := 'New Inspection Scheduled';
     v_body := 'You have been assigned to inspect ' || COALESCE(NEW.business_name, 'an establishment') || ' (Order: ' || COALESCE(NEW.inspection_order_no, 'N/A') || ').';
     
     INSERT INTO public.notifications (user_id, title, body, type, data)
     VALUES (
       v_inspector_id,
       v_title,
       v_body,
       'inspection_scheduled',
       jsonb_build_object(
         'inspection_id', NEW.id,
         'inspection_order_no', NEW.inspection_order_no,
         'business_name', NEW.business_name,
         'address', NEW.address,
         'date_issued', NEW.date_issued,
         'date_inspected', NEW.date_inspected
       )
     );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_notify_inspector_on_schedule ON public.inspections;
CREATE TRIGGER trigger_notify_inspector_on_schedule
AFTER INSERT OR UPDATE OF inspector_id, business_name, overall_status
ON public.inspections
FOR EACH ROW
EXECUTE FUNCTION notify_inspector_on_schedule();
