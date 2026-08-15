// Xacademy — Staff-only: manually reset a student's login password
// Deploy: Supabase Dashboard → Edge Functions → create "reset-student-password" → paste this.
// Secret needed: SUPABASE_SERVICE_ROLE_KEY (Project Settings → Edge Functions → Secrets).
// SUPABASE_URL and SUPABASE_ANON_KEY are already provided automatically to every
// Edge Function — no need to add them manually.
//
// اہم: service role key یہاں (server) پر Deno.env.get سے آتی ہے — کبھی app میں نہیں۔
// یہ key کسی بھی صارف کا پاس ورڈ بدل سکتی ہے، اس لیے ہر request میں کالر کا
// عملہ (teacher/admin/manager) ہونا سرور پر خود تصدیق کیا جاتا ہے — صرف
// کلائنٹ پر بھروسا نہیں کیا جاتا۔

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function fail(error: string, status: number) {
  return new Response(JSON.stringify({ error }), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return fail("AUTH_REQUIRED", 401);

    // 1. کالر کون ہے؟ اُسی کے اپنے token سے تصدیق (anon key client)۔
    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: callerData, error: callerErr } = await callerClient.auth.getUser();
    if (callerErr || !callerData?.user) return fail("AUTH_REQUIRED", 401);

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // 2. کالر واقعی staff ہے؟ (admin client سے — RLS پر بھروسا نہیں)
    const { data: callerProfile } = await admin
      .from("profiles")
      .select("role")
      .eq("id", callerData.user.id)
      .maybeSingle();

    const staffRoles = ["teacher", "admin", "manager"];
    if (!callerProfile || !staffRoles.includes(callerProfile.role)) {
      return fail("NOT_ALLOWED", 403);
    }

    // 3. ان پٹ کی توثیق
    const { student_id, new_password } = await req.json();
    if (!student_id || typeof student_id !== "string") return fail("INVALID_STUDENT", 400);
    if (!new_password || typeof new_password !== "string" || new_password.length < 6) {
      return fail("PASSWORD_TOO_SHORT", 400);
    }

    // 4. ہدف واقعی student ہو — staff اس راستے سے دوسرے staff کا پاس ورڈ نہ بدل سکے۔
    const { data: targetProfile } = await admin
      .from("profiles")
      .select("role")
      .eq("id", student_id)
      .maybeSingle();
    if (!targetProfile || targetProfile.role !== "student") {
      return fail("TARGET_NOT_STUDENT", 400);
    }

    // 5. اصل پاس ورڈ ری سیٹ — Admin API (service role) سے
    const { error: updateErr } = await admin.auth.admin.updateUserById(student_id, {
      password: new_password,
    });
    if (updateErr) return fail(updateErr.message, 500);

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return fail(String(e), 500);
  }
});
