// ios/MBI/MBI/Models/Models.swift
// MBI Phase 1 — Swift Data Models
// Mirrors Supabase schema exactly
// Sprint 1.5: ScoreBand.yellowline added — client-side detection only (no schema change yet)
// Sprint 4:   MBIUser gains 6 new profile fields per schema migration

import Foundation

// ─────────────────────────────────────────
// USER
// Sprint 4: healthGoal, weightLbs, wakeTime, sleepTime,
//           morningBriefEnabled, biologicalSex added.
//           All match new users table columns exactly.
// ─────────────────────────────────────────
struct MBIUser: Codable, Identifiable {
    let id: String
    var email: String
    var displayName: String?
    var stepGoal: Int
    var onboardingComplete: Bool
    var createdAt: String?

    // Sprint 4 — Profile section fields
    var healthGoal: String          // 'general_wellness' | 'longevity' | 'recovery' | 'stress_management' | 'fitness'
    var weightLbs: Double?          // nullable — user enters on first edit
    var wakeTime: String            // HH:MM 24h e.g. "06:00"
    var sleepTime: String           // HH:MM 24h e.g. "22:00"
    var morningBriefEnabled: Bool
    var biologicalSex: String?      // 'male' | 'female' | 'prefer_not_to_say' — schema only in Sprint 4
    var birthday: String?
    var heightFt: Int?
    var heightIn: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case displayName            = "display_name"
        case stepGoal               = "step_goal"
        case onboardingComplete     = "onboarding_complete"
        case createdAt              = "created_at"
        case healthGoal             = "health_goal"
        case weightLbs              = "weight_lbs"
        case wakeTime               = "wake_time"
        case sleepTime              = "sleep_time"
        case morningBriefEnabled    = "morning_brief_enabled"
        case biologicalSex          = "biological_sex"
        case birthday               = "birthday"
        case heightFt               = "height_ft"
        case heightIn               = "height_in"
    }

    // Provide defaults during decode so existing rows without
    // the new columns (pre-migration) don't crash the decoder.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                    = try c.decode(String.self,  forKey: .id)
        email                 = try c.decode(String.self,  forKey: .email)
        displayName           = try c.decodeIfPresent(String.self,  forKey: .displayName)
        stepGoal              = try c.decodeIfPresent(Int.self,     forKey: .stepGoal)              ?? 8000
        onboardingComplete    = try c.decodeIfPresent(Bool.self,    forKey: .onboardingComplete)    ?? false
        createdAt             = try c.decodeIfPresent(String.self,  forKey: .createdAt)
        healthGoal            = try c.decodeIfPresent(String.self,  forKey: .healthGoal)            ?? "general_wellness"
        weightLbs             = try c.decodeIfPresent(Double.self,  forKey: .weightLbs)
        wakeTime              = try c.decodeIfPresent(String.self,  forKey: .wakeTime)              ?? "06:00"
        sleepTime             = try c.decodeIfPresent(String.self,  forKey: .sleepTime)             ?? "22:00"
        morningBriefEnabled   = try c.decodeIfPresent(Bool.self,    forKey: .morningBriefEnabled)   ?? true
        biologicalSex         = try c.decodeIfPresent(String.self,  forKey: .biologicalSex)
        birthday  = try c.decodeIfPresent(String.self, forKey: .birthday)
        heightFt  = try c.decodeIfPresent(Int.self,    forKey: .heightFt)
        heightIn  = try c.decodeIfPresent(Int.self,    forKey: .heightIn)
        
    }

    // Standard memberwise init for constructing in tests / previews
    init(
        id: String,
        email: String,
        displayName: String? = nil,
        stepGoal: Int = 8000,
        onboardingComplete: Bool = false,
        createdAt: String? = nil,
        healthGoal: String = "general_wellness",
        weightLbs: Double? = nil,
        wakeTime: String = "06:00",
        sleepTime: String = "22:00",
        morningBriefEnabled: Bool = true,
        biologicalSex: String? = nil,
        birthday: String? = nil,
        heightFt: Int? = nil,
        heightIn: Int? = nil
    ) {
        self.id                  = id
        self.email               = email
        self.displayName         = displayName
        self.stepGoal            = stepGoal
        self.onboardingComplete  = onboardingComplete
        self.createdAt           = createdAt
        self.healthGoal          = healthGoal
        self.weightLbs           = weightLbs
        self.wakeTime            = wakeTime
        self.sleepTime           = sleepTime
        self.morningBriefEnabled = morningBriefEnabled
        self.biologicalSex       = biologicalSex
        self.birthday = birthday
        self.heightFt = heightFt
        self.heightIn = heightIn
    }
}

