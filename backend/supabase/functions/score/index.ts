// backend/supabase/functions/score/index.ts
// MBI Phase 1 — Scoring Pipeline Edge Function
// Sprint 4 | Wires ingestion → domain layer → daily_scores
// Sprint 2 update: populates trend_aggregates after each daily score upsert

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    const { data: history } = await supabase
      .from("daily_inputs")
      .select("*")
      .eq("user_id", userId)
      .lt("date", date)
      .order("date", { ascending: true })
      .limit(90);

    const historyRows = history ?? [];
    const historyDays = historyRows.length;

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

    // ── 9. Populate trend_aggregates (non-fatal) ──────────────────────
    try {
      await upsertTrendAggregates(userId, date);
    } catch (aggErr) {
      console.error("[score] trend_aggregates upsert failed (non-fatal):", aggErr);
    }

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

// ─────────────────────────────────────────
// TREND AGGREGATES
// Each helper instantiates its own Supabase client.
// Avoids ReturnType<typeof createClient> generic inference issues in Deno.
// ─────────────────────────────────────────

async function upsertTrendAggregates(userId: string, date: string): Promise<void> {
  await Promise.all([
    upsertWeeklyAggregate(userId, date),
    upsertMonthlyAggregate(userId, date),
  ]);
}

async function upsertWeeklyAggregate(userId: string, date: string): Promise<void> {
  const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  const d = new Date(date);
  const dayOfWeek = d.getUTCDay();
  const daysFromMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
  const weekStart = new Date(d);
  weekStart.setUTCDate(d.getUTCDate() - daysFromMonday);
  const weekEnd = new Date(weekStart);
  weekEnd.setUTCDate(weekStart.getUTCDate() + 6);
  const windowStart = toDateString(weekStart);
  const windowEnd = toDateString(weekEnd);

  const { data: scoreRows } = await sb
    .from("daily_scores")
    .select("date, chronos_score, driver_1, driver_2")
    .eq("user_id", userId)
    .gte("date", windowStart)
    .lte("date", windowEnd)
    .order("date", { ascending: true });

  const { data: inputRows } = await sb
    .from("daily_inputs")
    .select("date, hrv_ms, resting_hr_bpm, respiratory_rate_rpm, sleep_duration_hrs, sleep_efficiency_pct, steps, active_minutes")
    .eq("user_id", userId)
    .gte("date", windowStart)
    .lte("date", windowEnd);

  if (!scoreRows || scoreRows.length === 0) return;

  const aggregate = computeAggregate(scoreRows, inputRows ?? []);
  const trendDirection = await computeTrendDirection(sb, userId, windowStart, "weekly", aggregate.chronos_avg);

  const row: Record<string, unknown> = {
    user_id: userId,
    window_type: "weekly",
    window_start: windowStart,
    window_end: windowEnd,
    trend_direction: trendDirection,
    updated_at: new Date().toISOString(),
    ...aggregate,
  };

  // deno-lint-ignore no-explicit-any
  await (sb as any).from("trend_aggregates").upsert(row, { onConflict: "user_id,window_type,window_start" });
}

