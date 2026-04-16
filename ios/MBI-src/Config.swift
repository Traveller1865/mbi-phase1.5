// ios/MBI/Config.swift
// MBI Phase 1 — Configuration
// Replace placeholder values with your actual Supabase project credentials

import Foundation

enum Config {
    // ── Supabase ──────────────────────────────────────────────────────────
    // Find these in: Supabase Dashboard → Project Settings → API
    static let supabaseURL = "https://YOUR_PROJECT_REF.supabase.co"
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"

    // ── Edge Function URLs ────────────────────────────────────────────────
    static var ingestURL: URL { URL(string: "\(supabaseURL)/functions/v1/ingest")! }
    static var scoreURL: URL { URL(string: "\(supabaseURL)/functions/v1/score")! }
    static var narrateURL: URL { URL(string: "\(supabaseURL)/functions/v1/narrate")! }
    static var adminURL: URL { URL(string: "\(supabaseURL)/functions/v1/admin")! }

    // ── App Constants ─────────────────────────────────────────────────────
    static let defaultStepGoal = 8000
    static let minHistoryDaysForScore = 3
    static let appVersion = "1.0.0"
}
