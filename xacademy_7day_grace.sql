-- ============================================================
-- XACADEMY: Update Grace Period to 7 Days for Students
-- ============================================================

-- 1. Update enroll_in_class RPC function to grant 7 days grace period
CREATE OR REPLACE FUNCTION public.enroll_in_class(p_class_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO public.enrollments (user_id, class_id, grace_until)
  VALUES (v_user_id, p_class_id, NOW() + INTERVAL '7 days')
  ON CONFLICT (user_id, class_id) DO UPDATE
  SET grace_until = GREATEST(enrollments.grace_until, NOW() + INTERVAL '7 days');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Update existing unpaid enrollments to give them 7 days grace from now
UPDATE public.enrollments
SET grace_until = NOW() + INTERVAL '7 days'
WHERE payment_status IS NULL OR payment_status != 'paid';
