-- ============================================================
-- XACADEMY: Fix link-based enrollment ("no class" after signup)
-- ============================================================
-- Root cause:
--   1) enrollments table column drift: some code uses user_id,
--      other code (features_v2) uses student_id. Whichever column
--      is missing → INSERT/SELECT throws → client swallows it →
--      the enrollment is never written/read → student sees "no class".
--   2) get_my_classes() RPC (the client's primary read path) was
--      never created.
--   3) enroll_in_class() blocked classes older than 7 days, so a
--      shared link for an older class silently failed.
--
-- Fix strategy (safe + idempotent — run the whole file once in the
-- Supabase SQL Editor; re-running is harmless):
--   - Ensure enrollments has BOTH student_id and user_id, kept in
--     sync by a trigger, so every existing code path works.
--   - Ensure grace_until / payment_status columns exist.
--   - Add unique indexes so ON CONFLICT (either variant) works.
--   - Create get_my_classes().
--   - Redefine enroll_in_class() without the 7-day hard block.
-- ============================================================

-- Make sure the table exists (no-op if it already does)
CREATE TABLE IF NOT EXISTS public.enrollments (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  class_id   UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ------------------------------------------------------------
-- 1. Ensure all columns both naming conventions need
-- ------------------------------------------------------------
ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS student_id     UUID;
ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS user_id        UUID;
ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS grace_until    TIMESTAMPTZ;
ALTER TABLE public.enrollments ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'pending';

-- Backfill each id column from the other so old rows aren't lost
UPDATE public.enrollments SET student_id = user_id
  WHERE student_id IS NULL AND user_id IS NOT NULL;
UPDATE public.enrollments SET user_id = student_id
  WHERE user_id IS NULL AND student_id IS NOT NULL;

-- ------------------------------------------------------------
-- 2. Keep student_id and user_id in sync on every write
--    (so code that fills only one column still populates both)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enrollments_sync_ids()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.student_id IS NULL THEN NEW.student_id := NEW.user_id; END IF;
  IF NEW.user_id    IS NULL THEN NEW.user_id    := NEW.student_id; END IF;
  IF NEW.grace_until IS NULL THEN NEW.grace_until := NOW() + INTERVAL '7 days'; END IF;
  IF NEW.payment_status IS NULL THEN NEW.payment_status := 'pending'; END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_enrollments_sync_ids ON public.enrollments;
CREATE TRIGGER trg_enrollments_sync_ids
  BEFORE INSERT OR UPDATE ON public.enrollments
  FOR EACH ROW EXECUTE FUNCTION public.enrollments_sync_ids();

-- ------------------------------------------------------------
-- 3. Unique indexes so ON CONFLICT works for BOTH variants
--    (student_id,class_id) used by features_v2 + client
--    (user_id,class_id)    used by 7day_grace
--    Since the trigger keeps them equal, both enforce the same rule.
-- ------------------------------------------------------------
CREATE UNIQUE INDEX IF NOT EXISTS enrollments_student_class_uidx
  ON public.enrollments (student_id, class_id);
CREATE UNIQUE INDEX IF NOT EXISTS enrollments_user_class_uidx
  ON public.enrollments (user_id, class_id);

-- ------------------------------------------------------------
-- 4. get_my_classes(): the client's primary read path (was missing)
--    Returns every class the logged-in student is enrolled in.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_my_classes()
RETURNS TABLE (
  class_id       UUID,
  title          TEXT,
  scheduled_at   TIMESTAMPTZ,
  duration_min   INT,
  is_active      BOOLEAN,
  payment_status TEXT,
  grace_until    TIMESTAMPTZ
) AS $$
  SELECT
    c.id,
    c.title,
    c.scheduled_at,
    c.duration_min,
    c.is_active,
    COALESCE(e.payment_status, 'pending'),
    COALESCE(e.grace_until, NOW() + INTERVAL '7 days')
  FROM public.enrollments e
  JOIN public.classes c ON c.id = e.class_id
  WHERE COALESCE(e.student_id, e.user_id) = auth.uid()
  ORDER BY c.scheduled_at DESC;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

-- ------------------------------------------------------------
-- 5. enroll_in_class(): reliable link enrollment.
--    Writes student_id (trigger mirrors user_id) and sets a fresh
--    7-day grace period. No class-age block, so a teacher's shared
--    link always works, even for older classes. The per-student
--    7-day grace (free trial → pay or auto-block) still applies via
--    grace_until + the app's withinGrace / isBlocked logic.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.enroll_in_class(p_class_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'AUTH_REQUIRED';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.classes WHERE id = p_class_id) THEN
    RAISE EXCEPTION 'CLASS_NOT_FOUND';
  END IF;

  INSERT INTO public.enrollments (student_id, class_id, grace_until, payment_status)
  VALUES (v_user_id, p_class_id, NOW() + INTERVAL '7 days', 'pending')
  ON CONFLICT (student_id, class_id) DO UPDATE
    SET grace_until = GREATEST(public.enrollments.grace_until, NOW() + INTERVAL '7 days');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ------------------------------------------------------------
-- 6. RLS: let a student read/insert their own enrollment rows
--    (harmless if policies already exist — dropped first)
-- ------------------------------------------------------------
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "student reads own enrollments" ON public.enrollments;
CREATE POLICY "student reads own enrollments" ON public.enrollments
  FOR SELECT USING (
    auth.uid() = student_id OR auth.uid() = user_id OR public.is_staff()
  );

DROP POLICY IF EXISTS "student inserts own enrollments" ON public.enrollments;
CREATE POLICY "student inserts own enrollments" ON public.enrollments
  FOR INSERT WITH CHECK (
    auth.uid() = student_id OR auth.uid() = user_id
  );

DROP POLICY IF EXISTS "student updates own enrollments" ON public.enrollments;
CREATE POLICY "student updates own enrollments" ON public.enrollments
  FOR UPDATE USING (
    auth.uid() = student_id OR auth.uid() = user_id OR public.is_staff()
  );

-- ------------------------------------------------------------
-- 7. Grants
-- ------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.get_my_classes()      TO authenticated;
GRANT EXECUTE ON FUNCTION public.enroll_in_class(UUID) TO authenticated;

-- ============================================================
-- END. After running this, a student who registers via a class
-- link (or logs in later) will have their enrollment written and
-- read back correctly, so the class shows up instead of "no class".
-- ============================================================
