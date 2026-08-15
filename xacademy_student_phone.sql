-- ============================================================
-- XACADEMY: Add phone/mobile number field to student profiles
-- ============================================================
-- Needed for the new "Search Students" feature — teacher/admin can
-- view AND manually enter/edit a student's mobile number (students
-- never enter it themselves at signup, so it starts empty).
--
-- Safe + idempotent — run once in the Supabase SQL Editor.
-- ============================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;

-- ============================================================
-- END. profiles.phone now exists (NULL for existing students until
-- a teacher/admin fills it in from the Search Students screen).
-- ============================================================
