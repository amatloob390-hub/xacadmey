-- ============================================================
-- FIX: Payments table RLS & Data Type limits
-- ------------------------------------------------------------
-- Run this script in the Supabase Dashboard -> SQL Editor.
-- ============================================================

-- 1. Ensure receipt_url column exists in the payments table
ALTER TABLE public.payments ADD COLUMN IF NOT EXISTS receipt_url TEXT;

-- 2. Alter column types to TEXT to prevent length restrictions (e.g. value too long for varchar)
ALTER TABLE public.payments ALTER COLUMN txn_reference TYPE TEXT;
ALTER TABLE public.payments ALTER COLUMN receipt_url TYPE TEXT;

-- 3. Enable Row Level Security (RLS) on payments table
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- 4. Drop old conflicting policies if any
DROP POLICY IF EXISTS "Allow student insert payment" ON public.payments;
DROP POLICY IF EXISTS "Allow student select own payment" ON public.payments;
DROP POLICY IF EXISTS "Allow staff manage payments" ON public.payments;
DROP POLICY IF EXISTS "Allow student insert own payment" ON public.payments;
DROP POLICY IF EXISTS "Allow student select own payments" ON public.payments;
DROP POLICY IF EXISTS "Allow staff view all payments" ON public.payments;

-- 5. Create clean RLS policies for payments table

-- Policy A: Allow authenticated student users to insert their own payments
CREATE POLICY "Allow student insert payment" ON public.payments
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = student_id);

-- Policy B: Allow authenticated student users to view their own payments
CREATE POLICY "Allow student select own payment" ON public.payments
  FOR SELECT TO authenticated
  USING (auth.uid() = student_id);

-- Policy C: Allow staff (teacher/admin/manager) to perform any action (Select, Insert, Update, Delete) on all payments
CREATE POLICY "Allow staff manage payments" ON public.payments
  FOR ALL TO authenticated
  USING (public.is_staff())
  WITH CHECK (public.is_staff());
