-- ============================================================
-- XACADEMY: Fix fee/payment not reaching the teacher (v2 — bulletproof)
-- ============================================================
-- Confirmed root cause: the payments table has NO `amount` column.
-- The student's submit always sends `amount`, so the INSERT fails
-- completely → no payment row is ever created → the teacher panel
-- falls back to a placeholder (amount 0, "JazzCash / EasyPaisa",
-- "درخواست جمع ہو گئی", no receipt).
--
-- This version adds the columns FIRST with zero dependencies, then
-- defines is_staff() itself (so the RLS/RPC can't fail if features_v2
-- was never run), then the policies + RPC. Fully idempotent — run the
-- whole file once in the Supabase SQL Editor.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Columns FIRST (no dependencies — this part cannot fail)
-- ------------------------------------------------------------
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS student_id    UUID;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS class_id      UUID;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS amount        NUMERIC;   -- the missing one
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS method        TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS txn_reference TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS receipt_url   TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS status        TEXT DEFAULT 'pending';
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS created_at    TIMESTAMPTZ DEFAULT NOW();

-- The receipt screenshot / TID can be long — keep them unrestricted
ALTER TABLE public.payments ALTER COLUMN txn_reference TYPE TEXT;
ALTER TABLE public.payments ALTER COLUMN receipt_url   TYPE TEXT;

-- ------------------------------------------------------------
-- 2. Ensure the role helpers exist (self-contained, idempotent)
--    so the policies / RPC below never fail on a missing function.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_role()
RETURNS TEXT AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS BOOLEAN AS $$
  SELECT public.my_role() IN ('teacher', 'admin', 'manager');
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.my_role()  TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_staff() TO authenticated;

-- ------------------------------------------------------------
-- 3. RLS: student manages own payments; staff manages all
-- ------------------------------------------------------------
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Drop EVERY existing payments policy (including older ones from earlier
-- migrations that may still linger and block a new student's insert) so
-- only the clean set defined below remains.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies
           WHERE schemaname = 'public' AND tablename = 'payments'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.payments', r.policyname);
  END LOOP;
END $$;

CREATE POLICY "Allow student insert payment" ON public.payments
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = student_id);

CREATE POLICY "Allow student select own payment" ON public.payments
  FOR SELECT TO authenticated
  USING (auth.uid() = student_id);

CREATE POLICY "Allow student update own payment" ON public.payments
  FOR UPDATE TO authenticated
  USING (auth.uid() = student_id)
  WITH CHECK (auth.uid() = student_id);

-- Student can delete their own NOT-yet-approved payment. This lets the app
-- clear a previous pending attempt before inserting a new one, so a student
-- re-submitting doesn't pile up duplicate rows. Approved payments are safe.
DROP POLICY IF EXISTS "Allow student delete own payment" ON public.payments;
CREATE POLICY "Allow student delete own payment" ON public.payments
  FOR DELETE TO authenticated
  USING (auth.uid() = student_id
         AND COALESCE(status, 'pending') <> 'approved');

CREATE POLICY "Allow staff manage payments" ON public.payments
  FOR ALL TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

-- ------------------------------------------------------------
-- 4. get_pending_payments(): reliable read for staff.
--    LEFT JOINs so a missing profile/class never drops the payment;
--    returns student_id, class_id and receipt_url so the teacher
--    panel shows the real amount, method, TID and receipt screenshot.
-- ------------------------------------------------------------
DROP FUNCTION IF EXISTS public.get_pending_payments();
CREATE OR REPLACE FUNCTION public.get_pending_payments()
RETURNS TABLE (
  payment_id    UUID,
  student_id    UUID,
  class_id      UUID,
  student_name  TEXT,
  class_title   TEXT,
  method        TEXT,
  txn_reference TEXT,
  receipt_url   TEXT,
  amount        NUMERIC,
  created_at    TIMESTAMPTZ
) AS $$
  -- One row per student+class (the latest submission) so duplicate
  -- re-submissions don't show as repeated cards.
  SELECT q.payment_id, q.student_id, q.class_id, q.student_name,
         q.class_title, q.method, q.txn_reference, q.receipt_url,
         q.amount, q.created_at
  FROM (
    SELECT DISTINCT ON (p.student_id, p.class_id)
      p.id            AS payment_id,
      p.student_id,
      p.class_id,
      COALESCE(pr.full_name, 'اسٹوڈنٹ') AS student_name,
      COALESCE(c.title, 'کلاس')          AS class_title,
      p.method,
      p.txn_reference,
      p.receipt_url,
      p.amount,
      p.created_at
    FROM public.payments p
    LEFT JOIN public.profiles pr ON pr.id = p.student_id
    LEFT JOIN public.classes  c  ON c.id  = p.class_id
    WHERE public.is_staff()
      -- treat everything not yet decided as pending: pending / submitted / null
      AND COALESCE(p.status, 'pending') NOT IN ('approved', 'rejected')
    ORDER BY p.student_id, p.class_id, p.created_at DESC
  ) q
  ORDER BY q.created_at ASC;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_pending_payments() TO authenticated;

-- ------------------------------------------------------------
-- 5. Verify: this should now list `amount` among the columns
-- ------------------------------------------------------------
-- SELECT column_name FROM information_schema.columns
-- WHERE table_schema='public' AND table_name='payments' ORDER BY 1;

-- ============================================================
-- END. After running this, submit a NEW fee from the student side
-- (old failed attempts never created a row) — it will now appear in
-- the teacher panel with the real amount, method, TID and receipt.
-- ============================================================
