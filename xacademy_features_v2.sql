-- ============================================================
-- XACADEMY: Features v2
--   1) Teacher/Manager verification unlocks student login + join
--   2) Teacher adds students (email invite  OR  enroll existing)
--   3) Sub-admin / Manager role (verify students, approve payments, add students)
--   4) After a class is 7 days old, no NEW enrollment (already-enrolled stay)
--
-- اسے Supabase SQL Editor میں چلائیں (پورا فائل ایک بار)۔
-- محفوظ ہے: دوبارہ چلانے پر بھی ٹھیک (idempotent)۔
-- ============================================================

-- ------------------------------------------------------------
-- 0. Base columns / role support
-- ------------------------------------------------------------

-- class کی عمر ناپنے کیلئے created_at (۷ دن lock)
ALTER TABLE public.classes
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- is_verified یقینی بنائیں
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;

-- profiles میں email کالم (اصل ای میل auth.users میں ہوتی ہے) — بنا کر backfill کریں
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS email TEXT;

UPDATE public.profiles p
  SET email = u.email
  FROM auth.users u
  WHERE u.id = p.id AND (p.email IS NULL OR p.email = '');

-- 'manager' سمیت رولز کی اجازت (اگر پہلے کوئی CHECK constraint ہو تو ہٹا کر نیا لگائیں)
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('student', 'manager', 'teacher', 'admin'));

