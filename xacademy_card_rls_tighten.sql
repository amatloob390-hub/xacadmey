-- ============================================================
-- XACADEMY: verification_requests — INSERT/UPDATE پالیسیاں سخت کریں
-- ------------------------------------------------------------
-- بگ: UPDATE پالیسی USING(true) WITH CHECK(true) تھی — یعنی کوئی بھی
--     لاگ اِن صارف (صرف staff نہیں) کسی بھی row کو براہِ راست API کال
--     سے بدل سکتا تھا: اپنا کارڈ tier خود بڑھا سکتا تھا، اپنی status
--     خود 'approved' کر سکتا تھا، یا کسی اور کا PIN/card بدل سکتا تھا۔
--     اب صرف staff (ٹیچر/ایڈمن) UPDATE کر سکیں گے۔
--
--     INSERT پالیسی WITH CHECK(true) تھی — کوئی بھی (لاگ آؤٹ صارف بھی)
--     کسی اور کے user_id کے ساتھ جعلی درخواست بنا سکتا تھا۔ اب صرف
--     اپنے ہی user_id کیلئے insert کر سکیں گے۔ ایپ کا اپنا کوڈ ہمیشہ
--     auth.currentUser.id ہی بھیجتا ہے، اس لیے یہ موجودہ فیچرز نہیں
--     توڑتا۔
--
-- Supabase Dashboard → SQL Editor میں چلائیں۔ Safe + idempotent۔
-- ============================================================

DROP POLICY IF EXISTS "Allow update verification requests" ON public.verification_requests;
CREATE POLICY "Staff can update verification requests" ON public.verification_requests
  FOR UPDATE USING (public.is_staff()) WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "Allow authenticated users to insert verification requests" ON public.verification_requests;
CREATE POLICY "Insert own verification requests" ON public.verification_requests
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- END.
-- ============================================================
