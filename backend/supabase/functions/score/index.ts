// backend/supabase/functions/score/index.ts
// MBI Phase 1 — Scoring Pipeline Edge Function
// Sprint 4 | Wires ingestion → domain layer → daily_scores

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Import domain package (path will be resolved via import map in production)
// For Supabase Edge Functions, these are bundled at deploy time
import { computeBaseline, scoreDay, DOMAIN_VERSION } from "../../functions/_shared/domain/index.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders() });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    const { userId, date } = await req.json();

    if (!userId || !date) {
      return new Response(JSON.stringify({ error: "userId and date required" }), {
        status: 400, headers: { "Content-Type": "application/json", ...corsHeaders() },
      });
    }

    // ── 1. Fetch today's canonical input ──────────────────────────────
    const { data: input, error: inputErr } = await supabase
      .from("daily_inputs")
      .select("*")
      .eq("user_id", userId)
      .eq("date", date)
      .single();

    if (inputErr || !input) {
      return new Response(JSON.stringify({ error: "No input found for this date" }), {
        status: 404, headers: { "Content-Type": "application/json", ...corsHeaders() },
      });
    }

    // ── 2. Fetch up to 90 days of history ────────────────────────────
    // historyDays drives D4 (≥7) and D5 (≥30) eligibility in scoring.ts.
    // computeBaseline uses only the most recent 7 rows for rolling average.
    const { data: history } = await supabase
      .from("daily_inputs")
      .select("*")
      .eq("user_id", userId)
      .lt("date", date)
      .order("date", { ascending: true })
      .limit(90);

    const historyRows = history ?? [];
    const historyDays = historyRows.length;

    // Baseline computed from most recent 7 days only (rolling window)
    const baselineRows = historyRows.slice(-7);
    const baseline = computeBaseline(baselineRows);

    // ── 3. Fetch user step goal ───────────────────────────────────────
    const { data: user } = await supabase
      .from("users")
      .select("step_goal")
      .eq("id", userId)
      .single();

    const stepGoal = user?.step_goal ?? 8000;

    // ── 4. Fetch recent scores for delta override & fail state ────────
    const { data: recentScoreRows } = await supabase
      .from("daily_scores")
      .select("chronos_score, date")
      .eq("user_id", userId)
      .lt("date", date)
      .order("date", { ascending: false })
      .limit(5);

    const recentScores = (recentScoreRows ?? [])
      .map((r: { chronos_score: number }) => r.chronos_score)
      .filter((s: number) => s != null)
      .reverse();

    // ── 5. Compute last engagement gap ───────────────────────────────
    // Approximated: days since last score
    const engagementDays = recentScoreRows && recentScoreRows.length > 0
      ? daysBetween(recentScoreRows[0].date ?? date, date)
      : 0;

    // ── 6. Run scoring engine ─────────────────────────────────────────
    const result = scoreDay({
      input: {
        userId,
        date,
        hrv_ms: input.hrv_ms,
        resting_hr_bpm: input.resting_hr_bpm,
        respiratory_rate_rpm: input.respiratory_rate_rpm,
        sleep_duration_hrs: input.sleep_duration_hrs,
        sleep_efficiency_pct: input.sleep_efficiency_pct,
        steps: input.steps,
        active_minutes: input.active_minutes,
        distance_km: input.distance_km,
        // H-01: Tier 1 metrics
        spo2_pct: input.spo2_pct,
        resting_energy: input.resting_energy,
        stand_hours: input.stand_hours,
      },
      baseline,
      historyDays,
      recentScores,
      stepGoal,
      engagementDays,
    });

    // ── 7. Upsert baseline snapshot ───────────────────────────────────
    if (baseline) {
      await supabase.from("baselines").upsert({
        user_id: userId,
        computed_on: date,
        ...baseline,
        domain_version: DOMAIN_VERSION,
      }, { onConflict: "user_id,computed_on" });
    }

    // ── 8. Upsert score row ───────────────────────────────────────────
    const scoreRow = {
      user_id: userId,
      date,
      chronos_score: result.chronos_score,
      score_band: result.score_band,
      health_score: result.health_score,
      risk_score: result.risk_score,
      alpha: result.alpha,
      d1_autonomic: result.domain_scores.d1_autonomic,
      d2_sleep: result.domain_scores.d2_sleep,
      d3_activity: result.domain_scores.d3_activity,
      d4_stress: result.domain_scores.d4_stress,
      d5_allostatic: result.domain_scores.d5_allostatic,
      driver_1: result.driver_1,
      driver_2: result.driver_2,
      delta_override_triggered: result.delta_override_triggered,
      fail_state: result.fail_state,
      is_provisional: result.is_provisional,
      domain_version: result.domain_version,
    };

    const { data: savedScore, error: scoreErr } = await supabase
      .from("daily_scores")
      .upsert(scoreRow, { onConflict: "user_id,date" })
      .select()
      .single();

    if (scoreErr) throw scoreErr;

    return new Response(JSON.stringify({ success: true, score: savedScore, result }), {
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });

  } catch (err) {
    console.error("[score]", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  }
});

function corsHeaders() {
  return { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, content-type" };
}

function daysBetween(dateA: string, dateB: string): number {
  const msPerDay = 86_400_000;
  return Math.abs(new Date(dateB).getTime() - new Date(dateA).getTime()) / msPerDay;
}
