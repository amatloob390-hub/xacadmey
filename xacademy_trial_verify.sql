-- ============================================================
-- STUDENT VERIFY کے دو طریقے:
--   1) فیس سلپ کے ساتھ (مکمل/paid رکنیت)
--   2) 7 دن کی ٹرائل (مقررہ مدت کے بعد رسائی بند)
-- ------------------------------------------------------------
-- Supabase Dashboard → SQL Editor میں چلائیں۔
-- ============================================================

-- 1) profiles میں ٹرائل کے کالمز
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS is_trial    BOOLEAN DEFAULT FALSE;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS trial_until TIMESTAMPTZ;

-- 2) فیس سلپ کے ساتھ منظوری (paid — مستقل رسائی)
CREATE OR REPLACE FUNCTION public.staff_verify_student_paid(p_student_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;

  UPDATE public.profiles
    SET is_verified = TRUE,
        is_trial    = FALSE,
        trial_until = NULL
    WHERE id = p_student_id;

  IF to_regclass('public.verification_requests') IS NOT NULL THEN
    UPDATE public.verification_requests
      SET status = 'approved', updated_at = NOW()
      WHERE user_id = p_student_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.staff_verify_student_paid(UUID) TO authenticated;

-- 3) ٹرائل کے ساتھ منظوری (پہلے سے طے شدہ 7 دن)
CREATE OR REPLACE FUNCTION public.staff_verify_student_trial(
  p_student_id UUID,
  p_days       INT DEFAULT 7
)
RETURNS VOID AS $$
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;

  UPDATE public.profiles
    SET is_verified = TRUE,
        is_trial    = TRUE,
        trial_until = NOW() + (p_days || ' days')::INTERVAL
    WHERE id = p_student_id;

  IF to_regclass('public.verification_requests') IS NOT NULL THEN
    UPDATE public.verification_requests
      SET status = 'approved', updated_at = NOW()
      WHERE user_id = p_student_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.staff_verify_student_trial(UUID, INT) TO authenticated;
