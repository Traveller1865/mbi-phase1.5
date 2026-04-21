// ios/MBI/MBI/Views/TrendView.swift
// MBI Phase 1.5 — Trend Tab · E-10 update (R-02)
// Unbiased deviation callouts replace threshold-based InsightCards
// loadDeviations reads DailyScore domain fields — no metrics dictionary

import SwiftUI

// ─────────────────────────────────────────
// METRIC DEVIATION  — view-layer model
// Lives here (not Models.swift) because it references Color + ChronosTheme
// ─────────────────────────────────────────

struct MetricDeviation {
    let metricKey: String
    let displayName: String
    let deviationPct: Double
    var absMagnitude: Double { abs(deviationPct) }
    var direction: String { deviationPct >= 0 ? "above" : "below" }

    var accentColor: Color {
        let higherIsBad = ["resting_hr", "respiratory_rate"]
        let isGood = higherIsBad.contains(metricKey) ? deviationPct < 0 : deviationPct > 0
        if absMagnitude < 5 { return ChronosTheme.muted }
        return isGood
            ? Color(red: 0.35, green: 0.80, blue: 0.45)
            : Color(red: 0.90, green: 0.55, blue: 0.30)
    }

    var displayLabel: String {
        "\(displayName) is \(Int(absMagnitude))% \(direction) your baseline"
    }
}

// ─────────────────────────────────────────
// TREND VIEW
// ─────────────────────────────────────────

struct TrendView: View {
    @EnvironmentObject var sync: SyncCoordinator
    @EnvironmentObject var supabase: SupabaseService
    @State private var deviations: [MetricDeviation] = []

    // Metric display names — mirrors METRIC_LABELS in narrate/index.ts
    private let metricLabels: [String: String] = [
        "hrv":               "Heart Rate Variability",
        "resting_hr":        "Resting Heart Rate",
        "respiratory_rate":  "Respiratory Rate",
        "sleep_duration":    "Sleep Duration",
        "sleep_efficiency":  "Sleep Quality",
        "steps":             "Daily Steps",
        "active_minutes":    "Active Minutes",
    ]

    var body: some View {
        ZStack {
            ChronosTheme.ink.ignoresSafeArea()

            RadialGradient(
                colors: [ChronosTheme.gold.opacity(0.04), .clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    TrendHeader()

                    if let data = sync.dashboard {
                        let trend = sync.trendData

                        ScoreRibbon(trendData: trend.isEmpty ? fallback(from: data.recentScores) : trend)
                            .padding(.horizontal, 20).padding(.bottom, 16)

                        if let explanation = data.explanation {
                            WeeklyNarrativeCard(
                                scores: trend.map { $0.score },
                                explanation: explanation
                            )
                            .padding(.horizontal, 20).padding(.bottom, 16)
                        }

                        // ── Unbiased signal callouts (R-02) ──────────────
                        let analysis = WeekAnalysis(
                            trendData: trend.isEmpty ? fallback(from: data.recentScores) : trend,
                            deviations: deviations
                        )
                        let signals = analysis.topSignals

                        if signals.isEmpty && deviations.isEmpty {
                            TrendSignalPlaceholder()
                                .padding(.horizontal, 20).padding(.bottom, 40)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(Array(signals.enumerated()), id: \.offset) { _, signal in
                                    DeviationCalloutCard(signal: signal)
                                }
                            }
                            .padding(.horizontal, 20).padding(.bottom, 40)
                        }

                    } else {
                        TrendEmptyView().padding(.top, 60)
                    }
                }
            }
        }
        .task {
            guard let userId = supabase.session?.userId else { return }
            await sync.loadTrendData(userId: userId)
            await loadDeviations(userId: userId)
        }
    }

    // ── Deviation loader ──────────────────────────────────────────────
    // DailyScore exposes domain scores (d1/d2/d3), not raw metric values.
    // We map each domain to the metrics it represents and compute deviation
    // against the baseline value for that domain key.
    // When daily_inputs is surfaced (post R-03), swap domain proxies for
    // actual per-metric values from that table.
    private func loadDeviations(userId: String) async {
        guard let score = sync.dashboard?.score else { return }

        do {
            let baselines = try await supabase.fetchLatestBaselines(userId: userId)
            guard !baselines.isEmpty else { return }

            // Domain-level proxies — one value per domain, mapped to the
            // baseline keys that exist in the baselines table.
            // d1_autonomic → hrv, resting_hr, respiratory_rate
            // d2_sleep     → sleep_duration, sleep_efficiency
            // d3_activity  → steps, active_minutes
            let domainMap: [String: Double?] = [
                "hrv":              score.d1Autonomic,
                "resting_hr":       score.d1Autonomic,
                "respiratory_rate": score.d1Autonomic,
                "sleep_duration":   score.d2Sleep,
                "sleep_efficiency": score.d2Sleep,
                "steps":            score.d3Activity,
                "active_minutes":   score.d3Activity,
            ]

            var seen = Set<String>()    // one card per domain — deduplicate proxied keys
            var result: [MetricDeviation] = []

            for (key, baseline) in baselines {
                guard baseline > 0,
                      let currentOpt = domainMap[key],
                      let current = currentOpt,
                      let label = metricLabels[key] else { continue }

                // Only emit one card per underlying domain value to avoid
                // three identical cards for d1_autonomic proxy keys.
                let domainValue = String(format: "%.4f", current)
                guard seen.insert(domainValue).inserted else { continue }

                let pct = ((current - baseline) / baseline) * 100
                result.append(MetricDeviation(metricKey: key, displayName: label, deviationPct: pct))
            }

            deviations = result
        } catch {
            print("[TrendView] deviation load failed: \(error)")
        }
    }

    private func fallback(from scores: [Double]) -> [TrendPoint] {
        let cal = Calendar.current
        return scores.enumerated().map { i, score in
            let daysAgo = scores.count - 1 - i
            let date = cal.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return TrendPoint(date: formatter.string(from: date), score: score)
        }
    }
}