// ─────────────────────────────────────────
// HEALTH GOAL ENUM  (Sprint 4)
// Strongly-typed wrapper around the text column.
// The raw value matches what is stored in Supabase exactly.
// ─────────────────────────────────────────
enum HealthGoal: String, CaseIterable, Identifiable {
    case generalWellness   = "general_wellness"
    case longevity         = "longevity"
    case recovery          = "recovery"
    case stressManagement  = "stress_management"
    case fitness           = "fitness"

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .generalWellness:  return "General Wellness"
        case .longevity:        return "Longevity"
        case .recovery:         return "Recovery & Restoration"
        case .stressManagement: return "Stress Management"
        case .fitness:          return "Build Fitness"
        }
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

// ─────────────────────────────────────────
// SCORE BAND
// Sprint 1.5: .yellowline added
// ─────────────────────────────────────────
enum ScoreBand: String, Codable {
    case thriving   = "Thriving"
    case recovering = "Recovering"
    case yellowline = "Yellowline"
    case drifting   = "Drifting"
    case redline    = "Redline"

    var color: String {
        switch self {
        case .thriving:   return "ScoreThriving"
        case .recovering: return "ScoreRecovering"
        case .yellowline: return "ScoreYellowline"
        case .drifting:   return "ScoreDrifting"
        case .redline:    return "ScoreRedline"
        }
    }

    var description: String {
        switch self {
        case .thriving:   return "Strong recovery and adaptation"
        case .recovering: return "Mild stress load, within range"
        case .yellowline: return "Early decline — worth paying attention to"
        case .drifting:   return "Risk accumulating, needs attention"
        case .redline:    return "Acute physiological stress"
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
// Sprint 1.5: computedBand added — resolves Yellowline client-side
// ─────────────────────────────────────────
struct DashboardData {
    let score: DailyScore
    let explanation: Explanation?
    let recentScores: [Double]

    var isStale: Bool = false

    var computedBand: ScoreBand {
        guard score.scoreBand != .redline && score.scoreBand != .drifting else {
            return score.scoreBand
        }
        guard score.chronosScore > 75 else { return score.scoreBand }
        guard recentScores.count >= 2 else { return score.scoreBand }

        let yesterday = recentScores[recentScores.count - 2]
        let drop = yesterday - score.chronosScore

        if drop >= 1 && drop <= 5 {
            return .yellowline
        }
        return score.scoreBand
    }
}

// ─────────────────────────────────────────
// TREND POINT
// ─────────────────────────────────────────
struct TrendPoint: Identifiable {
    var id: String { date }
    let date: String
    let score: Double
}

// ─────────────────────────────────────────
// METRIC LABELS
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
        case .hrv:               return "Heart Rate Variability"
        case .resting_hr:        return "Resting Heart Rate"
        case .respiratory_rate:  return "Respiratory Rate"
        case .sleep_duration:    return "Sleep Duration"
        case .sleep_efficiency:  return "Sleep Quality"
        case .steps:             return "Daily Steps"
        case .active_minutes:    return "Active Minutes"
        case .distance:          return "Distance"
        }
    }

    var shortName: String {
        switch self {
        case .hrv:               return "HRV"
        case .resting_hr:        return "Resting HR"
        case .respiratory_rate:  return "Resp. Rate"
        case .sleep_duration:    return "Sleep"
        case .sleep_efficiency:  return "Sleep Quality"
        case .steps:             return "Steps"
        case .active_minutes:    return "Active Min"
        case .distance:          return "Distance"
        }
    }
}

// ─────────────────────────────────────────
// TREND AGGREGATE  (Sprint 2)
// ─────────────────────────────────────────
struct TrendAggregate: Codable, Identifiable {
    let id: String
    let userId: String
    let windowType: String
    let windowStart: String
    let windowEnd: String

    let chronosAvg: Double?
    let chronosMin: Double?
    let chronosMax: Double?
    let trendDirection: String?
    let daysInWindow: Int

    let hrvAvg: Double?
    let restingHrAvg: Double?
    let respiratoryRateAvg: Double?
    let sleepDurationAvg: Double?
    let sleepEfficiencyAvg: Double?
    let stepsAvg: Double?
    let activeMinutesAvg: Double?

