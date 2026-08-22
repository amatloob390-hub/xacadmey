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
