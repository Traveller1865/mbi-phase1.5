// backend/supabase/functions/narrate/index.ts
// MBI Phase 1 — Narrative Layer Edge Function
// Sprint 5 | Claude explains. Claude does not decide.
// Prompt Version: 1.0

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;

const MODEL = "claude-sonnet-4-20250514";
const PROMPT_VERSION = "1.0";

// ─────────────────────────────────────────
// METRIC DISPLAY NAMES
// ─────────────────────────────────────────
const METRIC_LABELS: Record<string, string> = {
  hrv: "heart rate variability",
  resting_hr: "resting heart rate",
  respiratory_rate: "respiratory rate",
  sleep_duration: "sleep duration",
  sleep_efficiency: "sleep quality",
  steps: "daily steps",
  active_minutes: "active minutes",
  distance: "activity distance",
};

const DOMAIN_LABELS: Record<string, string> = {
  d1_autonomic: "autonomic recovery",
  d2_sleep: "sleep recovery",
  d3_activity: "activity",
};

// ─────────────────────────────────────────
// PROMPT BUILDER
// Voice & tone rules enforced here (SoT §5.3, PRD §5.3)
// ─────────────────────────────────────────
function buildPrompt(input: {
  chronos_score: number;
  score_band: string;
  driver_1: string;
  driver_2: string;
  delta_override_triggered: boolean;
  fail_state: string | null;
  domain_scores: Record<string, number | null>;
  is_provisional: boolean;
  nudge_domain: string;
}): string {
  const driver1Label = METRIC_LABELS[input.driver_1] ?? input.driver_1;
  const driver2Label = METRIC_LABELS[input.driver_2] ?? input.driver_2;
  const nudgeLabel = DOMAIN_LABELS[input.nudge_domain] ?? input.nudge_domain;

  const bandContext = {
    Thriving: "The user is in strong recovery. Maintain momentum.",
    Recovering: "The user is in a mild stress load but within adaptive range.",
    Drifting: "Risk is accumulating. The user needs attention before it compounds.",
    Redline: "Acute physiological stress. Calm and supportive tone. Not alarming.",
  }[input.score_band] ?? "";

  const deltaContext = input.delta_override_triggered
    ? "IMPORTANT: The score has dropped more than 15 points over the last 3 days. Even if the current band is Recovering or Drifting, write as if the user is trending down quickly. Acknowledge the trajectory, not just today's state."
    : "";

  const provisionalNote = input.is_provisional
    ? "NOTE: This score is provisional — the user is still building their baseline. Mention gently that the score will become more personalized over the next few days."
    : "";

  return `You are the voice of Mynd & Bodi Institute, a prevention-first health intelligence platform.

Your role is to translate physiological data into plain-language wellness context. You are a trusted, warm, knowledgeable guide — not a clinician.

ABSOLUTE RULES — NEVER VIOLATE:
- Never use clinical language or diagnostic framing
- Never say "autonomic dysfunction", "systemic inflammation", "pathological", "risk factor", or any medical diagnostic term
- Never say "consult a physician" or suggest medical evaluation
- Never induce anxiety, shame, or obsessive self-monitoring
- Always use wellness framing: recovery, resilience, patterns, energy, balance
- One nudge only. Never a list. One single action sentence.

TODAY'S DATA (deterministic — do not change these values):
- Chronos Score: ${input.chronos_score}/100
- Band: ${input.score_band}
- Primary drivers: ${driver1Label} and ${driver2Label}
- Nudge target domain: ${nudgeLabel}

BAND CONTEXT: ${bandContext}
${deltaContext}
${provisionalNote}

Generate exactly two outputs:

EXPLANATION: 2–4 sentences. Reference both drivers by name (use the plain-language names above). Explain what the body is experiencing in wellness terms. If delta override is triggered, lead with the trend, not just today's state. Keep it warm, grounded, and specific to these two drivers.

NUDGE: Exactly 1 sentence. A single, concrete, achievable action targeting ${nudgeLabel}. Never a list. Never more than one action.

Respond in this exact JSON format:
{
  "explanation": "...",
  "nudge": "..."
}`;
}

// ─────────────────────────────────────────
// HANDLER
// ─────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    const { userId, date } = await req.json();

    // ── Fetch the score for this day ──────────────────────────────────
    const { data: score, error: scoreErr } = await supabase
      .from("daily_scores")
      .select("*")
      .eq("user_id", userId)
      .eq("date", date)
      .single();

    if (scoreErr || !score) {
      return new Response(JSON.stringify({ error: "Score not found — run /score first" }), {
        status: 404, headers: { "Content-Type": "application/json", ...corsHeaders() },
      });
    }

    // ── Determine nudge domain (lowest active D1/D2/D3) ──────────────
    const candidates: Array<[string, number | null]> = [
      ["d1_autonomic", score.d1_autonomic],
      ["d2_sleep", score.d2_sleep],
      ["d3_activity", score.d3_activity],
    ];
    const available = candidates.filter(([, v]) => v != null) as Array<[string, number]>;
    available.sort((a, b) => a[1] - b[1]);
    const nudge_domain = available.length > 0 ? available[0][0] : "d1_autonomic";

    const narrativeInput = {
      chronos_score: score.chronos_score,
      score_band: score.score_band,
      driver_1: score.driver_1,
      driver_2: score.driver_2,
      delta_override_triggered: score.delta_override_triggered,
      fail_state: score.fail_state,
      domain_scores: {
        d1_autonomic: score.d1_autonomic,
        d2_sleep: score.d2_sleep,
        d3_activity: score.d3_activity,
      },
      is_provisional: score.is_provisional,
      nudge_domain,
    };

    const prompt = buildPrompt(narrativeInput);

    // ── Call Claude API ───────────────────────────────────────────────
    const claudeResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 512,
        messages: [{ role: "user", content: prompt }],
      }),
    });

    if (!claudeResponse.ok) {
      const err = await claudeResponse.text();
      throw new Error(`Claude API error: ${err}`);
    }

    const claudeData = await claudeResponse.json();
    const rawText = claudeData.content?.[0]?.text ?? "";

    // Parse JSON from Claude response
    let parsed: { explanation: string; nudge: string };
    try {
      const jsonMatch = rawText.match(/\{[\s\S]*\}/);
      parsed = JSON.parse(jsonMatch?.[0] ?? rawText);
    } catch {
      // Fallback: extract manually
      parsed = {
        explanation: "Your body is showing some changes today worth paying attention to.",
        nudge: "Take a moment to rest and recover today.",
      };
    }

    // ── Upsert explanation ────────────────────────────────────────────
    const { data: saved, error: saveErr } = await supabase
      .from("explanations")
      .upsert({
        score_id: score.id,
        user_id: userId,
        date,
        explanation_text: parsed.explanation,
        nudge_text: parsed.nudge,
        prompt_version: PROMPT_VERSION,
        model_version: MODEL,
      }, { onConflict: "score_id" })
      .select()
      .single();

    if (saveErr) throw saveErr;

    return new Response(JSON.stringify({ success: true, narrative: saved }), {
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });

  } catch (err) {
    console.error("[narrate]", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }
});

function corsHeaders() {
  return { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, content-type" };
}
