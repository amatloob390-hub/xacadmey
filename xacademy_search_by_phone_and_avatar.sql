-- ============================================================
-- XACADEMY: Search Students by phone too + profile picture support
-- ------------------------------------------------------------
-- Supabase Dashboard → SQL Editor میں چلائیں۔ Safe + idempotent۔
-- ============================================================

-- 1) search_students RPC اب فون نمبر سے بھی میچ کرے (پہلے صرف نام/ای میل)۔
CREATE OR REPLACE FUNCTION public.search_students(p_query TEXT)
RETURNS TABLE (
  id UUID,
  full_name TEXT,
  email TEXT,
  phone TEXT,
  role TEXT,
  is_verified BOOLEAN,
  is_trial BOOLEAN,
  trial_until TIMESTAMPTZ
) AS $$
  SELECT
    p.id,
    p.full_name,
    COALESCE(NULLIF(TRIM(p.email), ''), u.email) AS email,
    p.phone,
    p.role,
    p.is_verified,
    p.is_trial,
    p.trial_until
  FROM public.profiles p
  JOIN auth.users u ON u.id = p.id
  WHERE public.is_staff()
    AND p.role = 'student'
    AND (
      p.full_name ILIKE '%' || p_query || '%'
      OR COALESCE(NULLIF(TRIM(p.email), ''), u.email) ILIKE '%' || p_query || '%'
      OR p.phone ILIKE '%' || p_query || '%'
    )
  ORDER BY p.full_name
  LIMIT 25;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.search_students(TEXT) TO authenticated;

-- 2) پروفائل تصویر — طالبِ علم اور اسٹاف دونوں اپنی تصویر اپلوڈ کر سکیں
--    (base64، اسی طرح جیسے فیس سلپ کی رسید محفوظ ہوتی ہے)۔
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS avatar_base64 TEXT;

-- ============================================================
-- END.
-- ============================================================
