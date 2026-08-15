-- ============================================================
-- XACADEMY: Fix Search Students — profiles.email is unreliable
-- ============================================================
-- Root cause (confirmed via direct SQL): profiles.email is NULL for
-- many students (Ali included) — the real email only lives in
-- auth.users.email. The client-side search queried profiles.email
-- directly and found nothing, exactly the same root cause already
-- fixed for attendance emails via get_students_emails().
--
-- Fix: a SECURITY DEFINER RPC that matches full_name OR the resolved
-- email (COALESCE(profiles.email, auth.users.email)) — staff only.
--
-- Safe + idempotent — run once in the Supabase SQL Editor.
-- ============================================================

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
    )
  ORDER BY p.full_name
  LIMIT 25;
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.search_students(TEXT) TO authenticated;

-- One-time backfill: fill any still-empty profiles.email from the real
-- auth.users email, so future direct-table lookups elsewhere are also
-- more likely to work.
UPDATE public.profiles p
  SET email = u.email
  FROM auth.users u
  WHERE u.id = p.id AND (p.email IS NULL OR TRIM(p.email) = '');

-- ============================================================
-- END. Search now resolves the real email regardless of whether
-- profiles.email was ever populated.
-- ============================================================
