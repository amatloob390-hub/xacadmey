-- ============================================================
-- XACADEMY: Membership card issuance — existing card holders can
-- register their card details; new applicants upload a payment slip
-- and get a card auto-issued (by the teacher's approval) valid for
-- 1 year from issue.
-- ------------------------------------------------------------
-- Supabase Dashboard → SQL Editor میں چلائیں۔ Safe + idempotent.
-- Requires xacademy_registration_upgrades.sql to have run first
-- (verification_requests table + membership_card/membership_fee columns).
-- ============================================================

ALTER TABLE public.verification_requests ADD COLUMN IF NOT EXISTS is_existing_card_holder BOOLEAN DEFAULT FALSE;
ALTER TABLE public.verification_requests ADD COLUMN IF NOT EXISTS name_on_card TEXT;
ALTER TABLE public.verification_requests ADD COLUMN IF NOT EXISTS card_number TEXT;
ALTER TABLE public.verification_requests ADD COLUMN IF NOT EXISTS card_issue_date TIMESTAMPTZ;
ALTER TABLE public.verification_requests ADD COLUMN IF NOT EXISTS card_expiry_date TIMESTAMPTZ;
ALTER TABLE public.verification_requests ADD COLUMN IF NOT EXISTS card_pin TEXT;

-- ============================================================
-- END. card_expiry_date پر approved requests کو auth_service.dart کا
-- signIn() چیک کرتا ہے — میعاد ختم ہو تو لاگ اِن بلاک ہو جاتا ہے (ٹرائل
-- ختم ہونے والے چیک جیسا ہی)۔
-- ============================================================
