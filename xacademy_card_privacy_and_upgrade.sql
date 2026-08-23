-- ============================================================
-- XACADEMY: verification_requests privacy fix + card-upgrade support
-- ------------------------------------------------------------
-- 1) SECURITY FIX: verification_requests کی SELECT پالیسی USING(true)
--    تھی — یعنی کوئی بھی (یہاں تک کہ anon key سے، لاگ اِن کے بغیر) ہر
--    اسٹوڈنٹ کا فون نمبر، رسید کی تصویر، کارڈ نمبر اور PIN تک پڑھ سکتا
--    تھا۔ اب صرف خود اسٹوڈنٹ (اپنی درخواست) یا staff (ٹیچر/ایڈمن) پڑھ
--    سکیں گے۔
-- 2) کارڈ اپ گریڈ: اگر اسٹوڈنٹ کے پاس پہلے سے فعال کارڈ ہو اور وہ بہتر
--    tier کیلئے اپلائی کرے، نئے کارڈ کی میعاد پرانے کارڈ کی میعاد ہی
--    رہے گی (نئے 1 سال کی بجائے)۔
--
-- Supabase Dashboard → SQL Editor میں چلائیں۔ Safe + idempotent۔
-- ============================================================

DROP POLICY IF EXISTS "Allow select verification requests" ON public.verification_requests;
CREATE POLICY "Select own or staff" ON public.verification_requests
  FOR SELECT USING (auth.uid() = user_id OR public.is_staff());

ALTER TABLE public.verification_requests
  ADD COLUMN IF NOT EXISTS preserve_expiry_date TIMESTAMPTZ;

-- ============================================================
-- END.
-- ============================================================
