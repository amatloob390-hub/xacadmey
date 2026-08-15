-- ============================================================
-- XACADEMY: Show student email in the attendance report
-- ============================================================
-- Why: several students can share the same name, so the teacher
-- needs the email next to the name. The app already renders the
-- email when it has one, but its fallback reads the profiles table
-- directly — which RLS blocks for a teacher looking at OTHER
-- students — so the email came back empty.
--
-- Fix: a SECURITY DEFINER helper that resolves emails reliably
-- (bypasses RLS) and only returns data to staff. It coalesces the
-- profiles email with the real auth.users email so it always works,
-- even if profiles.email was never backfilled.
--
-- Run once in the Supabase SQL Editor (idempotent).
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_students_emails(p_ids UUID[])
RETURNS TABLE (id UUID, email TEXT) AS $$
  SELECT u.id,
         COALESCE(NULLIF(TRIM(p.email), ''), u.email) AS email
  FROM unnest(p_ids) AS x(id)
  JOIN auth.users u        ON u.id = x.id
  LEFT JOIN public.profiles p ON p.id = u.id
  WHERE public.is_staff();   -- only teacher / admin / manager may resolve emails
$$ LANGUAGE sql STABLE SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_students_emails(UUID[]) TO authenticated;

-- ============================================================
-- END. After running this, the attendance list shows each
-- student's email under their name.
-- ============================================================