// ─────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────

struct TrendHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR WEEK")
                .font(.jost(size: 10, weight: .light))
                .foregroundColor(ChronosTheme.gold)
                .tracking(3)

            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text("in signal.")
                    .font(.cormorant(size: 32, weight: .light))
                    .foregroundColor(ChronosTheme.text)
                Text(" ")
                Text("Seven days. One story.")
                    .font(.cormorantItalic(size: 16))
                    .foregroundColor(ChronosTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
}

// ─────────────────────────────────────────
// SCORE RIBBON  (7-day bar chart)
// ─────────────────────────────────────────

struct ScoreRibbon: View {
    let trendData: [TrendPoint]

    private var todayIndex: Int { max(trendData.count - 1, 0) }

    private var lowIndex: Int? {
        guard let min = trendData.map({ $0.score }).min(),
              min < 50 else { return nil }
        return trendData.firstIndex(where: { $0.score == min })
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.09, blue: 0.16),
                        Color(red: 0.06, green: 0.06, blue: 0.10)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))

            VStack {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, ChronosTheme.gold, .clear],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(height: 1)
                    .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
                Spacer()
            }

            VStack(spacing: 12) {
                Text(weekLabel())
                    .font(.jost(size: 10, weight: .light))
                    .foregroundColor(ChronosTheme.muted)
                    .tracking(2).textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(trendData.enumerated()), id: \.offset) { i, point in
                        VStack(spacing: 6) {
                            if i == todayIndex {
                                Text("\(Int(point.score))")
                                    .font(.jost(size: 10, weight: .medium))
                                    .foregroundColor(ChronosTheme.goldLight)
                            } else {
                                Text("\(Int(point.score))")
                                    .font(.jost(size: 9, weight: .light))
                                    .foregroundColor(ChronosTheme.faint)
                            }

                            GeometryReader { geo in
                                VStack {
                                    Spacer()
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(barGradient(index: i))
                                        .frame(height: barHeight(score: point.score, maxHeight: geo.size.height))
                                }
                            }

                            Text(dayLabel(from: point.date))
                                .font(.jost(size: 9, weight: i == todayIndex ? .medium : .light))
                                .foregroundColor(i == todayIndex ? ChronosTheme.gold : ChronosTheme.muted)
                                .tracking(0.5)
                        }
                    }
                }
                .frame(height: 100)
            }
            .padding(20)
        }
    }

    private func barGradient(index: Int) -> LinearGradient {
        if index == todayIndex {
            return LinearGradient(
                colors: [ChronosTheme.gold, ChronosTheme.goldLight],
                startPoint: .bottom, endPoint: .top
            )
        } else if index == lowIndex {
            return LinearGradient(
                colors: [
                    Color(red: 0.65, green: 0.25, blue: 0.25).opacity(0.4),
                    Color(red: 0.72, green: 0.30, blue: 0.30).opacity(0.6)
                ],
                startPoint: .bottom, endPoint: .top
            )
        } else {
            return LinearGradient(
                colors: [ChronosTheme.gold.opacity(0.3), ChronosTheme.gold.opacity(0.55)],
                startPoint: .bottom, endPoint: .top
            )
        }
    }

    private func barHeight(score: Double, maxHeight: CGFloat) -> CGFloat {
        let scores = trendData.map { $0.score }
        let minS = (scores.min() ?? 0) - 8
        let maxS = (scores.max() ?? 100) + 4
        let range = maxS - minS
        guard range > 0 else { return maxHeight * 0.5 }
        let pct = CGFloat((score - minS) / range)
        return max(pct * maxHeight, 6)
    }

    private func dayLabel(from dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return "?" }
        formatter.dateFormat = "E"
        return String(formatter.string(from: date).prefix(1)).uppercased()
    }

    private func weekLabel() -> String {
        guard let first = trendData.first else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: first.date) else { return "" }
        formatter.dateFormat = "MMMM d"
        return "Week of \(formatter.string(from: date))"
    }
}