    let topDriver1: String?
    let topDriver2: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId             = "user_id"
        case windowType         = "window_type"
        case windowStart        = "window_start"
        case windowEnd          = "window_end"
        case chronosAvg         = "chronos_avg"
        case chronosMin         = "chronos_min"
        case chronosMax         = "chronos_max"
        case trendDirection     = "trend_direction"
        case daysInWindow       = "days_in_window"
        case hrvAvg             = "hrv_avg"
        case restingHrAvg       = "resting_hr_avg"
        case respiratoryRateAvg = "respiratory_rate_avg"
        case sleepDurationAvg   = "sleep_duration_avg"
        case sleepEfficiencyAvg = "sleep_efficiency_avg"
        case stepsAvg           = "steps_avg"
        case activeMinutesAvg   = "active_minutes_avg"
        case topDriver1         = "top_driver_1"
        case topDriver2         = "top_driver_2"
    }

    func avg(for metricKey: String) -> Double? {
        switch metricKey {
        case "hrv":               return hrvAvg
        case "resting_hr":        return restingHrAvg
        case "respiratory_rate":  return respiratoryRateAvg
        case "sleep_duration":    return sleepDurationAvg
        case "sleep_efficiency":  return sleepEfficiencyAvg
        case "steps":             return stepsAvg
        case "active_minutes":    return activeMinutesAvg
        default:                  return nil
        }
    }
}

// ─────────────────────────────────────────
// TREND WINDOW  (Sprint 2)
// ─────────────────────────────────────────
enum TrendWindow: String, CaseIterable {
    case sevenDay    = "7D"
    case eightWeek   = "8W"
    case twelveMonth = "12M"

    var apiKey: String {
        switch self {
        case .sevenDay:    return "7d"
        case .eightWeek:   return "8w"
        case .twelveMonth: return "12m"
        }
    }

    var aggregateType: String {
        switch self {
        case .sevenDay:    return "daily"
        case .eightWeek:   return "weekly"
        case .twelveMonth: return "monthly"
        }
    }

    var fetchLimit: Int {
        switch self {
        case .sevenDay:    return 7
        case .eightWeek:   return 8
        case .twelveMonth: return 12
        }
    }

    var headerEyebrow: String {
        switch self {
        case .sevenDay:    return "YOUR WEEK"
        case .eightWeek:   return "YOUR MONTH"
        case .twelveMonth: return "YOUR YEAR"
        }
    }

    var headerTitle: String {
        switch self {
        case .sevenDay:    return "in signal."
        case .eightWeek:   return "in pattern."
        case .twelveMonth: return "in arc."
        }
    }

    var headerSubtitle: String {
        switch self {
        case .sevenDay:    return "Seven days. One story."
        case .eightWeek:   return "Eight weeks. One arc."
        case .twelveMonth: return "Twelve months. One trajectory."
        }
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        switch self {
        case .sevenDay:
            let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
            formatter.dateFormat = "MMMM d"
            return "WEEK OF \(formatter.string(from: weekStart).uppercased())"
        case .eightWeek:
            return "LAST 8 WEEKS"
        case .twelveMonth:
            return "LAST 12 MONTHS"
        }
    }

    var buildingThreshold: Int {
        switch self {
        case .sevenDay:    return 3
        case .eightWeek:   return 2
        case .twelveMonth: return 3
        }
    }

    var buildingLabel: String {
        switch self {
        case .sevenDay:    return "Baseline building"
        case .eightWeek:   return "Building — more weeks needed"
        case .twelveMonth: return "Building — history deepens over time"
        }
    }
}

// ─────────────────────────────────────────
// METRIC TILE DATA  (Sprint 2)
// ─────────────────────────────────────────
struct MetricTileData: Identifiable {
    let id: String
    let displayName: String
    let shortName: String
    let todayValue: Double?
    let sevenDayAvg: Double?
    let thirtyDayAvg: Double?
    let unit: String

    var isChronos: Bool { id == "chronos" }
}

// ─────────────────────────────────────────
// TREND SIGNAL CALLOUT  (Sprint 2)
// ─────────────────────────────────────────
enum CalloutCategory {
    case workingForYou
    case worthWatching
}

struct TrendCallout: Identifiable {
    let id = UUID()
    let category: CalloutCategory
    let text: String
}