async function upsertMonthlyAggregate(userId: string, date: string): Promise<void> {
  const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  const d = new Date(date);
  const windowStart = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-01`;
  const lastDay = new Date(d.getUTCFullYear(), d.getUTCMonth() + 1, 0).getUTCDate();
  const windowEnd = `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, "0")}-${String(lastDay).padStart(2, "0")}`;

  const { data: scoreRows } = await sb
    .from("daily_scores")
    .select("date, chronos_score, driver_1, driver_2")
    .eq("user_id", userId)
    .gte("date", windowStart)
    .lte("date", windowEnd)
    .order("date", { ascending: true });

  const { data: inputRows } = await sb
    .from("daily_inputs")
    .select("date, hrv_ms, resting_hr_bpm, respiratory_rate_rpm, sleep_duration_hrs, sleep_efficiency_pct, steps, active_minutes")
    .eq("user_id", userId)
    .gte("date", windowStart)
    .lte("date", windowEnd);

  if (!scoreRows || scoreRows.length === 0) return;

  const aggregate = computeAggregate(scoreRows, inputRows ?? []);
  const trendDirection = await computeTrendDirection(sb, userId, windowStart, "monthly", aggregate.chronos_avg);

  const row: Record<string, unknown> = {
    user_id: userId,
    window_type: "monthly",
    window_start: windowStart,
    window_end: windowEnd,
    trend_direction: trendDirection,
    updated_at: new Date().toISOString(),
    ...aggregate,
  };

  // deno-lint-ignore no-explicit-any
  await (sb as any).from("trend_aggregates").upsert(row, { onConflict: "user_id,window_type,window_start" });
}

// ─────────────────────────────────────────
// COMPUTE AGGREGATE — pure, no Supabase calls
// ─────────────────────────────────────────

function computeAggregate(
  scoreRows: Array<{ date: string; chronos_score: number; driver_1: string; driver_2: string }>,
  inputRows: Array<Record<string, unknown>>
): Record<string, unknown> {
  const chronosScores = scoreRows.map(r => r.chronos_score).filter(v => v != null);

  const chronos_avg = avg(chronosScores);
  const chronos_min = chronosScores.length > 0 ? Math.min(...chronosScores) : null;
  const chronos_max = chronosScores.length > 0 ? Math.max(...chronosScores) : null;

  const hrv_avg             = avgField(inputRows, "hrv_ms");
  const resting_hr_avg      = avgField(inputRows, "resting_hr_bpm");
  const respiratory_rate_avg = avgField(inputRows, "respiratory_rate_rpm");
  const sleep_duration_avg  = avgField(inputRows, "sleep_duration_hrs");
  const sleep_efficiency_avg = avgField(inputRows, "sleep_efficiency_pct");
  const steps_avg           = avgField(inputRows, "steps");
  const active_minutes_avg  = avgField(inputRows, "active_minutes");

  const driverFreq: Record<string, number> = {};
  for (const row of scoreRows) {
    if (row.driver_1) driverFreq[row.driver_1] = (driverFreq[row.driver_1] ?? 0) + 1;
    if (row.driver_2) driverFreq[row.driver_2] = (driverFreq[row.driver_2] ?? 0) + 1;
  }
  const sortedDrivers = Object.entries(driverFreq).sort((a, b) => b[1] - a[1]);

  return {
    chronos_avg,
    chronos_min,
    chronos_max,
    days_in_window: chronosScores.length,
    hrv_avg,
    resting_hr_avg,
    respiratory_rate_avg,
    sleep_duration_avg,
    sleep_efficiency_avg,
    steps_avg,
    active_minutes_avg,
    top_driver_1: sortedDrivers[0]?.[0] ?? null,
    top_driver_2: sortedDrivers[1]?.[0] ?? null,
  };
}

// ─────────────────────────────────────────
// TREND DIRECTION
// ─────────────────────────────────────────

async function computeTrendDirection(
  // deno-lint-ignore no-explicit-any
  sb: any,
  userId: string,
  currentWindowStart: string,
  windowType: string,
  currentAvg: unknown
): Promise<"improving" | "stable" | "declining"> {
  if (currentAvg == null || typeof currentAvg !== "number") return "stable";

  const { data: prior } = await sb
    .from("trend_aggregates")
    .select("chronos_avg")
    .eq("user_id", userId)
    .eq("window_type", windowType)
    .lt("window_start", currentWindowStart)
    .order("window_start", { ascending: false })
    .limit(1)
    .single();

  const priorAvg = prior?.chronos_avg;
  if (priorAvg == null || typeof priorAvg !== "number") return "stable";

  const diff = currentAvg - priorAvg;
  if (diff > 3)  return "improving";
  if (diff < -3) return "declining";
  return "stable";
}

// ─────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────

function avg(values: number[]): number | null {
  if (values.length === 0) return null;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

function avgField(rows: Array<Record<string, unknown>>, field: string): number | null {
  const vals = rows
    .map(r => r[field])
    .filter((v): v is number => v != null && typeof v === "number");
  return avg(vals);
}

function toDateString(date: Date): string {
  return date.toISOString().split("T")[0];
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, content-type",
  };
}

function daysBetween(dateA: string, dateB: string): number {
  const msPerDay = 86_400_000;
  return Math.abs(new Date(dateB).getTime() - new Date(dateA).getTime()) / msPerDay;
}