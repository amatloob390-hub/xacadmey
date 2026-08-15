-- ============================================================
-- XACADEMY: Fix fee/payment not reaching the teacher
-- ============================================================
-- Symptom: a student submits a fee (amount, method, TID, receipt
-- screenshot) but the teacher's "Verify Payments" panel shows a
-- placeholder — amount 0, method "JazzCash / EasyPaisa", reference
-- "درخواست جمع ہو گئی", and no receipt. That placeholder is the app's
-- LAST-resort fallback (pending enrollment), which only appears when
-- the real payment row can't be read.
--
-- Root causes handled here:
--   1) payments table may be missing columns the insert needs
--      (method / txn_reference / amount / status / receipt_url) — a
--      partial schema makes the student's insert silently fail, so no
--      row is ever created.
--   2) RLS may not let staff read students' payments.
--   3) get_pending_payments() used INNER JOINs (a missing profile or
--      class row dropped the payment) and never returned receipt_url
--      or the ids the app needs.
--
-- Safe + idempotent — run the whole file once in the Supabase SQL
-- Editor. Re-running is harmless.
-- ============================================================

-- ------------------------------------------------------------
-- 1. Make sure the payments table has every column the app writes
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payments (
  id         UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  student_id UUID,
  class_id   UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS student_id    UUID;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS class_id      UUID;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS amount        NUMERIC;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS method        TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS txn_reference TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS receipt_url   TEXT;
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS status        TEXT DEFAULT 'pending';
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS created_at    TIMESTAMPTZ DEFAULT NOW();

-- The receipt screenshot / TID can be long — keep them unrestricted
ALTER TABLE public.payments ALTER COLUMN txn_reference TYPE TEXT;
ALTER TABLE public.payments ALTER COLUMN receipt_url   TYPE TEXT;

-- ------------------------------------------------------------
-- 2. RLS: student manages own payments; staff manages all
-- ------------------------------------------------------------
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow student insert payment"      ON public.payments;
DROP POLICY IF EXISTS "Allow student select own payment"  ON public.payments;
DROP POLICY IF EXISTS "Allow student update own payment"  ON public.payments;
DROP POLICY IF EXISTS "Allow staff manage payments"       ON public.payments;

-- Student can insert their own payment
CREATE POLICY "Allow student insert payment" ON public.payments
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = student_id);

-- Student can read their own payments
CREATE POLICY "Allow student select own payment" ON public.payments
  FOR SELECT TO authenticated
  USING (auth.uid() = student_id);

-- Student can update/replace their own not-yet-approved payment
CREATE POLICY "Allow student update own payment" ON public.payments
  FOR UPDATE TO authenticated
  USING (auth.uid() = student_id)
  WITH CHECK (auth.uid() = student_id);

-- Staff (teacher / admin / manager) can do anything on all payments
CREATE POLICY "Allow staff manage payments" ON public.payments
  FOR ALL TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());

-- ------------------------------------------------------------
-- 3. get_pending_payments(): reliable read for staff.
--    LEFT JOINs so a missing profile/class never drops the payment,
--    and returns student_id, class_id and receipt_url so the teacher
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
  SELECT
    p.id,
    p.student_id,
    p.class_id,
    COALESCE(pr.full_name, 'اسٹوڈنٹ'),
    COALESCE(c.title, 'کلاس'),
    p.method,
    p.txn_reference,
    p.receipt_url,
    p.amount,
    p.created_at
  FROM public.payments p
  LEFT JOIN public.profiles pr ON pr.id = p.student_id
  LEFT JOIN public.classes  c  ON c.id  = p.class_id
  WHERE public.is_staff()
    AND COALESCE(p.status, 'pending') = 'pending'
  ORDER BY p.created_at ASC;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_pending_payments() TO authenticated;

-- ============================================================
-- END. After running this, a student's submitted fee (amount,
-- method, TID and receipt screenshot) shows correctly in the
-- teacher's payment-verification panel.
-- ============================================================