// ─────────────────────────────────────────
// WEEKLY NARRATIVE CARD
// ─────────────────────────────────────────

struct WeeklyNarrativeCard: View {
    let scores: [Double]
    let explanation: Explanation

    var weekSummary: String {
        guard !scores.isEmpty else { return "" }
        let avg = scores.reduce(0, +) / Double(scores.count)
        let trend = (scores.last ?? 0) - (scores.first ?? 0)
        let direction = trend > 5 ? "improving" : trend < -5 ? "declining" : "holding steady"
        return "7-day average \(Int(avg)) · \(direction)"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.08, green: 0.08, blue: 0.14),
                        Color(red: 0.06, green: 0.06, blue: 0.10)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(ChronosTheme.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 14) {
                Text(weekLabel())
                    .font(.jost(size: 9, weight: .light))
                    .foregroundColor(ChronosTheme.gold)
                    .tracking(3).textCase(.uppercase)

                Rectangle().fill(ChronosTheme.gold.opacity(0.2)).frame(height: 1)

                Text(explanation.explanationText)
                    .font(.jost(size: 14, weight: .light))
                    .foregroundColor(Color(red: 0.965, green: 0.953, blue: 0.920))
                    .lineSpacing(7).fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(ChronosTheme.gold)
                        .frame(width: 5, height: 5)
                        .padding(.top, 4)
                    Text(weekSummary)
                        .font(.jost(size: 11, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                        .italic().lineSpacing(4)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
    }

    private func weekLabel() -> String {
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return "Week of \(formatter.string(from: weekStart))"
    }
}

// ─────────────────────────────────────────
// DEVIATION CALLOUT CARD  (R-02)
// ─────────────────────────────────────────

struct DeviationCalloutCard: View {
    let signal: MetricDeviation

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(signal.accentColor.opacity(0.7))
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 5) {
                Text("\(Int(signal.absMagnitude))% \(signal.direction) baseline".uppercased())
                    .font(.jost(size: 9, weight: .light))
                    .foregroundColor(signal.accentColor)
                    .tracking(2.5)

                Text(signal.displayLabel)
                    .font(.jost(size: 13, weight: .light))
                    .foregroundColor(ChronosTheme.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ChronosTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(signal.accentColor.opacity(0.15), lineWidth: 1))
        )
    }
}

// ─────────────────────────────────────────
// TREND SIGNAL PLACEHOLDER
// ─────────────────────────────────────────

struct TrendSignalPlaceholder: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(ChronosTheme.faint)
            Text("Signal callouts appear once your baseline has enough data.")
                .font(.jost(size: 12, weight: .light))
                .foregroundColor(ChronosTheme.faint)
                .lineSpacing(4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ChronosTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(ChronosTheme.border, lineWidth: 1))
        )
    }
}

// ─────────────────────────────────────────
// WEEK ANALYSIS  — unbiased deviation ranking (R-02)
// ─────────────────────────────────────────

struct WeekAnalysis {
    let trendData: [TrendPoint]
    var deviations: [MetricDeviation] = []

    var scores: [Double] { trendData.map { $0.score } }

    var topSignals: [MetricDeviation] {
        deviations
            .filter { $0.absMagnitude >= 5 }
            .sorted { $0.absMagnitude > $1.absMagnitude }
            .prefix(3)
            .map { $0 }
    }

    var weekSummaryText: String {
        guard !scores.isEmpty else { return "" }
        let avg = scores.reduce(0, +) / Double(scores.count)
        let trend = (scores.last ?? 0) - (scores.first ?? 0)
        let direction = trend > 5 ? "improving" : trend < -5 ? "declining" : "holding steady"
        return "7-day average \(Int(avg)) · \(direction)"
    }
}

// ─────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────

struct TrendEmptyView: View {
    var body: some View {
        VStack(spacing: 20) {
            ChronosLogoMark()
                .frame(width: 52, height: 52)
                .opacity(0.3)

            Text("No trend yet")
                .font(.cormorant(size: 24))
                .foregroundColor(ChronosTheme.muted)

            Text("Your weekly trend will appear after\nyour first few days of data are scored.")
                .font(.jost(size: 13, weight: .light))
                .foregroundColor(ChronosTheme.faint)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 48)
        }
    }
}
