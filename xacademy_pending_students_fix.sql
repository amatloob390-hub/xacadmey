-- ============================================================
-- FIX: Teacher/Admin کو زیرِ التوا (pending) students نظر نہ آنا
-- ------------------------------------------------------------
-- وجہ: profiles table کی RLS ہر user کو صرف اپنا profile پڑھنے دیتی ہے،
-- اِس لیے Approvals screen کی سیدھی profiles query خالی آتی تھی۔
--
-- حل: ایک SECURITY DEFINER فنکشن جو (صرف staff کے لیے) RLS سے بالاتر
-- ہو کر زیرِ التوا students کی فہرست لوٹائے۔
--
-- اِس فائل کو Supabase Dashboard → SQL Editor میں چلائیں۔
-- ============================================================

CREATE OR REPLACE FUNCTION public.list_pending_students()
RETURNS TABLE (id UUID, full_name TEXT, email TEXT) AS $$
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;

  RETURN QUERY
    SELECT p.id, p.full_name::text, p.email::text
    FROM public.profiles p
    WHERE p.role = 'student'
      AND (p.is_verified = FALSE OR p.is_verified IS NULL)
    ORDER BY p.full_name::text NULLS LAST;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.list_pending_students() TO authenticated;


-- ============================================================
-- Approve (منظوری) والا function بھی یقینی بنائیں — تاکہ "تصدیق میں
-- مسئلہ" نہ آئے۔ CREATE OR REPLACE ہے، پہلے سے ہو تو update ہو جائے گا۔
-- ============================================================
CREATE OR REPLACE FUNCTION public.staff_verify_student(p_student_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;

  -- اصل کام: student کو verified کریں (login کے لیے یہی کافی ہے)
  UPDATE public.profiles
    SET is_verified = TRUE
    WHERE id = p_student_id;

  -- verification_requests صرف تب update کریں اگر وہ table موجود ہو
  -- (بہت سے DB پر یہ table نہیں ہوتی — اِس لیے error نہ آئے)
  IF to_regclass('public.verification_requests') IS NOT NULL THEN
    UPDATE public.verification_requests
      SET status = 'approved', updated_at = NOW()
      WHERE user_id = p_student_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.staff_verify_student(UUID) TO authenticated;


-- ============================================================
-- Reject (منسوخ): زیرِ التوا اسٹوڈنٹ کی رجسٹریشن مسترد کریں۔
-- پورا اکاؤنٹ (auth.users) حذف کر دیتا ہے — profiles/verification_requests
-- FK cascade سے خود ہٹ جاتے ہیں۔ صرف staff کر سکتا ہے۔
-- ============================================================
CREATE OR REPLACE FUNCTION public.staff_reject_student(p_student_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;

  -- صرف غیر-تصدیق شدہ students ہی مسترد ہو سکتے ہیں (احتیاطاً)
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = p_student_id
      AND role = 'student'
      AND (is_verified = FALSE OR is_verified IS NULL)
  ) THEN
    RAISE EXCEPTION 'NOT_PENDING_STUDENT';
  END IF;

  DELETE FROM auth.users WHERE id = p_student_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.staff_reject_student(UUID) TO authenticated;
