// ios/MBI/Models/Models.swift
// MBI Phase 1 — Swift Data Models
// Mirrors Supabase schema exactly

import Foundation

// ─────────────────────────────────────────
// USER
// ─────────────────────────────────────────
struct MBIUser: Codable, Identifiable {
    let id: String
    var email: String
    var displayName: String?
    var stepGoal: Int
    var onboardingComplete: Bool
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName = "display_name"
        case stepGoal = "step_goal"
        case onboardingComplete = "onboarding_complete"
        case createdAt = "created_at"
    }
}

// ─────────────────────────────────────────
// DAILY SCORE
// ─────────────────────────────────────────
struct DailyScore: Codable, Identifiable {
    let id: String
    let userId: String
    let date: String
    let chronosScore: Double
    let scoreBand: ScoreBand
    let healthScore: Double?
    let riskScore: Double?
    let alpha: Double?
    let d1Autonomic: Double?
    let d2Sleep: Double?
    let d3Activity: Double?
    let d4Stress: Double?
    let d5Allostatic: Double?
    let driver1: String
    let driver2: String
    let deltaOverrideTriggered: Bool
    let failState: String?
    let isProvisional: Bool
    let domainVersion: String

    enum CodingKeys: String, CodingKey {
        case id, date
        case userId = "user_id"
        case chronosScore = "chronos_score"
        case scoreBand = "score_band"
        case healthScore = "health_score"
        case riskScore = "risk_score"
        case alpha
        case d1Autonomic = "d1_autonomic"
        case d2Sleep = "d2_sleep"
        case d3Activity = "d3_activity"
        case d4Stress = "d4_stress"
        case d5Allostatic = "d5_allostatic"
        case driver1 = "driver_1"
        case driver2 = "driver_2"
        case deltaOverrideTriggered = "delta_override_triggered"
        case failState = "fail_state"
        case isProvisional = "is_provisional"
        case domainVersion = "domain_version"
    }
}

enum ScoreBand: String, Codable {
    case thriving = "Thriving"
    case recovering = "Recovering"
    case drifting = "Drifting"
    case redline = "Redline"

    var color: String {
        switch self {
        case .thriving: return "ScoreThriving"
        case .recovering: return "ScoreRecovering"
        case .drifting: return "ScoreDrifting"
        case .redline: return "ScoreRedline"
        }
    }

    var description: String {
        switch self {
        case .thriving: return "Strong recovery and adaptation"
        case .recovering: return "Mild stress load, within range"
        case .drifting: return "Risk accumulating, needs attention"
        case .redline: return "Acute physiological stress"
        }
    }
}

// ─────────────────────────────────────────
// EXPLANATION
// ─────────────────────────────────────────
struct Explanation: Codable, Identifiable {
    let id: String
    let scoreId: String
    let userId: String
    let date: String
    let explanationText: String
    let nudgeText: String
    let promptVersion: String
    let modelVersion: String

    enum CodingKeys: String, CodingKey {
        case id
        case scoreId = "score_id"
        case userId = "user_id"
        case date
        case explanationText = "explanation_text"
        case nudgeText = "nudge_text"
        case promptVersion = "prompt_version"
        case modelVersion = "model_version"
    }
}

// ─────────────────────────────────────────
// DASHBOARD (combined view model)
// ─────────────────────────────────────────
struct DashboardData {
    let score: DailyScore
    let explanation: Explanation?
    let recentScores: [Double]   // last 7 Chronos scores for sparkline

    var isStale: Bool = false
}

// ─────────────────────────────────────────
// TREND POINT
// ─────────────────────────────────────────
struct TrendPoint: Identifiable {
    var id: String { date }
    let date: String      // "yyyy-MM-dd"
    let score: Double
}

// ─────────────────────────────────────────
// METRIC LABELS (for UI display)
// ─────────────────────────────────────────
enum Metric: String {
    case hrv
    case resting_hr
    case respiratory_rate
    case sleep_duration
    case sleep_efficiency
    case steps
    case active_minutes
    case distance

    var displayName: String {
        switch self {
        case .hrv: return "Heart Rate Variability"
        case .resting_hr: return "Resting Heart Rate"
        case .respiratory_rate: return "Respiratory Rate"
        case .sleep_duration: return "Sleep Duration"
        case .sleep_efficiency: return "Sleep Quality"
        case .steps: return "Daily Steps"
        case .active_minutes: return "Active Minutes"
        case .distance: return "Distance"
        }
    }

    var shortName: String {
        switch self {
        case .hrv: return "HRV"
        case .resting_hr: return "Resting HR"
        case .respiratory_rate: return "Resp. Rate"
        case .sleep_duration: return "Sleep"
        case .sleep_efficiency: return "Sleep Quality"
        case .steps: return "Steps"
        case .active_minutes: return "Active Min"
        case .distance: return "Distance"
        }
    }
}
