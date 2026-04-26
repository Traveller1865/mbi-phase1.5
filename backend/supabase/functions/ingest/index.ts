// backend/supabase/functions/ingest/index.ts
// MBI Phase 1 — Ingestion & Canonicalization Layer
// Version: 1.1 | H-01: Tier 1 metric expansion

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SOURCE_VERSION = "1.1";

interface RawHealthKitPayload {
  userId: string;
  date: string;
  metrics: {
    hrv_ms?: number | null;
    resting_hr_bpm?: number | null;
    respiratory_rate_rpm?: number | null;
    sleep_duration_hrs?: number | null;
    sleep_efficiency_pct?: number | null;
    steps?: number | null;
    active_minutes?: number | null;
    distance_km?: number | null;
    // H-01: Tier 1 expansion
    spo2_pct?: number | null;
    resting_energy?: number | null;
    stand_hours?: number | null;
  };
}

interface DataQualityFlags {
  missing_metrics: string[];
  out_of_range: Record<string, string>;
  is_complete: boolean;
}

function canonicalize(raw: RawHealthKitPayload): {
  row: Record<string, unknown>;
  flags: DataQualityFlags;
} {
  const flags: DataQualityFlags = { missing_metrics: [], out_of_range: {}, is_complete: false };
  const clean: Record<string, number | null> = {};

  // ── Existing metrics ──────────────────────────────────────────
  if (raw.metrics.hrv_ms == null) { flags.missing_metrics.push("hrv_ms"); clean.hrv_ms = null; }
  else if (raw.metrics.hrv_ms < 0 || raw.metrics.hrv_ms > 300) { flags.out_of_range["hrv_ms"] = `${raw.metrics.hrv_ms} out of [0,300]`; clean.hrv_ms = null; }
  else { clean.hrv_ms = Math.round(raw.metrics.hrv_ms * 10) / 10; }

  if (raw.metrics.resting_hr_bpm == null) { flags.missing_metrics.push("resting_hr_bpm"); clean.resting_hr_bpm = null; }
  else if (raw.metrics.resting_hr_bpm < 30 || raw.metrics.resting_hr_bpm > 200) { flags.out_of_range["resting_hr_bpm"] = `${raw.metrics.resting_hr_bpm} out of [30,200]`; clean.resting_hr_bpm = null; }
  else { clean.resting_hr_bpm = Math.round(raw.metrics.resting_hr_bpm * 10) / 10; }

  if (raw.metrics.respiratory_rate_rpm == null) { flags.missing_metrics.push("respiratory_rate_rpm"); clean.respiratory_rate_rpm = null; }
  else if (raw.metrics.respiratory_rate_rpm < 6 || raw.metrics.respiratory_rate_rpm > 40) { flags.out_of_range["respiratory_rate_rpm"] = `${raw.metrics.respiratory_rate_rpm} out of [6,40]`; clean.respiratory_rate_rpm = null; }
  else { clean.respiratory_rate_rpm = Math.round(raw.metrics.respiratory_rate_rpm * 10) / 10; }

  if (raw.metrics.sleep_duration_hrs == null) { flags.missing_metrics.push("sleep_duration_hrs"); clean.sleep_duration_hrs = null; }
  else if (raw.metrics.sleep_duration_hrs < 0 || raw.metrics.sleep_duration_hrs > 16) { flags.out_of_range["sleep_duration_hrs"] = `${raw.metrics.sleep_duration_hrs} out of [0,16]`; clean.sleep_duration_hrs = null; }
  else { clean.sleep_duration_hrs = Math.round(raw.metrics.sleep_duration_hrs * 100) / 100; }

  if (raw.metrics.sleep_efficiency_pct == null) { flags.missing_metrics.push("sleep_efficiency_pct"); clean.sleep_efficiency_pct = null; }
  else if (raw.metrics.sleep_efficiency_pct < 0 || raw.metrics.sleep_efficiency_pct > 100) { flags.out_of_range["sleep_efficiency_pct"] = `${raw.metrics.sleep_efficiency_pct} out of [0,100]`; clean.sleep_efficiency_pct = null; }
  else { clean.sleep_efficiency_pct = Math.round(raw.metrics.sleep_efficiency_pct * 10) / 10; }

  if (raw.metrics.steps == null) { flags.missing_metrics.push("steps"); clean.steps = null; }
  else { clean.steps = Math.max(0, Math.round(raw.metrics.steps)); }

  if (raw.metrics.active_minutes == null) { flags.missing_metrics.push("active_minutes"); clean.active_minutes = null; }
  else { clean.active_minutes = Math.max(0, Math.round(raw.metrics.active_minutes)); }

  clean.distance_km = raw.metrics.distance_km != null
    ? Math.round(raw.metrics.distance_km * 100) / 100
    : null;

  // ── H-01: Tier 1 metrics — optional, never block is_complete ──
  // spo2_pct: valid range 70–100%
  if (raw.metrics.spo2_pct == null) {
    clean.spo2_pct = null;
  } else if (raw.metrics.spo2_pct < 70 || raw.metrics.spo2_pct > 100) {
    flags.out_of_range["spo2_pct"] = `${raw.metrics.spo2_pct} out of [70,100]`;
    clean.spo2_pct = null;
  } else {
    clean.spo2_pct = Math.round(raw.metrics.spo2_pct * 10) / 10;
  }

  // resting_energy: kcal/day, valid range 500–5000
  if (raw.metrics.resting_energy == null) {
    clean.resting_energy = null;
  } else if (raw.metrics.resting_energy < 500 || raw.metrics.resting_energy > 5000) {
    flags.out_of_range["resting_energy"] = `${raw.metrics.resting_energy} out of [500,5000]`;
    clean.resting_energy = null;
  } else {
    clean.resting_energy = Math.round(raw.metrics.resting_energy);
  }

  // stand_hours: valid range 0–24
  if (raw.metrics.stand_hours == null) {
    clean.stand_hours = null;
  } else if (raw.metrics.stand_hours < 0 || raw.metrics.stand_hours > 24) {
    flags.out_of_range["stand_hours"] = `${raw.metrics.stand_hours} out of [0,24]`;
    clean.stand_hours = null;
  } else {
    clean.stand_hours = Math.round(raw.metrics.stand_hours * 10) / 10;
  }

  // is_complete only tracks original 7 primary metrics — Tier 1 are bonus
  const primaryMetrics = [
    "hrv_ms", "resting_hr_bpm", "respiratory_rate_rpm",
    "sleep_duration_hrs", "sleep_efficiency_pct", "steps", "active_minutes",
  ];
  flags.is_complete = primaryMetrics.every((m) => clean[m] != null);

  return {
    row: {
      user_id: raw.userId,
      date: raw.date,
      ...clean,
      data_quality_flags: flags,
      source_version: SOURCE_VERSION,
    },
    flags,
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    const body = await req.json();
    const payloads: RawHealthKitPayload[] = Array.isArray(body.payload)
      ? body.payload
      : [body.payload];
    const results = [];

    for (const payload of payloads) {
      const { row, flags } = canonicalize(payload);
      const { data, error } = await supabase
        .from("daily_inputs")
        .upsert(row, { onConflict: "user_id,date" })
        .select()
        .single();

      if (error) {
        return new Response(
          JSON.stringify({ error: error.message, code: error.code, details: error.details, hint: error.hint }),
          { status: 400, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
        );
      }
      results.push({ date: payload.date, id: data.id, flags });
    }

    return new Response(
      JSON.stringify({ success: true, ingested: results }),
      { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" } }
    );
  }
});