-- ------------------------------------------------------------
-- 1. Helper: موجودہ لاگ اِن یوزر کا رول
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- staff = teacher / admin / manager
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS BOOLEAN AS $$
  SELECT public.my_role() IN ('teacher', 'admin', 'manager');
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ------------------------------------------------------------
-- 2. Student invites (teacher email سے دعوت دے، signup پر خودکار verify)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_invites (
  id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  email        TEXT NOT NULL UNIQUE,
  full_name    TEXT,
  class_id     UUID REFERENCES public.classes(id) ON DELETE SET NULL,
  invited_by   UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
  consumed     BOOLEAN DEFAULT FALSE,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.student_invites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "staff manage invites" ON public.student_invites;
CREATE POLICY "staff manage invites" ON public.student_invites
  FOR ALL USING (public.is_staff()) WITH CHECK (public.is_staff());

-- claim_invite(): signUp کے بالکل آخر میں client یہ RPC کال کرے۔
-- خود لاگ اِن یوزر کے طور پر چلتا ہے — اگر اس کی ای میل کو دعوت دی گئی ہو تو
-- خودکار verify + (اگر class ہو) enroll کر کے دعوت consumed کر دیتا ہے۔
-- (ٹرگر کے بجائے صریح RPC — تاکہ handle_new_user اور client upsert کی
--  ترتیب سے متاثر نہ ہو؛ یہ ہمیشہ سب سے آخر میں چلتا ہے۔)
CREATE OR REPLACE FUNCTION public.claim_invite()
RETURNS TEXT AS $$
DECLARE
  v_uid    UUID := auth.uid();
  v_email  TEXT;
  v_invite public.student_invites%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT email INTO v_email FROM public.profiles WHERE id = v_uid;
  IF v_email IS NULL THEN
    SELECT email INTO v_email FROM auth.users WHERE id = v_uid;
  END IF;

  SELECT * INTO v_invite
  FROM public.student_invites
  WHERE LOWER(email) = LOWER(v_email) AND consumed = FALSE
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN 'NONE';
  END IF;

  -- خودکار تصدیق: بغیر انتظار کے لاگ اِن ممکن
  UPDATE public.profiles SET is_verified = TRUE WHERE id = v_uid;

  IF v_invite.class_id IS NOT NULL THEN
    INSERT INTO public.enrollments (student_id, class_id, grace_until)
    VALUES (v_uid, v_invite.class_id, NOW() + INTERVAL '7 days')
    ON CONFLICT (student_id, class_id) DO UPDATE
      SET grace_until = GREATEST(public.enrollments.grace_until, NOW() + INTERVAL '7 days');
  END IF;

  UPDATE public.student_invites SET consumed = TRUE WHERE id = v_invite.id;

  RETURN 'CLAIMED';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 3. Teacher/Manager: نیا اسٹوڈنٹ ای میل سے دعوت دے (ابھی رجسٹرڈ نہیں)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.invite_student(
  p_email     TEXT,
  p_full_name TEXT DEFAULT NULL,
  p_class_id  UUID DEFAULT NULL
)
RETURNS TEXT AS $$
DECLARE
  v_email TEXT := LOWER(TRIM(p_email));
  v_id    UUID;
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;

  -- کیا یہ ای میل پہلے سے رجسٹرڈ ہے؟ تو فوراً verify + enroll
  SELECT id INTO v_id FROM public.profiles WHERE LOWER(email) = v_email LIMIT 1;

  IF v_id IS NOT NULL THEN
    UPDATE public.profiles SET is_verified = TRUE WHERE id = v_id;
    IF p_class_id IS NOT NULL THEN
      INSERT INTO public.enrollments (student_id, class_id, grace_until)
      VALUES (v_id, p_class_id, NOW() + INTERVAL '7 days')
      ON CONFLICT (student_id, class_id) DO UPDATE
        SET grace_until = GREATEST(public.enrollments.grace_until, NOW() + INTERVAL '7 days');
    END IF;
    RETURN 'EXISTING_VERIFIED';
  END IF;

  -- ورنہ دعوت محفوظ کریں (signup پر خودکار فعال ہو گی)
  INSERT INTO public.student_invites (email, full_name, class_id, invited_by)
  VALUES (v_email, p_full_name, p_class_id, auth.uid())
  ON CONFLICT (email) DO UPDATE
    SET full_name  = COALESCE(EXCLUDED.full_name, public.student_invites.full_name),
        class_id   = COALESCE(EXCLUDED.class_id, public.student_invites.class_id),
        invited_by = EXCLUDED.invited_by,
        consumed   = FALSE;

  RETURN 'INVITED';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 4. Teacher/Manager: پہلے سے رجسٹرڈ اسٹوڈنٹ کو ای میل سے enroll/verify
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.staff_add_existing_student(
  p_email    TEXT,
  p_class_id UUID DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
  v_id UUID;
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;

  SELECT id INTO v_id FROM public.profiles WHERE LOWER(email) = LOWER(TRIM(p_email)) LIMIT 1;
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'STUDENT_NOT_FOUND';
  END IF;

  UPDATE public.profiles SET is_verified = TRUE WHERE id = v_id;

  IF p_class_id IS NOT NULL THEN
    INSERT INTO public.enrollments (student_id, class_id, grace_until)
    VALUES (v_id, p_class_id, NOW() + INTERVAL '7 days')
    ON CONFLICT (student_id, class_id) DO UPDATE
      SET grace_until = GREATEST(public.enrollments.grace_until, NOW() + INTERVAL '7 days');
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 5. Teacher/Manager: اسٹوڈنٹ کی تصدیق (login + join کھل جائے)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.staff_verify_student(p_student_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;

  UPDATE public.profiles SET is_verified = TRUE WHERE id = p_student_id;

  UPDATE public.verification_requests
    SET status = 'approved', updated_at = NOW()
    WHERE user_id = p_student_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 6. صرف Teacher/Admin: کسی کو رول دے (manager/sub-admin بنائے)
--     manager دوسروں کو رول نہیں دے سکتا۔
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_user_role(
  p_email TEXT,
  p_role  TEXT
)
RETURNS VOID AS $$
DECLARE
  v_caller_role TEXT := public.my_role();
  v_target_id   UUID;
BEGIN
  IF v_caller_role NOT IN ('teacher', 'admin') THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;

  IF p_role NOT IN ('student', 'manager', 'teacher', 'admin') THEN
    RAISE EXCEPTION 'BAD_ROLE';
  END IF;

  -- 'admin' رول صرف admin دے سکتا ہے
  IF p_role = 'admin' AND v_caller_role <> 'admin' THEN
    RAISE EXCEPTION 'ADMIN_ONLY';
  END IF;

  SELECT id INTO v_target_id FROM public.profiles WHERE LOWER(email) = LOWER(TRIM(p_email)) LIMIT 1;
  IF v_target_id IS NULL THEN
    RAISE EXCEPTION 'USER_NOT_FOUND';
  END IF;

  UPDATE public.profiles
    SET role = p_role,
        is_verified = CASE WHEN p_role <> 'student' THEN TRUE ELSE is_verified END
    WHERE id = v_target_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- staff فہرست (Manage Roles اسکرین کیلئے)
CREATE OR REPLACE FUNCTION public.list_staff()
RETURNS TABLE (id UUID, full_name TEXT, email TEXT, role TEXT) AS $$
  SELECT id, full_name, email, role
  FROM public.profiles
  WHERE public.is_staff() AND role IN ('manager', 'teacher', 'admin')
  ORDER BY role, full_name;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ------------------------------------------------------------
-- 7. enroll_in_class: ۷ دن lock — class 7 دن پرانی ہو تو نیا enroll بند
--     (پہلے سے enrolled متاثر نہیں ہوتے)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enroll_in_class(p_class_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id      UUID := auth.uid();
  v_created_at   TIMESTAMPTZ;
  v_already      BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  SELECT created_at INTO v_created_at FROM public.classes WHERE id = p_class_id;
  IF v_created_at IS NULL THEN
    RAISE EXCEPTION 'CLASS_NOT_FOUND';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.enrollments
    WHERE student_id = v_user_id AND class_id = p_class_id
  ) INTO v_already;

  -- class ۷ دن سے پرانی اور یہ نیا اسٹوڈنٹ ہے → enrollment بند
  IF NOT v_already AND v_created_at < (NOW() - INTERVAL '7 days') THEN
    RAISE EXCEPTION 'ENROLLMENT_CLOSED';
  END IF;

  INSERT INTO public.enrollments (student_id, class_id, grace_until)
  VALUES (v_user_id, p_class_id, NOW() + INTERVAL '7 days')
  ON CONFLICT (student_id, class_id) DO UPDATE
    SET grace_until = GREATEST(public.enrollments.grace_until, NOW() + INTERVAL '7 days');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 8. get_available_classes: ۷ دن سے پرانی (بند) کلاسیں نئے اسٹوڈنٹ کو نہ دکھائیں
--     نوٹ: اگر آپ کے پروجیکٹ میں اس RPC کی مختلف ساخت ہو تو
--     صرف WHERE شرط والا حصہ اپنی موجودہ definition میں شامل کریں:
--       AND c.created_at >= (NOW() - INTERVAL '7 days')
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_available_classes()
RETURNS TABLE (
  class_id     UUID,
  title        TEXT,
  scheduled_at TIMESTAMPTZ,
  duration_min INT,
  is_active    BOOLEAN
) AS $$
  SELECT c.id, c.title, c.scheduled_at, c.duration_min, c.is_active
  FROM public.classes c
  WHERE c.created_at >= (NOW() - INTERVAL '7 days')
    AND NOT EXISTS (
      SELECT 1 FROM public.enrollments e
      WHERE e.class_id = c.id AND e.student_id = auth.uid()
    )
  ORDER BY c.scheduled_at ASC;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ------------------------------------------------------------
-- 9. Permissions (RPC calls)
-- ------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.my_role()                     TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_staff()                    TO authenticated;
GRANT EXECUTE ON FUNCTION public.claim_invite()                TO authenticated;
GRANT EXECUTE ON FUNCTION public.invite_student(TEXT, TEXT, UUID)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_add_existing_student(TEXT, UUID)   TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_verify_student(UUID)     TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_user_role(TEXT, TEXT)      TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_staff()                  TO authenticated;
GRANT EXECUTE ON FUNCTION public.enroll_in_class(UUID)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_available_classes()       TO authenticated;

-- ------------------------------------------------------------
-- 10. ادائیگیاں (Fee) — Manager/Sub-admin بھی فیس چیک کر کے منظور/رد کرے
--     (staff = teacher/admin/manager)۔ خود-مکتفی: اگر payments.status
--     کالم موجود نہ ہو تو خودکار بن جاتا ہے۔
-- ------------------------------------------------------------
ALTER TABLE public.payments
  ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'pending';

-- زیرِ التوا ادائیگیوں کی فہرست (staff دیکھے)
DROP FUNCTION IF EXISTS public.get_pending_payments();
CREATE OR REPLACE FUNCTION public.get_pending_payments()
RETURNS TABLE (
  payment_id    UUID,
  student_name  TEXT,
  class_title   TEXT,
  method        TEXT,
  txn_reference TEXT,
  amount        NUMERIC,
  created_at    TIMESTAMPTZ
) AS $$
  SELECT p.id, pr.full_name, c.title, p.method, p.txn_reference, p.amount, p.created_at
  FROM public.payments p
  JOIN public.profiles pr ON pr.id = p.student_id
  JOIN public.classes  c  ON c.id  = p.class_id
  WHERE public.is_staff()
    AND COALESCE(p.status, 'pending') = 'pending'
  ORDER BY p.created_at ASC;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ادائیگی منظور: فیس 'paid' + enrollment فعال (student لاگ اِن/جوائن کر سکے)
CREATE OR REPLACE FUNCTION public.approve_payment(p_payment_id UUID)
RETURNS VOID AS $$
DECLARE
  v_student UUID;
  v_class   UUID;
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;

  SELECT student_id, class_id INTO v_student, v_class
  FROM public.payments WHERE id = p_payment_id;
  IF v_student IS NULL THEN
    RAISE EXCEPTION 'PAYMENT_NOT_FOUND';
  END IF;

  UPDATE public.payments SET status = 'approved' WHERE id = p_payment_id;

  -- فیس ادا شدہ: enrollment 'paid' (نہ ہو تو بنا دیں)، تصدیق بھی یقینی
  INSERT INTO public.enrollments (student_id, class_id, grace_until, payment_status)
  VALUES (v_student, v_class, NOW() + INTERVAL '7 days', 'paid')
  ON CONFLICT (student_id, class_id) DO UPDATE
    SET payment_status = 'paid';

  UPDATE public.profiles SET is_verified = TRUE WHERE id = v_student;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ادائیگی رد
CREATE OR REPLACE FUNCTION public.reject_payment(p_payment_id UUID)
RETURNS VOID AS $$
BEGIN
  IF NOT public.is_staff() THEN
    RAISE EXCEPTION 'NOT_ALLOWED';
  END IF;
  UPDATE public.payments SET status = 'rejected' WHERE id = p_payment_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_pending_payments()        TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_payment(UUID)         TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_payment(UUID)          TO authenticated;

-- ============================================================
-- END
-- اب Manager/Sub-admin بھی: اسٹوڈنٹ verify + فیس (payments) منظور/رد کر سکتا ہے۔
-- رول دینا (set_user_role) صرف teacher/admin کے پاس ہے۔
-- ============================================================
