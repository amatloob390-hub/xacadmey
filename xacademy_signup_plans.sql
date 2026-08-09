-- ============================================================
-- SIGNUP PLANS: Trial (free 7-day) بمقابلہ Paid
-- ------------------------------------------------------------
-- Supabase Dashboard → SQL Editor میں چلائیں۔
-- ============================================================

-- 1) profiles کے کالمز
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_trial    BOOLEAN     DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS trial_until TIMESTAMPTZ;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS plan        TEXT        DEFAULT 'paid'; -- 'trial' | 'paid'
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS signup_at   TIMESTAMPTZ DEFAULT NOW();

-- 2) self-service trial: student signup کے فوراً بعد یہ کال کرتا ہے
--    (کوئی teacher verification نہیں — خودکار 7 دن)
CREATE OR REPLACE FUNCTION public.self_start_trial(p_days INT DEFAULT 7)
RETURNS VOID AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'NOT_AUTHENTICATED';
  END IF;

  UPDATE public.profiles
    SET is_verified = TRUE,
        is_trial    = TRUE,
        plan        = 'trial',
        trial_until = NOW() + (p_days || ' days')::INTERVAL,
        signup_at   = COALESCE(signup_at, NOW())
    WHERE id = auth.uid()
      AND role = 'student';   -- صرف students ٹرائل لے سکتے ہیں
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.self_start_trial(INT) TO authenticated;

-- 3) Paid verify: plan='paid' سیٹ کرے اور ٹرائل صاف کرے
CREATE OR REPLACE FUNCTION public.staff_verify_student_paid(p_student_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT public.is_staff() THEN RAISE EXCEPTION 'NOT_ALLOWED'; END IF;

  UPDATE public.profiles
    SET is_verified = TRUE,
        is_trial    = FALSE,
        trial_until = NULL,
        plan        = 'paid'
    WHERE id = p_student_id;

  IF to_regclass('public.verification_requests') IS NOT NULL THEN
    UPDATE public.verification_requests
      SET status = 'approved', updated_at = NOW()
      WHERE user_id = p_student_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.staff_verify_student_paid(UUID) TO authenticated;
