// backend/supabase/functions/narrate-trend/index.ts
// MBI Phase 1.5 — Trend Narrative Edge Function
// Sprint 2 · Epic 1
// Claude generates window synthesis text from structured inputs only.
// Claude never influences scores, aggregations, driver selections, or signal callouts.
// Prompt Version: 1.0

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY")!;

const MODEL = "claude-sonnet-4-5";
const PROMPT_VERSION = "1.0";
const MAX_TOKENS = 300;

// ─────────────────────────────────────────
// TYPES
// ─────────────────────────────────────────

type WindowType = "7d" | "8w" | "12m";

interface TrendNarrativeInput {
  window_type: WindowType;
  window_start: string;
  window_end: string;
  chronos_avg: number;
  chronos_min: number;
  chronos_max: number;
  trend_direction: "improving" | "stable" | "declining";
  top_drivers: string[];   // top 2 most-flagged metrics across the window
  days_in_window: number;
}

// ─────────────────────────────────────────
// METRIC LABELS — mirrors narrate/index.ts
// ─────────────────────────────────────────

const METRIC_LABELS: Record<string, string> = {
  hrv:               "heart rate variability",
  resting_hr:        "resting heart rate",
  respiratory_rate:  "respiratory rate",
  sleep_duration:    "sleep duration",
  sleep_efficiency:  "sleep quality",
  steps:             "daily steps",
  active_minutes:    "active minutes",
  d1_autonomic:      "autonomic recovery",
  d2_sleep:          "sleep recovery",
  d3_activity:       "activity",
};

// ─────────────────────────────────────────
// WINDOW LABELS
// ─────────────────────────────────────────

const WINDOW_LABELS: Record<WindowType, string> = {
  "7d":  "the past 7 days",
  "8w":  "the past 8 weeks",
  "12m": "the past 12 months",
};

// ─────────────────────────────────────────
// PROMPT BUILDER
// Voice & tone rules match narrate/index.ts.
// Structured data in → narrative copy out.
// Claude does not compute anything from this prompt.
// ─────────────────────────────────────────

function buildPrompt(input: TrendNarrativeInput): string {
  const windowLabel = WINDOW_LABELS[input.window_type];
  const driver1 = METRIC_LABELS[input.top_drivers[0]] ?? input.top_drivers[0] ?? "your primary metric";
  const driver2 = METRIC_LABELS[input.top_drivers[1]] ?? input.top_drivers[1] ?? null;
  const driverPhrase = driver2
    ? `${driver1} and ${driver2}`
    : driver1;

  const directionPhrase = {
    improving: "an improving trend",
    stable:    "a stable pattern",
    declining: "a declining trend",
  }[input.trend_direction];

  return `You are the voice of Mynd & Bodi Institute, a prevention-first health intelligence platform.

Your role is to translate physiological trend data into plain-language wellness context for a time window. You are a trusted, warm, knowledgeable guide — not a clinician.

ABSOLUTE RULES — NEVER VIOLATE:
- Never use clinical language or diagnostic framing
- Never say "autonomic dysfunction", "systemic inflammation", "pathological", "risk factor", or any medical diagnostic term
- Never say "consult a physician" or suggest medical evaluation
- Never induce anxiety, shame, or obsessive self-monitoring
- Always use wellness framing: recovery, resilience, patterns, energy, balance
- Write 3–5 sentences. No more. No less.
- Reference specific metric names from the drivers provided
- Describe the arc of the window — where things started, what the pattern was, what is driving it
- Do not repeat or paraphrase the stat line — it is shown separately below the narrative

WINDOW DATA (deterministic — do not alter these values):
- Window: ${windowLabel}
- Average Chronos score: ${Math.round(input.chronos_avg)}
- Range: ${Math.round(input.chronos_min)} low · ${Math.round(input.chronos_max)} high
- Trend direction: ${directionPhrase}
- Key drivers across this window: ${driverPhrase}
- Days of data in window: ${input.days_in_window}

Write a 3–5 sentence window synthesis. Describe the arc of ${windowLabel}. Reference ${driverPhrase} by name. Keep the tone warm, grounded, and specific. Do not write a list. Write connected prose.

Respond with only the narrative text. No labels. No JSON. No preamble.`;
}

// ─────────────────────────────────────────
// HANDLER
// ─────────────────────────────────────────

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    const _supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    const body = await req.json() as TrendNarrativeInput & { userId: string };
    const { userId, window_type, window_start, window_end,
            chronos_avg, chronos_min, chronos_max,
            trend_direction, top_drivers, days_in_window } = body;

    // ── Validate required fields ─────────────────────────────────────
    if (!userId || !window_type || chronos_avg == null) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: userId, window_type, chronos_avg" }),
        { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders() } }
      );
    }

    const input: TrendNarrativeInput = {
      window_type,
      window_start,
      window_end,
      chronos_avg,
      chronos_min,
      chronos_max,
      trend_direction,
      top_drivers: top_drivers ?? [],
      days_in_window: days_in_window ?? 0,
    };

    const prompt = buildPrompt(input);

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
        max_tokens: MAX_TOKENS,
        system: "You are the Mynd & Bodi Institute wellness voice. Write only warm, plain-language wellness narrative. Never use clinical or diagnostic language. Respond with narrative prose only — no labels, no JSON, no lists.",
        messages: [{ role: "user", content: prompt }],
      }),
    });

    if (!claudeResponse.ok) {
      const err = await claudeResponse.text();
      throw new Error(`Claude API error: ${err}`);
    }

    const claudeData = await claudeResponse.json();
    const narrativeText = (claudeData.content?.[0]?.text ?? "").trim();

    if (!narrativeText) {
      throw new Error("Claude returned empty narrative");
    }

    return new Response(
      JSON.stringify({
        success: true,
        narrative: narrativeText,
        prompt_version: PROMPT_VERSION,
        model_version: MODEL,
      }),
      { headers: { "Content-Type": "application/json", ...corsHeaders() } }
    );

  } catch (err) {
    console.error("[narrate-trend]", err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { "Content-Type": "application/json", ...corsHeaders() } }
    );
  }
});

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type",
  };
}