// Xacademy — AI support agent (Groq via OpenAI-compatible API)
// Deploy: Supabase Dashboard → Edge Functions → create "ai-chat" → paste this.
// Secret: Project Settings → Edge Functions → add GROQ_API_KEY = <your new key>
//
// اہم: API key یہاں (server) پر Deno.env.get سے آتی ہے — کبھی app میں نہیں۔

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY")!;

const SYSTEM_PROMPT =
  "You are a helpful, professional AI support agent for X Academy, a premier " +
  "freelancing education platform. Assist students and beginners in learning " +
  "freelance skills: writing winning proposals, building strong portfolios, " +
  "communicating with clients, and pricing strategies. Keep an encouraging, " +
  "educational tone. Answer in the user's language (Urdu or English). If asked " +
  "about topics outside freelancing, skills, or X Academy courses, politely " +
  "decline and steer back to freelancing education.";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const body = await req.json();

    // نئی شکل: پوری گفتگو (messages array)؛ پرانی شکل: صرف ایک message.
    // دونوں support ہیں تاکہ پرانی app بھی چلتی رہے۔
    let history: Array<{ role: string; content: string }> = [];
    if (Array.isArray(body?.messages)) {
      history = body.messages
        .filter(
          (m: unknown): m is { role: string; content: string } =>
            !!m &&
            typeof (m as { content?: unknown }).content === "string" &&
            (m as { content: string }).content.trim().length > 0 &&
            ((m as { role?: unknown }).role === "user" ||
              (m as { role?: unknown }).role === "assistant"),
        )
        .map((m: { role: string; content: string }) => ({
          role: m.role,
          content: m.content,
        }))
        // ٹوکن دھماکہ روکنے کیلئے آخری 20 پیغامات رکھیں۔
        .slice(-20);
    } else if (typeof body?.message === "string" && body.message.trim()) {
      history = [{ role: "user", content: body.message }];
    }

    if (history.length === 0 || history[history.length - 1].role !== "user") {
      return new Response(JSON.stringify({ error: "message required" }), {
        status: 400,
        headers: { ...cors, "Content-Type": "application/json" },
      });
    }

    const r = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "llama-3.1-8b-instant",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          ...history,
        ],
        temperature: 0.6,
      }),
    });

    const data = await r.json();
    const reply = data?.choices?.[0]?.message?.content ?? "";
    return new Response(JSON.stringify({ reply }), {
      headers: { ...cors, "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...cors, "Content-Type": "application/json" },
    });
  }
});
