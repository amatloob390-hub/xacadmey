-- ============================================================
-- XACADEMY: Student Admin Verification (xacademy321@gmail.com)
-- ============================================================

-- 1. Ensure is_verified column exists on profiles table (default FALSE for students)
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;

-- Automatically set teachers and admins to is_verified = TRUE
UPDATE public.profiles
SET is_verified = TRUE
WHERE role IN ('teacher', 'admin');

-- 2. Create verification_requests table to track student registration approvals for xacademy321@gmail.com
CREATE TABLE IF NOT EXISTS public.verification_requests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    full_name TEXT,
    admin_email TEXT DEFAULT 'xacademy321@gmail.com',
    status TEXT CHECK (status IN ('pending', 'approved', 'rejected')) DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS for verification_requests
ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow authenticated users to insert verification requests" ON public.verification_requests;
CREATE POLICY "Allow authenticated users to insert verification requests" ON public.verification_requests FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Allow select verification requests" ON public.verification_requests;
CREATE POLICY "Allow select verification requests" ON public.verification_requests FOR SELECT USING (true);

-- 3. RPC Function for Admin (xacademy321@gmail.com) to Approve a Student
CREATE OR REPLACE FUNCTION public.approve_student(p_student_id UUID)
RETURNS VOID AS $$
BEGIN
  -- Mark profile as verified
  UPDATE public.profiles
  SET is_verified = TRUE
  WHERE id = p_student_id;

  -- Update verification request status
  UPDATE public.verification_requests
  SET status = 'approved', updated_at = NOW()
  WHERE user_id = p_student_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. RPC Function for Admin to Approve Student by Email (e.g. approve student talha@gmail.com)
CREATE OR REPLACE FUNCTION public.approve_student_by_email(p_email TEXT)
RETURNS VOID AS $$
BEGIN
  UPDATE public.profiles
  SET is_verified = TRUE
  WHERE LOWER(email) = LOWER(TRIM(p_email));

  UPDATE public.verification_requests
  SET status = 'approved', updated_at = NOW()
  WHERE LOWER(email) = LOWER(TRIM(p_email));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
