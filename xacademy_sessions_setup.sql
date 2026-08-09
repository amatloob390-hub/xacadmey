-- ============================================================
-- SINGLE-DEVICE LOGIN کے لیے sessions table + RLS + realtime
-- ------------------------------------------------------------
-- app (SessionManager) ہر user کے لیے ایک row رکھتا ہے:
--   user_id -> active_device_id (سب سے حالیہ لاگ اِن ڈیوائس)
-- نئی ڈیوائس لاگ اِن ہو تو یہ row اووَررائٹ ہوتی ہے، اور پرانی
-- ڈیوائس (realtime/polling سے) خود کو logout کر دیتی ہے۔
--
-- اِسے Supabase Dashboard → SQL Editor میں چلائیں۔
-- ============================================================

-- 1) table
CREATE TABLE IF NOT EXISTS public.sessions (
  user_id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  active_device_id TEXT,
  updated_at       TIMESTAMPTZ DEFAULT NOW()
);

-- 2) RLS — ہر user صرف اپنی row دیکھ/لکھ سکے
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "own session select" ON public.sessions;
CREATE POLICY "own session select" ON public.sessions
  FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "own session insert" ON public.sessions;
CREATE POLICY "own session insert" ON public.sessions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "own session update" ON public.sessions;
CREATE POLICY "own session update" ON public.sessions
  FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 3) fallback RPC (اگر سیدھا upsert RLS سے رک جائے تو app یہ کال کرتا ہے)
CREATE OR REPLACE FUNCTION public.register_device(p_device_id TEXT)
RETURNS VOID AS $$
BEGIN
  INSERT INTO public.sessions (user_id, active_device_id, updated_at)
  VALUES (auth.uid(), p_device_id, NOW())
  ON CONFLICT (user_id) DO UPDATE
    SET active_device_id = EXCLUDED.active_device_id,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.register_device(TEXT) TO authenticated;

-- 4) realtime — تاکہ پرانی ڈیوائس فوراً (بغیر 5s انتظار) logout ہو
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'sessions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.sessions;
  END IF;
END $$;
