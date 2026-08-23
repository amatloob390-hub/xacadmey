-- ============================================================
-- XACADEMY: Fix — verification_requests پر UPDATE پالیسی غائب تھی
-- ------------------------------------------------------------
-- بگ: Approve/Reject بٹن "کامیابی" کا پیغام دکھاتا تھا، لیکن چونکہ RLS
-- فعال تھی اور صرف INSERT/SELECT پالیسیاں موجود تھیں (کوئی UPDATE
-- پالیسی نہیں)، اصل status کالم کبھی 'approved'/'rejected' میں بدلتا
-- ہی نہیں تھا — اسی لیے منظور شدہ درخواست دوبارہ لوڈ کرنے پر پھر
-- pending کے طور پر نظر آتی رہتی تھی۔
--
-- Supabase Dashboard → SQL Editor میں چلائیں۔ Safe + idempotent۔
-- ============================================================

DROP POLICY IF EXISTS "Allow update verification requests" ON public.verification_requests;
CREATE POLICY "Allow update verification requests" ON public.verification_requests
  FOR UPDATE USING (true) WITH CHECK (true);

-- ============================================================
-- END.
-- ============================================================
