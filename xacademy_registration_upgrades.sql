-- ============================================================
-- XACADEMY: Registration upgrades — mobile number, fee-slip upload
-- (Paid plan), and membership card tier (Premier plan) collected
-- directly at signup.
-- ------------------------------------------------------------
-- Supabase Dashboard → SQL Editor میں چلائیں۔ Safe + idempotent.
-- ============================================================

-- 1) profiles.phone پہلے سے موجود ہے (xacademy_student_phone.sql سے) —
--    اب student خود بھی signup پر بھر سکتا ہے، صرف teacher نہیں۔
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;

-- 1.5) verification_requests table خود اس project میں کبھی نہیں بنی تھی
--      (اُس کا CREATE TABLE xacademy_admin_verification.sql میں تھا، جو
--      کبھی نہیں چلائی گئی) — یہاں خود بخود بنا دیتے ہیں تاکہ یہ فائل
--      اکیلے بھی چل سکے، چاہے وہ پرانی فائل کبھی چلی ہو یا نہ ہو۔
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

ALTER TABLE public.verification_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow authenticated users to insert verification requests" ON public.verification_requests;
CREATE POLICY "Allow authenticated users to insert verification requests" ON public.verification_requests FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS "Allow select verification requests" ON public.verification_requests;
CREATE POLICY "Allow select verification requests" ON public.verification_requests FOR SELECT USING (true);

-- 2) verification_requests: signup پر جمع ہونے والی اضافی معلومات —
--    فون نمبر، Paid پلان کی فیس سلپ (base64 تصویر)، اور Premier پلان
--    کیلئے منتخب کردہ membership card + اُس کی فیس۔
ALTER TABLE public.verification_requests ADD COLUMN IF NOT EXISTS phone TEXT;
ALTER TABLE public.verification_requests ADD COLUMN IF NOT EXISTS receipt_image TEXT;
ALTER TABLE public.verification_requests ADD COLUMN IF NOT EXISTS membership_card TEXT; -- 'silver' | 'gold' | 'platinum' | 'gold_platinum'
ALTER TABLE public.verification_requests ADD COLUMN IF NOT EXISTS membership_fee NUMERIC;

-- ============================================================
-- END.
-- ============================================================
