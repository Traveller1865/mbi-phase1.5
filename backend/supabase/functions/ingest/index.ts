// backend/supabase/functions/ingest/index.ts
// MBI Phase 1 — Ingestion & Canonicalization Layer

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("https://sjhysadnpswrcpmezmoc.supabase.co/functions/v1/ingest")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqaHlzYWRucHN3cmNwbWV6bW9jIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjI3MDcyMywiZXhwIjoyMDkxODQ2NzIzfQ.1FjI_Lteygh5Z0FUeBXQsaa3mS4Qm0oLd1FoI49qysE")!;
const SOURCE_VERSION = "1.0";

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
  const flags: DataQualityFlags = {
    missing_metrics: [],
    out_of_range: {},
    is_complete: false,
  };

  const clean: Record<string, number | null> = {};

  if (raw.metrics.hrv_ms == null) {
    flags.missing_metrics.push("hrv_ms");
    clean.hrv_ms = null;
  } else if (raw.metrics.hrv_ms < 0 || raw.metrics.hrv_ms > 300) {
    flags.out_of_range["hrv_ms"] = `${raw.metrics.hrv_ms} out of [0,300]`;
    clean.hrv_ms = null;
  } else {
    clean.hrv_ms = Math.round(raw.metrics.hrv_ms * 10) / 10;
  }

  if (raw.metrics.resting_hr_bpm == null) {
    flags.missing_metrics.push("resting_hr_bpm");
    clean.resting_hr_bpm = null;
  } else if (raw.metrics.resting_hr_bpm < 30 || raw.metrics.resting_hr_bpm > 200) {
    flags.out_of_range["resting_hr_bpm"] = `${raw.metrics.resting_hr_bpm} out of [30,200]`;
    clean.resting_hr_bpm = null;
  } else {
    clean.resting_hr_bpm = Math.round(raw.metrics.resting_hr_bpm * 10) / 10;
  }

  if (raw.metrics.respiratory_rate_rpm == null) {
    flags.missing_metrics.push("respiratory_rate_rpm");
    clean.respiratory_rate_rpm = null;
  } else if (raw.metrics.respiratory_rate_rpm < 6 || raw.metrics.respiratory_rate_rpm > 40) {
    flags.out_of_range["respiratory_rate_rpm"] = `${raw.metrics.respiratory_rate_rpm} out of [6,40]`;
    clean.respiratory_rate_rpm = null;
  } else {
    clean.respiratory_rate_rpm = Math.round(raw.metrics.respiratory_rate_rpm * 10) / 10;
  }

  if (raw.metrics.sleep_duration_hrs == null) {
    flags.missing_metrics.push("sleep_duration_hrs");
    clean.sleep_duration_hrs = null;
  } else if (raw.metrics.sleep_duration_hrs < 0 || raw.metrics.sleep_duration_hrs > 16) {
    flags.out_of_range["sleep_duration_hrs"] = `${raw.metrics.sleep_duration_hrs} out of [0,16]`;
    clean.sleep_duration_hrs = null;
  } else {
    clean.sleep_duration_hrs = Math.round(raw.metrics.sleep_duration_hrs * 100) / 100;
  }

  if (raw.metrics.sleep_efficiency_pct == null) {
    flags.missing_metrics.push("sleep_efficiency_pct");
    clean.sleep_efficiency_pct = null;
  } else if (raw.metrics.sleep_efficiency_pct < 0 || raw.metrics.sleep_efficiency_pct > 100) {
    flags.out_of_range["sleep_efficiency_pct"] = `${raw.metrics.sleep_efficiency_pct} out of [0,100]`;
    clean.sleep_efficiency_pct = null;
  } else {
    clean.sleep_efficiency_pct = Math.round(raw.metrics.sleep_efficiency_pct * 10) / 10;
  }

  if (raw.metrics.steps == null) {
    flags.missing_metrics.push("steps");
    clean.steps = null;
  } else {
    clean.steps = Math.max(0, Math.round(raw.metrics.steps));
  }

  if (raw.metrics.active_minutes == null) {
    flags.missing_metrics.push("active_minutes");
    clean.active_minutes = null;
  } else {
    clean.active_minutes = Math.max(0, Math.round(raw.metrics.active_minutes));
  }

  clean.distance_km = raw.metrics.distance_km != null
    ? Math.round(raw.metrics.distance_km * 100) / 100
    : null;

  const primaryMetrics = ["hrv_ms", "resting_hr_bpm", "respiratory_rate_rpm", "sleep_duration_hrs", "sleep_efficiency_pct", "steps", "active_minutes"];
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
    // Validate env vars are present
    if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
      return new Response(
        JSON.stringify({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY env vars" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

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
        // Return the actual Postgres error message, not [object Object]
        return new Response(
          JSON.stringify({
            error: error.message,
            code: error.code,
            details: error.details,
            hint: error.hint,
          }),
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