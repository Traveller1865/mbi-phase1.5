// backend/supabase/functions/_shared/domain/index.ts
// Re-export of the domain package for Edge Function consumption
// In production: symlink or copy from /packages/domain at build time
// For local Supabase dev: this file mirrors the domain package exports

export { computeBaseline } from "../../../../packages/domain/baseline.ts";
export { computeDeviations, METRIC_WEIGHTS } from "../../../../packages/domain/deviation.ts";
export { scoreDay, getScoreBand, selectNudgeDomain } from "../../../../packages/domain/scoring.ts";
export { selectTopDrivers } from "../../../../packages/domain/drivers.ts";
export { computeFailState } from "../../../../packages/domain/failstates.ts";
export { DOMAIN_VERSION } from "../../../../packages/domain/contracts.ts";
export type * from "../../../../packages/domain/contracts.ts";
