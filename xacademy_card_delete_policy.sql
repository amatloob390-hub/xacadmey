-- ============================================================
-- XACADEMY: Fix — verification_requests پر DELETE پالیسی غائب تھی
-- ------------------------------------------------------------
-- بگ: ٹیچر "Delete" دبانے پر "Card Deleted" کا کامیابی پیغام دیکھتا
-- تھا، لیکن چونکہ RLS فعال تھی اور کوئی DELETE پالیسی موجود نہیں تھی،
-- اصل row کبھی حذف نہیں ہوتا تھا — فہرست دوبارہ لوڈ ہونے پر وہی کارڈ
-- پھر نظر آتا رہتا۔ صرف staff (ٹیچر/ایڈمن) کو حذف کرنے کی اجازت۔
--
-- Supabase Dashboard → SQL Editor میں چلائیں۔ Safe + idempotent۔
-- ============================================================

DROP POLICY IF EXISTS "Staff can delete verification requests" ON public.verification_requests;
CREATE POLICY "Staff can delete verification requests" ON public.verification_requests
  FOR DELETE USING (public.is_staff());

-- ============================================================
-- END.
-- ============================================================
