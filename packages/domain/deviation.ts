// packages/domain/deviation.ts
// MBI Scoring Engine — Deviation Detection
// Version: 1.1 | ALL thresholds sourced from Scoring Engine Source of Truth v1.1

import type { Baseline, DailyInput, DeviationState, MetricDeviation } from "./contracts.ts";

// ─────────────────────────────────────────
// WEIGHTS (SoT §2)
// ─────────────────────────────────────────
export const METRIC_WEIGHTS: Record<string, number> = {
  hrv: 2,
  resting_hr: 2,
  respiratory_rate: 2,
  sleep_duration: 1.5,
  sleep_efficiency: 1.5,
  steps: 1,
  active_minutes: 1,
  distance: 0, // supporting only
};

// ─────────────────────────────────────────
// HRV (SDNN) — Weight 2× (SoT §4.1)
// ─────────────────────────────────────────
function deviateHRV(value: number | null | undefined, baseline: Baseline): DeviationState {
  if (value == null || baseline.hrv_avg == null) return 0;
  // Guardrail
  if (value < 25) return -2;
  const pctBelow = (baseline.hrv_avg - value) / baseline.hrv_avg;
  if (pctBelow > 0.30) return -2;
  if (pctBelow >= 0.15) return -1;
  return 0;
}

// ─────────────────────────────────────────
// RESTING HEART RATE — Weight 2× (SoT §4.2)
// ─────────────────────────────────────────
function deviateRHR(value: number | null | undefined, baseline: Baseline): DeviationState {
  if (value == null || baseline.resting_hr_avg == null) return 0;
  // Guardrail
  if (value > 90) return -2;
  const diff = value - baseline.resting_hr_avg;
  if (diff >= 10) return -2;
  if (diff >= 5) return -1;
  return 0;
}

// ─────────────────────────────────────────
// RESPIRATORY RATE — Weight 2× (SoT §4.3)
// ─────────────────────────────────────────
function deviateRespRate(value: number | null | undefined, baseline: Baseline): DeviationState {
  if (value == null || baseline.respiratory_rate_avg == null) return 0;
  // Guardrail
  if (value > 20) return -2;
  const diff = value - baseline.respiratory_rate_avg;
  if (diff >= 4) return -2;
  if (diff >= 2) return -1;
  return 0;
}

// ─────────────────────────────────────────
// SLEEP DURATION — Weight 1.5× (SoT §4.4)
// ─────────────────────────────────────────
function deviateSleepDuration(value: number | null | undefined, baseline: Baseline): DeviationState {
  if (value == null || baseline.sleep_duration_avg == null) return 0;
  // Guardrail
  if (value < 5.5) return -2;
  const diff = baseline.sleep_duration_avg - value; // positive = below baseline
  if (diff >= 2) return -2;
  if (diff >= 1) return -1;
  return 0;
}

// ─────────────────────────────────────────
// SLEEP EFFICIENCY — Weight 1.5× (SoT §4.5)
// ─────────────────────────────────────────
function deviateSleepEfficiency(value: number | null | undefined, baseline: Baseline): DeviationState {
  if (value == null || baseline.sleep_efficiency_avg == null) return 0;
  // Guardrail
  if (value < 70) return -2;
  const diff = baseline.sleep_efficiency_avg - value;
  if (diff >= 8) return -2; // treat hard as ≥8 per SoT
  if (diff >= 5) return -1;
  return 0;
}

// ─────────────────────────────────────────
// STEPS — Weight 1× behavioral (SoT §4.6)
// ─────────────────────────────────────────
function deviateSteps(value: number | null | undefined, stepGoal: number): DeviationState {
  if (value == null) return 0;
  if (value < stepGoal * 0.5) return -2;
  if (value < stepGoal) return -1;
  return 0;
}

// ─────────────────────────────────────────
// ACTIVE MINUTES — Weight 1× behavioral (SoT §4.7)
// ─────────────────────────────────────────
function deviateActiveMinutes(value: number | null | undefined): DeviationState {
  if (value == null) return 0;
  if (value < 10) return -2;
  if (value < 20) return -1;
  return 0;
}

// ─────────────────────────────────────────
// MAIN: compute all deviations
// ─────────────────────────────────────────
export function computeDeviations(
  input: DailyInput,
  baseline: Baseline,
  stepGoal: number = 8000
): MetricDeviation[] {
  return [
    {
      metric: "hrv",
      value: input.hrv_ms ?? null,
      deviation: deviateHRV(input.hrv_ms, baseline),
      weight: METRIC_WEIGHTS.hrv,
    },
    {
      metric: "resting_hr",
      value: input.resting_hr_bpm ?? null,
      deviation: deviateRHR(input.resting_hr_bpm, baseline),
      weight: METRIC_WEIGHTS.resting_hr,
    },
    {
      metric: "respiratory_rate",
      value: input.respiratory_rate_rpm ?? null,
      deviation: deviateRespRate(input.respiratory_rate_rpm, baseline),
      weight: METRIC_WEIGHTS.respiratory_rate,
    },
    {
      metric: "sleep_duration",
      value: input.sleep_duration_hrs ?? null,
      deviation: deviateSleepDuration(input.sleep_duration_hrs, baseline),
      weight: METRIC_WEIGHTS.sleep_duration,
    },
    {
      metric: "sleep_efficiency",
      value: input.sleep_efficiency_pct ?? null,
      deviation: deviateSleepEfficiency(input.sleep_efficiency_pct, baseline),
      weight: METRIC_WEIGHTS.sleep_efficiency,
    },
    {
      metric: "steps",
      value: input.steps ?? null,
      deviation: deviateSteps(input.steps, stepGoal),
      weight: METRIC_WEIGHTS.steps,
    },
    {
      metric: "active_minutes",
      value: input.active_minutes ?? null,
      deviation: deviateActiveMinutes(input.active_minutes),
      weight: METRIC_WEIGHTS.active_minutes,
    },
  ];
}
