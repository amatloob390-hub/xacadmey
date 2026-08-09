-- ============================================================
-- SITE SETTINGS: teacher سے سیٹ ہونے والے social media links
-- landing page عوامی طور پر پڑھتی ہے؛ صرف staff اپڈیٹ کر سکتا ہے۔
-- Supabase Dashboard → SQL Editor میں چلائیں۔
-- ============================================================

CREATE TABLE IF NOT EXISTS public.site_settings (
  id         INT PRIMARY KEY DEFAULT 1,
  facebook   TEXT,
  instagram  TEXT,
  youtube    TEXT,
  tiktok     TEXT,
  whatsapp   TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT site_settings_single_row CHECK (id = 1)
);

-- ہمیشہ ایک ہی row رہے
INSERT INTO public.site_settings (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;

-- عوامی پڑھائی (landing page)
DROP POLICY IF EXISTS "public read site settings" ON public.site_settings;
CREATE POLICY "public read site settings" ON public.site_settings
  FOR SELECT USING (true);

-- صرف staff اپڈیٹ کر سکے
DROP POLICY IF EXISTS "staff update site settings" ON public.site_settings;
CREATE POLICY "staff update site settings" ON public.site_settings
  FOR UPDATE USING (public.is_staff()) WITH CHECK (public.is_staff());
