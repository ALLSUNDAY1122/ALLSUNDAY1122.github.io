import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const MODEL = "gpt-6-luna";
const MAX_TEXT_LENGTH = 16000;

const responseSchema = {
  type: "object",
  additionalProperties: false,
  properties: {
    tasks: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        properties: {
          title: { type: "string" },
          category: { type: "string", enum: ["submission", "event", "item", "purchase", "response", "other"] },
          raw_date_text: { type: ["string", "null"] },
          due_date: { type: ["string", "null"], description: "YYYY-MM-DD only when the original text explicitly states the year, month and day." },
          source_excerpt: { type: "string" },
          confidence: { type: "string", enum: ["low", "medium", "high"] }
        },
        required: ["title", "category", "raw_date_text", "due_date", "source_excerpt", "confidence"]
      }
    }
  },
  required: ["tasks"]
};

const instructions = `あなたは日本の保育園・幼稚園・学校の配布プリントから、保護者が行動すべき項目だけを抽出するアシスタントです。
ルール:
- 原文に書かれている行動だけを抽出し、推測・補完・創作をしない。
- 提出、行事、持ち物、購入・準備、回答・申込を分類する。同じ文に複数の異なる行動がある場合は、項目を分けて漏れなく抽出する。
- 行動が曖昧なら category=other とし、confidence=low にする。
- 日付表現は原文のまま raw_date_text に入れる。
- due_date は原文に西暦年・月・日がすべて明記されている場合だけ YYYY-MM-DD で返す。年がない、相対日付、曜日だけの場合は必ず null。
- source_excerpt は候補を裏付ける原文の短い抜粋を逐語で返す。見つからない場合は項目を出さない。
- 一般的なお知らせや挨拶はタスクにしない。
- 最大25件。候補がなければ空配列。
- 出力は指定JSONスキーマに厳密に従う。`;

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return Response.json({ error: "method_not_allowed" }, { status: 405 });
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) return Response.json({ error: "unauthorized" }, { status: 401 });

  const apiKey = Deno.env.get("OPENAI_API_KEY");
  if (!apiKey) return Response.json({ error: "ai_not_configured", message: "OPENAI_API_KEY secret is not configured." }, { status: 503 });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !anonKey) return Response.json({ error: "backend_not_configured" }, { status: 500 });

  let body: { household_id?: string; document_id?: string; ocr_text?: string };
  try { body = await req.json(); } catch { return Response.json({ error: "invalid_json" }, { status: 400 }); }
  const { household_id, document_id, ocr_text } = body;
  if (!household_id || !document_id || typeof ocr_text !== "string" || !ocr_text.trim()) {
    return Response.json({ error: "missing_required_fields" }, { status: 400 });
  }
  if (ocr_text.length > MAX_TEXT_LENGTH) return Response.json({ error: "text_too_long", max_characters: MAX_TEXT_LENGTH }, { status: 413 });

  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false }
  });

  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData.user) return Response.json({ error: "unauthorized" }, { status: 401 });

  const { data: document, error: documentError } = await supabase
    .from("documents")
    .select("id, household_id, child_id, ai_status")
    .eq("id", document_id)
    .eq("household_id", household_id)
    .maybeSingle();
  if (documentError || !document) return Response.json({ error: "document_not_found" }, { status: 404 });
  if (document.ai_status === "complete") return Response.json({ error: "already_processed" }, { status: 409 });

  const { data: reservation, error: quotaError } = await supabase.rpc("reserve_ai_request", {
    p_household_id: household_id
  });
  if (quotaError || !reservation) {
    return Response.json({ error: "monthly_ai_limit_reached", monthly_limit: 1000 }, { status: 429 });
  }

  const { data: claimed, error: claimError } = await supabase
    .from("documents")
    .update({ ai_status: "processing", ocr_text })
    .eq("id", document_id)
    .eq("household_id", household_id)
    .in("ai_status", ["pending", "failed"])
    .select("id")
    .maybeSingle();
  if (claimError || !claimed) return Response.json({ error: "document_busy_or_already_processed" }, { status: 409 });

  try {
    const openaiResponse = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: MODEL,
        store: false,
        max_output_tokens: 1400,
        input: [
          { role: "system", content: [{ type: "input_text", text: instructions }] },
          { role: "user", content: [{ type: "input_text", text: ocr_text }] }
        ],
        text: {
          format: {
            type: "json_schema",
            name: "nursery_print_tasks",
            strict: true,
            schema: responseSchema
          }
        }
      })
    });

    const openaiPayload = await openaiResponse.json();
    if (!openaiResponse.ok) throw new Error(`openai_http_${openaiResponse.status}`);

    const outputText = (openaiPayload.output ?? [])
      .flatMap((item: { content?: Array<{ type?: string; text?: string }> }) => item.content ?? [])
      .find((item: { type?: string }) => item.type === "output_text")?.text;
    if (typeof outputText !== "string") throw new Error("missing_structured_output");

    const parsed = JSON.parse(outputText);
    const candidates = Array.isArray(parsed.tasks) ? parsed.tasks.slice(0, 25) : [];
    const allowedCategories = new Set(["submission", "event", "item", "purchase", "response", "other"]);
    const allowedConfidence = new Set(["low", "medium", "high"]);
    const tasks = (await Promise.all(candidates.map(async (item: Record<string, unknown>) => {
      const title = typeof item.title === "string" ? item.title.trim().slice(0, 500) : "";
      const excerpt = typeof item.source_excerpt === "string" ? item.source_excerpt.trim().slice(0, 1200) : "";
      const category = typeof item.category === "string" && allowedCategories.has(item.category) ? item.category : "other";
      const rawDate = typeof item.raw_date_text === "string" ? item.raw_date_text.slice(0, 100) : null;
      const dateCandidate = typeof item.due_date === "string" && /^20\\d{2}-\\d{2}-\\d{2}$/.test(item.due_date) ? item.due_date : null;
      const dateValue = dateCandidate ? new Date(dateCandidate + "T00:00:00.000Z") : null;
      const dueDate = dateValue && !Number.isNaN(dateValue.getTime()) && dateValue.toISOString().slice(0, 10) === dateCandidate ? dateCandidate : null;
      const confidence = typeof item.confidence === "string" && allowedConfidence.has(item.confidence) ? item.confidence : "low";
      if (!title || !excerpt || !ocr_text.includes(excerpt)) return null;
      const stableInput = new TextEncoder().encode(document_id + "|" + category + "|" + title + "|" + excerpt);
      const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", stableInput));
      digest[6] = (digest[6] & 0x0f) | 0x50;
      digest[8] = (digest[8] & 0x3f) | 0x80;
      const hex = Array.from(digest.slice(0, 16)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
      const id = hex.slice(0, 8) + "-" + hex.slice(8, 12) + "-" + hex.slice(12, 16) + "-" + hex.slice(16, 20) + "-" + hex.slice(20);
      return {
        id,
        household_id,
        document_id,
        child_id: document.child_id,
        created_by: userData.user.id,
        title,
        category,
        raw_date_text: rawDate,
        due_date: dueDate,
        source_excerpt: excerpt,
        state: "review",
        ai_confidence: confidence
      };
    }))).filter(Boolean);

    if (tasks.length > 0) {
      const { error: insertError } = await supabase.from("tasks").upsert(tasks, { onConflict: "id" });
      if (insertError) throw new Error("task_upsert_failed");
    }

    const { error: completeError } = await supabase.from("documents").update({ ai_status: "complete" }).eq("id", document_id).eq("household_id", household_id);
    if (completeError) throw new Error("document_finalize_failed");

    const usage = openaiPayload.usage ?? {};
    await supabase.from("ai_extraction_logs").insert({
      household_id,
      document_id,
      user_id: userData.user.id,
      model: MODEL,
      input_tokens: usage.input_tokens ?? null,
      output_tokens: usage.output_tokens ?? null,
      status: "success"
    });

    return Response.json({ ok: true, model: MODEL, tasks_created: tasks.length, tasks: tasks.map((task: Record<string, unknown>) => ({
      title: task.title, category: task.category, raw_date_text: task.raw_date_text,
      due_date: task.due_date, source_excerpt: task.source_excerpt, state: task.state,
      ai_confidence: task.ai_confidence
    })) });
  } catch (error) {
    await supabase.from("documents").update({ ai_status: "failed" }).eq("id", document_id).eq("household_id", household_id);
    await supabase.from("ai_extraction_logs").insert({
      household_id, document_id, user_id: userData.user.id,
      model: MODEL, status: "failed"
    });
    console.error("print extraction failed", error instanceof Error ? error.message : "unknown");
    return Response.json({ error: "extraction_failed", message: "AI解析に失敗しました。原文を確認し、再試行してください。" }, { status: 502 });
  }
});
