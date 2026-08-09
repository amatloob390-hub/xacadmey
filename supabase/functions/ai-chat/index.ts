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
    const { message } = await req.json();
    if (!message || typeof message !== "string") {
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
          { role: "user", content: message },
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
