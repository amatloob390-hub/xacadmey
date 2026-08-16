-- ============================================================
-- FREE CLASSES: ٹیچر ہر کلاس کو Free یا Paid کے طور پر مارک کر سکے
-- ------------------------------------------------------------
-- Supabase Dashboard → SQL Editor میں چلائیں۔
-- ============================================================

ALTER TABLE public.classes ADD COLUMN IF NOT EXISTS is_free BOOLEAN DEFAULT FALSE;
