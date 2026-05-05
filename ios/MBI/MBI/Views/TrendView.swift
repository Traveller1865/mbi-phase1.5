// ios/MBI/MBI/Views/TrendView.swift
// MBI Phase 1.5 — Trend Tab · Sprint 2 · Epic 1
// Full redesign: window toggle, line chart, window narrative, metric selector, signal callouts
// Replaces: ScoreRibbon (bar chart), WeeklyNarrativeCard (today's explanation),
//           DeviationCalloutCard (threshold-based), WeekAnalysis (old logic)

import SwiftUI
import Charts

// ─────────────────────────────────────────
// TREND VIEW MODEL
// Owns all window state, fetches, and narrative caching.
// Single source of truth for the Trend tab.
// ─────────────────────────────────────────

@MainActor
class TrendViewModel: ObservableObject {

    // Window state
    @Published var selectedWindow: TrendWindow = .sevenDay

    // Chart data
    @Published var chartPoints: [TrendChartPoint] = []
    @Published var selectedMetricKey: String = "chronos"    // "chronos" or a metric key

    // Narrative
    @Published var narrativeText: String = ""
    @Published var isLoadingNarrative: Bool = false

    // Metric selector
    @Published var metricTiles: [MetricTileData] = []

    // Signal callouts
    @Published var workingCallouts: [TrendCallout] = []
    @Published var watchCallouts: [TrendCallout] = []

    // Aggregate cache — keyed by window type string
    private var aggregateCache: [String: [TrendAggregate]] = [:]
    // Narrative cache — keyed by window type string
    private var narrativeCache: [String: String] = [:]
    // Raw daily rows cache
    private var dailyScoresCache: [[String: Any]] = []
    private var dailyInputsCache: [[String: Any]] = []

    // Building state
    @Published var isBuilding: Bool = false
    @Published var buildingLabel: String = ""

    // Error
    @Published var loadError: String? = nil

    private var supabase: SupabaseService?

    func attach(supabase: SupabaseService) {
        self.supabase = supabase
    }

    // ── Initial load ─────────────────────────────────────────────────
    func initialLoad(userId: String) async {
        guard let supabase else { return }

        // Scores fetch — primary, but non-fatal if it fails
        do {
            let scoresResult = try await supabase.fetchRecentDailyScores(userId: userId, limit: 7)
            dailyScoresCache = scoresResult
        } catch {
            print("[TrendViewModel] scores fetch failed: \(error)")
            // Continue — chart will show building state
        }

        // Inputs fetch — always non-fatal
        dailyInputsCache = await supabase.fetchRecentDailyInputs(userId: userId, limit: 7)

        // Monthly aggregates for 30D tile column — non-fatal
        do {
            let monthlyResult = try await supabase.fetchTrendAggregates(userId: userId, windowType: "monthly", limit: 1)
            if let m = monthlyResult.first,
               let agg = try? decodeAggregate(from: m) {
                aggregateCache["monthly_latest"] = [agg]
            }
        } catch {
            print("[TrendViewModel] monthly fetch failed: \(error)")
        }

        buildMetricTiles()
        await switchWindow(to: .sevenDay, userId: userId)
    }

    // ── Window switch ────────────────────────────────────────────────
    func switchWindow(to window: TrendWindow, userId: String) async {
        selectedWindow = window
        selectedMetricKey = "chronos"   // reset metric selection on window change
        loadError = nil

        switch window {
        case .sevenDay:
            load7DWindow()
        case .eightWeek:
            await loadAggregateWindow(userId: userId, windowType: "weekly", limit: 8)
        case .twelveMonth:
            await loadAggregateWindow(userId: userId, windowType: "monthly", limit: 12)
        }

        await loadNarrative(for: window, userId: userId)
        computeCallouts(for: window)
    }

    // ── 7D window ────────────────────────────────────────────────────
    private func load7DWindow() {
        let rows = dailyScoresCache
        isBuilding = rows.count < TrendWindow.sevenDay.buildingThreshold
        buildingLabel = TrendWindow.sevenDay.buildingLabel

        chartPoints = rows.compactMap { row -> TrendChartPoint? in
            guard let date = row["date"] as? String,
                  let score = row["chronos_score"] as? Double else { return nil }
            return TrendChartPoint(date: date, value: score, metricKey: "chronos")
        }
    }

    // ── 8W / 12M aggregate windows ──────────────────────────────────
    private func loadAggregateWindow(userId: String, windowType: String, limit: Int) async {
        guard let supabase else { return }

        // Use cache if available
        if let cached = aggregateCache[windowType], !cached.isEmpty {
            applyAggregates(cached, windowType: windowType, limit: limit)
            return
        }

        do {
            let rows = try await supabase.fetchTrendAggregates(userId: userId, windowType: windowType, limit: limit)
            let aggregates = rows.compactMap { try? decodeAggregate(from: $0) }
            aggregateCache[windowType] = aggregates
            applyAggregates(aggregates, windowType: windowType, limit: limit)
        } catch {
            loadError = "Could not load \(windowType) data."
            print("[TrendViewModel] aggregate load failed: \(error)")
        }
    }

    private func applyAggregates(_ aggregates: [TrendAggregate], windowType: String, limit: Int) {
        let threshold = windowType == "weekly"
            ? TrendWindow.eightWeek.buildingThreshold
            : TrendWindow.twelveMonth.buildingThreshold

        isBuilding = aggregates.count < threshold
        buildingLabel = windowType == "weekly"
            ? TrendWindow.eightWeek.buildingLabel
            : TrendWindow.twelveMonth.buildingLabel

        chartPoints = aggregates.compactMap { agg -> TrendChartPoint? in
            guard let avg = agg.chronosAvg else { return nil }
            return TrendChartPoint(date: agg.windowStart, value: avg, metricKey: "chronos")
        }
    }

    // ── Metric selector filter ────────────────────────────────────────
    func selectMetric(_ key: String) {
        selectedMetricKey = key

        if key == "chronos" {
            // Restore composite chart for current window
            switch selectedWindow {
            case .sevenDay:
                load7DWindow()
            case .eightWeek:
                if let cached = aggregateCache["weekly"] {
                    applyAggregates(cached, windowType: "weekly", limit: 8)
                }
            case .twelveMonth:
                if let cached = aggregateCache["monthly"] {
                    applyAggregates(cached, windowType: "monthly", limit: 12)
                }
            }
            return
        }

        // Per-metric chart data
        switch selectedWindow {
        case .sevenDay:
            chartPoints = dailyInputsCache.compactMap { row -> TrendChartPoint? in
                guard let date = row["date"] as? String else { return nil }
                let value = metricValue(from: row, key: key)
                guard let v = value else { return nil }
                return TrendChartPoint(date: date, value: v, metricKey: key)
            }

        case .eightWeek:
            if let cached = aggregateCache["weekly"] {
                chartPoints = cached.compactMap { agg -> TrendChartPoint? in
                    guard let v = agg.avg(for: key) else { return nil }
                    return TrendChartPoint(date: agg.windowStart, value: v, metricKey: key)
                }
            }

        case .twelveMonth:
            if let cached = aggregateCache["monthly"] {
                chartPoints = cached.compactMap { agg -> TrendChartPoint? in
                    guard let v = agg.avg(for: key) else { return nil }
                    return TrendChartPoint(date: agg.windowStart, value: v, metricKey: key)
                }
            }
        }
    }

    // ── Narrative ────────────────────────────────────────────────────
    private func loadNarrative(for window: TrendWindow, userId: String) async {
        guard let supabase else { return }
        let cacheKey = window.apiKey

        // Serve from cache if available — do not regenerate on tab switch
        if let cached = narrativeCache[cacheKey], !cached.isEmpty {
            narrativeText = cached
            return
        }

        isLoadingNarrative = true
        defer { isLoadingNarrative = false }

        // Build inputs from available data
        let (avg, min, max, direction, drivers) = narrativeInputs(for: window)

        guard avg > 0 else {
            narrativeText = ""
            return
        }

        let windowStart: String
        let windowEnd: String
        let daysInWindow: Int
        let today = todayString()

        switch window {
        case .sevenDay:
            let startDate = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
            windowStart = formatDate(startDate)
            windowEnd = today
            daysInWindow = dailyScoresCache.count

        case .eightWeek:
            let aggs = aggregateCache["weekly"] ?? []
            windowStart = aggs.first?.windowStart ?? ""
            windowEnd = aggs.last?.windowEnd ?? today
            daysInWindow = aggs.reduce(0) { $0 + $1.daysInWindow }

        case .twelveMonth:
            let aggs = aggregateCache["monthly"] ?? []
            windowStart = aggs.first?.windowStart ?? ""
            windowEnd = aggs.last?.windowEnd ?? today
            daysInWindow = aggs.reduce(0) { $0 + $1.daysInWindow }
        }

        do {
            let text = try await supabase.fetchTrendNarrative(
                userId: userId,
                windowType: window.apiKey,
                windowStart: windowStart,
                windowEnd: windowEnd,
                chronosAvg: avg,
                chronosMin: min,
                chronosMax: max,
                trendDirection: direction,
                topDrivers: drivers,
                daysInWindow: daysInWindow
            )
            narrativeCache[cacheKey] = text
            narrativeText = text
        } catch {
            narrativeText = ""
            print("[TrendViewModel] narrative fetch failed: \(error)")
        }
    }

    // ── Metric tiles ─────────────────────────────────────────────────
    private func buildMetricTiles() {
        let todayRow = dailyInputsCache.last
        let monthlyLatest = aggregateCache["monthly_latest"]?.first

        // Chronos tile — always first
        let chronosScores = dailyScoresCache.compactMap { $0["chronos_score"] as? Double }
        let chronos7DAvg = chronosScores.isEmpty ? nil : chronosScores.reduce(0, +) / Double(chronosScores.count)
        let chronos30DAvg = monthlyLatest?.chronosAvg

        var tiles: [MetricTileData] = [
            MetricTileData(
                id: "chronos",
                displayName: "Chronos",
                shortName: "Chronos",
                todayValue: chronosScores.last,
                sevenDayAvg: chronos7DAvg,
                thirtyDayAvg: chronos30DAvg,
                unit: ""
            )
        ]

        // Per-metric tiles — only show if data exists
        let metricDefs: [(key: String, name: String, short: String, unit: String, inputKey: String)] = [
            ("hrv",               "HRV",          "HRV",        "ms",  "hrv_ms"),
            ("resting_hr",        "Resting HR",   "HR",         "bpm", "resting_hr_bpm"),
            ("respiratory_rate",  "Resp. Rate",   "Resp",       "rpm", "respiratory_rate_rpm"),
            ("sleep_duration",    "Sleep",        "Sleep",      "hrs", "sleep_duration_hrs"),
            ("sleep_efficiency",  "Sleep Quality","Quality",    "%",   "sleep_efficiency_pct"),
            ("steps",             "Steps",        "Steps",      "",    "steps"),
            ("active_minutes",    "Active Min",   "Active",     "min", "active_minutes"),
        ]

        let sevenDayInputValues: [String: [Double]] = metricDefs.reduce(into: [:]) { acc, def in
            let vals = dailyInputsCache.compactMap { row -> Double? in
                metricValue(from: row, key: def.key)
            }
            if !vals.isEmpty { acc[def.key] = vals }
        }

        for def in metricDefs {
            guard let vals = sevenDayInputValues[def.key], !vals.isEmpty else { continue }
            let todayVal = todayRow.flatMap { metricValue(from: $0, key: def.key) }
            let avg7D = vals.reduce(0, +) / Double(vals.count)
            let avg30D = monthlyLatest?.avg(for: def.key)

            tiles.append(MetricTileData(
                id: def.key,
                displayName: def.name,
                shortName: def.short,
                todayValue: todayVal,
                sevenDayAvg: avg7D,
                thirtyDayAvg: avg30D,
                unit: def.unit
            ))
        }

        metricTiles = tiles
    }

    // ── Signal callouts (deterministic) ─────────────────────────────
    private func computeCallouts(for window: TrendWindow) {
        var working: [TrendCallout] = []
        var watching: [TrendCallout] = []

        switch window {
        case .sevenDay:
            compute7DCallouts(working: &working, watching: &watching)
        case .eightWeek:
            computeAggregateCallouts(aggs: aggregateCache["weekly"] ?? [],
                                     prevAggs: nil,
                                     working: &working, watching: &watching)
        case .twelveMonth:
            computeAggregateCallouts(aggs: aggregateCache["monthly"] ?? [],
                                     prevAggs: nil,
                                     working: &working, watching: &watching)
        }

        workingCallouts = Array(working.prefix(3))
        watchCallouts   = Array(watching.prefix(3))
    }

    private func compute7DCallouts(working: inout [TrendCallout], watching: inout [TrendCallout]) {
        let scores = dailyScoresCache.compactMap { $0["chronos_score"] as? Double }
        guard scores.count >= 7 else { return }

        let avg = scores.reduce(0, +) / Double(scores.count)

        // Best day
        if let maxScore = scores.max(),
           let maxIdx = scores.firstIndex(of: maxScore) {
            let dayRow = dailyScoresCache[maxIdx]
            let dayLabel = shortDayLabel(from: dayRow["date"] as? String ?? "")
            working.append(TrendCallout(category: .workingForYou,
                text: "Best day: \(dayLabel) at \(Int(maxScore))"))
        }

        // Consistency: fewer than 2 days more than 10 pts below average
        let deviationFlags = scores.filter { abs($0 - avg) > 10 && $0 < avg }.count
        if deviationFlags < 2 {
            let aboveCount = scores.filter { $0 >= avg }.count
            working.append(TrendCallout(category: .workingForYou,
                text: "\(aboveCount) of 7 days at or above your baseline"))
        }

        // Score range
        if let maxS = scores.max(), let minS = scores.min() {
            let range = maxS - minS
            if range > 20 {
                watching.append(TrendCallout(category: .worthWatching,
                    text: "Score ranged \(Int(range)) points this week"))
            }
        }

        // Per-metric deviation — use daily inputs
        let metricKeys = ["hrv", "resting_hr", "sleep_duration", "sleep_efficiency", "steps"]
        for key in metricKeys {
            let vals = dailyInputsCache.compactMap { metricValue(from: $0, key: key) }
            guard vals.count >= 4 else { continue }
            let metricAvg = vals.reduce(0, +) / Double(vals.count)
            guard metricAvg > 0 else { continue }
            let first3Avg = vals.prefix(3).reduce(0, +) / 3.0
            let last3Avg  = vals.suffix(3).reduce(0, +) / 3.0
            let changePct = ((last3Avg - first3Avg) / metricAvg) * 100

            let label = metricDisplayName(for: key)
            if changePct > 10 {
                let higherIsBad = ["resting_hr", "respiratory_rate"]
                if higherIsBad.contains(key) {
                    watching.append(TrendCallout(category: .worthWatching,
                        text: "\(label) up \(Int(changePct))% from earlier this week"))
                } else {
                    working.append(TrendCallout(category: .workingForYou,
                        text: "\(label) up \(Int(changePct))% from earlier this week"))
                }
            } else if changePct < -10 {
                let higherIsBad = ["resting_hr", "respiratory_rate"]
                if higherIsBad.contains(key) {
                    working.append(TrendCallout(category: .workingForYou,
                        text: "\(label) down \(Int(abs(changePct)))% from earlier this week"))
                } else {
                    watching.append(TrendCallout(category: .worthWatching,
                        text: "\(label) down \(Int(abs(changePct)))% from earlier this week"))
                }
            }
        }
    }

    private func computeAggregateCallouts(
        aggs: [TrendAggregate],
        prevAggs: [TrendAggregate]?,
        working: inout [TrendCallout],
        watching: inout [TrendCallout]
    ) {
        guard aggs.count >= 2 else { return }

        let chronosVals = aggs.compactMap { $0.chronosAvg }
        guard !chronosVals.isEmpty else { return }

        // Trend direction
        if let direction = aggs.last?.trendDirection {
            switch direction {
            case "improving":
                working.append(TrendCallout(category: .workingForYou,
                    text: "Chronos trend is improving across this window"))
            case "declining":
                // Check if it is 2+ consecutive declining windows
                let decliningCount = aggs.suffix(3).filter { $0.trendDirection == "declining" }.count
                if decliningCount >= 2 {
                    watching.append(TrendCallout(category: .worthWatching,
                        text: "\(decliningCount)-window declining trend in Chronos"))
                } else {
                    watching.append(TrendCallout(category: .worthWatching,
                        text: "Chronos trend declined this window"))
                }
            default: break
            }
        }
        
        // Score variability — fires regardless of direction
        if let hi = chronosVals.max(), let lo = chronosVals.min(), (hi - lo) > 10 {
            watching.append(TrendCallout(category: .worthWatching,
                text: "Score range of \(Int(hi - lo)) points across this window"))
        }

        // Most improved metric vs prior half of window
        let halfIdx = aggs.count / 2
        let firstHalf = Array(aggs.prefix(halfIdx))
        let secondHalf = Array(aggs.suffix(aggs.count - halfIdx))

        let metricKeys = ["hrv", "resting_hr", "sleep_duration", "sleep_efficiency", "steps"]
        for key in metricKeys {
            let firstAvgs = firstHalf.compactMap { $0.avg(for: key) }
            let secondAvgs = secondHalf.compactMap { $0.avg(for: key) }
            guard !firstAvgs.isEmpty, !secondAvgs.isEmpty else { continue }

            let firstMean = firstAvgs.reduce(0, +) / Double(firstAvgs.count)
            let secondMean = secondAvgs.reduce(0, +) / Double(secondAvgs.count)
            guard firstMean > 0 else { continue }

            let changePct = ((secondMean - firstMean) / firstMean) * 100
            let label = metricDisplayName(for: key)
            let higherIsBad = ["resting_hr", "respiratory_rate"]

            if changePct > 10 {
                if higherIsBad.contains(key) {
                    watching.append(TrendCallout(category: .worthWatching,
                        text: "\(label) up \(Int(changePct))% in the second half of this window"))
                } else {
                    working.append(TrendCallout(category: .workingForYou,
                        text: "\(label) up \(Int(changePct))% in the second half of this window"))
                }
            } else if changePct < -10 {
                if higherIsBad.contains(key) {
                    working.append(TrendCallout(category: .workingForYou,
                        text: "\(label) down \(Int(abs(changePct)))% in the second half of this window"))
                } else {
                    watching.append(TrendCallout(category: .worthWatching,
                        text: "\(label) down \(Int(abs(changePct)))% in the second half of this window"))
                }
            }
        }
    }

    // ── Narrative inputs helper ──────────────────────────────────────
    private func narrativeInputs(for window: TrendWindow) -> (avg: Double, min: Double, max: Double, direction: String, drivers: [String]) {
        switch window {
        case .sevenDay:
            let scores = dailyScoresCache.compactMap { $0["chronos_score"] as? Double }
            guard !scores.isEmpty else { return (0, 0, 0, "stable", []) }
            let avg = scores.reduce(0, +) / Double(scores.count)
            let minS = scores.min() ?? 0
            let maxS = scores.max() ?? 0
            let trend = (scores.last ?? 0) - (scores.first ?? 0)
            let direction = trend > 5 ? "improving" : trend < -5 ? "declining" : "stable"
            // Top drivers by frequency
            var driverFreq: [String: Int] = [:]
            for row in dailyScoresCache {
                if let d1 = row["driver_1"] as? String { driverFreq[d1, default: 0] += 1 }
                if let d2 = row["driver_2"] as? String { driverFreq[d2, default: 0] += 1 }
            }
            let topDrivers = driverFreq.sorted { $0.value > $1.value }.prefix(2).map { $0.key }
            return (avg, minS, maxS, direction, Array(topDrivers))

        case .eightWeek:
            let aggs = aggregateCache["weekly"] ?? []
            return aggregateNarrativeInputs(aggs)

        case .twelveMonth:
            let aggs = aggregateCache["monthly"] ?? []
            return aggregateNarrativeInputs(aggs)
        }
    }

    private func aggregateNarrativeInputs(_ aggs: [TrendAggregate]) -> (avg: Double, min: Double, max: Double, direction: String, drivers: [String]) {
        let vals = aggs.compactMap { $0.chronosAvg }
        guard !vals.isEmpty else { return (0, 0, 0, "stable", []) }
        let avg = vals.reduce(0, +) / Double(vals.count)
        let minV = vals.min() ?? 0
        let maxV = vals.max() ?? 0
        let direction = aggs.last?.trendDirection ?? "stable"
        var driverFreq: [String: Int] = [:]
        for agg in aggs {
            if let d = agg.topDriver1 { driverFreq[d, default: 0] += 1 }
            if let d = agg.topDriver2 { driverFreq[d, default: 0] += 1 }
        }
        let topDrivers = driverFreq.sorted { $0.value > $1.value }.prefix(2).map { $0.key }
        return (avg, minV, maxV, direction, Array(topDrivers))
    }

    // ── Helpers ──────────────────────────────────────────────────────
    private func metricValue(from row: [String: Any], key: String) -> Double? {
        let inputKey: String
        switch key {
        case "hrv":              inputKey = "hrv_ms"
        case "resting_hr":       inputKey = "resting_hr_bpm"
        case "respiratory_rate": inputKey = "respiratory_rate_rpm"
        case "sleep_duration":   inputKey = "sleep_duration_hrs"
        case "sleep_efficiency": inputKey = "sleep_efficiency_pct"
        case "steps":            inputKey = "steps"
        case "active_minutes":   inputKey = "active_minutes"
        default: return nil
        }
        if let v = row[inputKey] as? Double { return v }
        if let v = row[inputKey] as? Int { return Double(v) }
        return nil
    }

    private func metricDisplayName(for key: String) -> String {
        switch key {
        case "hrv":               return "HRV"
        case "resting_hr":        return "Resting HR"
        case "respiratory_rate":  return "Resp. rate"
        case "sleep_duration":    return "Sleep duration"
        case "sleep_efficiency":  return "Sleep quality"
        case "steps":             return "Steps"
        case "active_minutes":    return "Active minutes"
        default:                  return key
        }
    }

    private func shortDayLabel(from dateString: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateString) else { return "" }
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    private func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func decodeAggregate(from dict: [String: Any]) throws -> TrendAggregate {
        let data = try JSONSerialization.data(withJSONObject: dict)
        return try JSONDecoder().decode(TrendAggregate.self, from: data)
    }

    // Stat line for narrative block
    var statLine: String {
        let scores: [Double]
        switch selectedWindow {
        case .sevenDay:
            scores = dailyScoresCache.compactMap { $0["chronos_score"] as? Double }
        case .eightWeek:
            scores = (aggregateCache["weekly"] ?? []).compactMap { $0.chronosAvg }
        case .twelveMonth:
            scores = (aggregateCache["monthly"] ?? []).compactMap { $0.chronosAvg }
        }
        guard !scores.isEmpty else { return "" }
        let avg = scores.reduce(0, +) / Double(scores.count)
        let trend = (scores.last ?? 0) - (scores.first ?? 0)
        let direction = trend > 5 ? "improving" : trend < -5 ? "declining" : "stable"
        let windowLabel: String
        switch selectedWindow {
        case .sevenDay:    windowLabel = "7-day"
        case .eightWeek:   windowLabel = "8-week"
        case .twelveMonth: windowLabel = "12-month"
        }
        return "\(windowLabel) average \(Int(avg)) · \(direction)"
    }
}

// ─────────────────────────────────────────
// TREND CHART POINT
// Unified point model for TrendLineChart across all windows and metrics.
// ─────────────────────────────────────────
struct TrendChartPoint: Identifiable {
    let id = UUID()
    let date: String
    let value: Double
    let metricKey: String
}

// ─────────────────────────────────────────
// TREND VIEW
// ─────────────────────────────────────────

struct TrendView: View {
    @EnvironmentObject var sync: SyncCoordinator
    @EnvironmentObject var supabase: SupabaseService
    @StateObject private var vm = TrendViewModel()

    var body: some View {
        ZStack {
            ChronosTheme.ink.ignoresSafeArea()

            RadialGradient(
                colors: [ChronosTheme.gold.opacity(0.04), .clear],
                center: .top, startRadius: 0, endRadius: 320
            )
            .ignoresSafeArea()

            if let _ = sync.dashboard {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Header ───────────────────────────────
                        TrendHeaderView(window: vm.selectedWindow)

                        // ── Window toggle ────────────────────────
                        WindowToggle(selectedWindow: $vm.selectedWindow) { newWindow in
                            guard let userId = supabase.session?.userId else { return }
                            Task { await vm.switchWindow(to: newWindow, userId: userId) }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                        // ── Line chart ───────────────────────────
                        TrendLineChart(
                            points: vm.chartPoints,
                            window: vm.selectedWindow,
                            selectedMetricKey: vm.selectedMetricKey,
                            scoreBand: sync.dashboard?.score.scoreBand ?? .recovering,
                            isBuilding: vm.isBuilding,
                            buildingLabel: vm.buildingLabel
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                        // ── Narrative block ──────────────────────
                        if vm.isLoadingNarrative {
                            NarrativeLoadingCard()
                                .padding(.horizontal, 20).padding(.bottom, 16)
                        } else if !vm.narrativeText.isEmpty {
                            TrendNarrativeCard(
                                window: vm.selectedWindow,
                                narrativeText: vm.narrativeText,
                                statLine: vm.statLine
                            )
                            .padding(.horizontal, 20).padding(.bottom, 16)
                        }

                        // ── Metric selector ──────────────────────
                        if !vm.metricTiles.isEmpty {
                            MetricSelectorGrid(
                                tiles: vm.metricTiles,
                                selectedKey: vm.selectedMetricKey
                            ) { key in
                                vm.selectMetric(key)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }

                        // ── Signal callouts ──────────────────────
                        let hasCallouts = !vm.workingCallouts.isEmpty || !vm.watchCallouts.isEmpty
                        if hasCallouts {
                            SignalCallouts(
                                working: vm.workingCallouts,
                                watching: vm.watchCallouts
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }

                        // Placeholder only if fewer than 7 days of history
                        if !hasCallouts && (sync.dashboard?.recentScores.count ?? 0) < 7 {
                            TrendSignalPlaceholder()
                                .padding(.horizontal, 20).padding(.bottom, 40)
                        }
                    }
                }
            } else {
                TrendEmptyView().padding(.top, 60)
            }
        }
        .task {
            guard let userId = supabase.session?.userId else { return }
            vm.attach(supabase: supabase)
            await vm.initialLoad(userId: userId)
        }
    }
}

// ─────────────────────────────────────────
// HEADER — window adaptive
// ─────────────────────────────────────────

struct TrendHeaderView: View {
    let window: TrendWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(window.headerEyebrow)
                .font(.jost(size: 10, weight: .light))
                .foregroundColor(ChronosTheme.gold)
                .tracking(3)

            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(window.headerTitle)
                    .font(.cormorant(size: 32, weight: .light))
                    .foregroundColor(ChronosTheme.text)
                Text(" ")
                Text(window.headerSubtitle)
                    .font(.cormorantItalic(size: 16))
                    .foregroundColor(ChronosTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .animation(.easeInOut(duration: 0.2), value: window)
    }
}

// ─────────────────────────────────────────
// WINDOW TOGGLE — 3-segment pill
// ─────────────────────────────────────────

struct WindowToggle: View {
    @Binding var selectedWindow: TrendWindow
    var onSelect: (TrendWindow) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TrendWindow.allCases, id: \.self) { window in
                Button {
                    guard window != selectedWindow else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedWindow = window
                    }
                    onSelect(window)
                } label: {
                    Text(window.rawValue)
                        .font(.jost(size: 12, weight: selectedWindow == window ? .medium : .light))
                        .foregroundColor(selectedWindow == window ? ChronosTheme.ink : ChronosTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedWindow == window ? ChronosTheme.gold : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ChronosTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(ChronosTheme.border, lineWidth: 1))
        )
    }
}

// ─────────────────────────────────────────
// TREND LINE CHART
// Replaces ScoreRibbon bar chart across all three windows.
// ─────────────────────────────────────────

struct TrendLineChart: View {
    let points: [TrendChartPoint]
    let window: TrendWindow
    let selectedMetricKey: String
    let scoreBand: ScoreBand
    let isBuilding: Bool
    let buildingLabel: String

    private var lineColor: Color {
        switch scoreBand {
        case .thriving:   return Color(red: 0.35, green: 0.80, blue: 0.45)
        case .recovering: return ChronosTheme.gold
        case .yellowline: return Color(red: 0.95, green: 0.80, blue: 0.30)
        case .drifting:   return Color(red: 0.90, green: 0.55, blue: 0.30)
        case .redline:    return Color(red: 0.85, green: 0.30, blue: 0.30)
        }
    }
    private var windowAvg: Double {
        guard !points.isEmpty else { return 0 }
        return points.map { $0.value }.reduce(0, +) / Double(points.count)
    }

    private var yRange: ClosedRange<Double> {
        guard !points.isEmpty else { return 0...100 }
        let vals = points.map { $0.value }
        let minV = (vals.min() ?? 0) - 5
        let maxV = (vals.max() ?? 100) + 5
        return max(0, minV)...max(minV + 10, maxV)
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

            // Top gold line
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
                // Window label
                Text(window.dateLabel)
                    .font(.jost(size: 9, weight: .light))
                    .foregroundColor(ChronosTheme.muted)
                    .tracking(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // HIGH / AVG / LOW — shown when data exists
                if !points.isEmpty {
                    HStack(spacing: 0) {
                        if let hi = points.map({ $0.value }).max() {
                            VStack(spacing: 2) {
                                Text("HIGH").font(.jost(size: 7, weight: .light)).foregroundColor(ChronosTheme.faint).tracking(1.5)
                                Text("\(Int(hi))").font(.jost(size: 14, weight: .medium)).foregroundColor(lineColor)
                            }
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text("AVG").font(.jost(size: 7, weight: .light)).foregroundColor(ChronosTheme.faint).tracking(1.5)
                            Text("\(Int(windowAvg))").font(.jost(size: 14, weight: .medium)).foregroundColor(ChronosTheme.muted)
                        }
                        Spacer()
                        if let lo = points.map({ $0.value }).min() {
                            VStack(spacing: 2) {
                                Text("LOW").font(.jost(size: 7, weight: .light)).foregroundColor(ChronosTheme.faint).tracking(1.5)
                                Text("\(Int(lo))").font(.jost(size: 14, weight: .medium)).foregroundColor(ChronosTheme.faint)
                            }
                        }
                    }
                }

                // Chart — always shown when points exist or building
                if points.isEmpty && !isBuilding {
                    Spacer().frame(height: 100)
                } else {
                    Chart {
                        if windowAvg > 0 {
                            RuleMark(y: .value("Average", windowAvg))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundStyle(Color.white.opacity(0.20))
                        }
                        ForEach(Array(points.enumerated()), id: \.offset) { i, point in
                            LineMark(x: .value("Date", i), y: .value("Score", point.value))
                                .foregroundStyle(lineColor)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date", i), y: .value("Score", point.value))
                                .foregroundStyle(lineColor)
                                .symbolSize(i == points.count - 1 ? 60 : 30)
                        }
                    }
                    .chartYScale(domain: yRange)
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisValueLabel {
                                if let idx = value.as(Int.self), idx < points.count {
                                    Text(xAxisLabel(for: idx, total: points.count))
                                        .font(.jost(size: 8, weight: idx == points.count - 1 ? .medium : .light))
                                        .foregroundStyle(idx == points.count - 1 ? ChronosTheme.gold : ChronosTheme.muted)
                                }
                            }
                        }
                    }
                    .chartYAxis(.hidden)
                    .frame(height: 100)
                    .allowsHitTesting(false)
                }

                // Building state label
                if isBuilding {
                    Text(buildingLabel)
                        .font(.jost(size: 10, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(20)
        }
        .frame(height: isBuilding ? 160 : 220)
        .animation(.easeInOut(duration: 0.25), value: points.map { $0.id })
    }

    private func xAxisLabel(for index: Int, total: Int) -> String {
        guard index < points.count else { return "" }
        let dateString = points[index].date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return "" }

        switch window {
        case .sevenDay:
            formatter.dateFormat = "E"
            return String(formatter.string(from: date).prefix(1)).uppercased()
        case .eightWeek:
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        case .twelveMonth:
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }
    }
}

// ─────────────────────────────────────────
// TREND NARRATIVE CARD — window synthesis
// Replaces WeeklyNarrativeCard (which showed today's explanation).
// ─────────────────────────────────────────

struct TrendNarrativeCard: View {
    let window: TrendWindow
    let narrativeText: String
    let statLine: String

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
                // Dynamic date label
                Text(window.dateLabel)
                    .font(.jost(size: 9, weight: .light))
                    .foregroundColor(ChronosTheme.gold)
                    .tracking(3)
                    .textCase(.uppercase)

                Rectangle().fill(ChronosTheme.gold.opacity(0.2)).frame(height: 1)

                // Window synthesis — generated by Claude API, not today's explanation
                Text(narrativeText)
                    .font(.jost(size: 14, weight: .light))
                    .foregroundColor(Color(red: 0.965, green: 0.953, blue: 0.920))
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)

                // Stat line
                if !statLine.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(ChronosTheme.gold)
                            .frame(width: 5, height: 5)
                            .padding(.top, 4)
                        Text(statLine)
                            .font(.jost(size: 11, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .italic()
                            .lineSpacing(4)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .animation(.easeInOut(duration: 0.2), value: window)
    }
}

// Loading state for narrative while Claude API call is in-flight
struct NarrativeLoadingCard: View {
    @State private var opacity: Double = 0.4

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(ChronosTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(ChronosTheme.border, lineWidth: 1))

            Text("Reading the pattern...")
                .font(.jost(size: 13, weight: .light))
                .foregroundColor(ChronosTheme.muted.opacity(opacity))
                .italic()
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                        opacity = 1.0
                    }
                }
        }
        .frame(height: 72)
    }
}

// ─────────────────────────────────────────
// METRIC SELECTOR BANNER
// Horizontally scrolling tile row.
// Chronos always first. Data-driven — no hardcoded list.
// Narrative does NOT update when a metric tile is selected.
// ─────────────────────────────────────────

struct MetricSelectorGrid: View {
    let tiles: [MetricTileData]
    let selectedKey: String
    var onSelect: (String) -> Void
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(tiles) { tile in
                MetricTileView(tile: tile, isSelected: selectedKey == tile.id) {
                    onSelect(tile.id)
                }
            }
        }
    }
}

struct MetricTileView: View {
    let tile: MetricTileData
    let isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Metric name
                Text(tile.shortName)
                    .font(.jost(size: 11, weight: .medium))
                    .foregroundColor(ChronosTheme.text)

                // Three-number summary header
                HStack(spacing: 0) {
                    tileColumn(label: "Today", value: tile.todayValue, unit: tile.unit)
                    Spacer()
                    tileColumn(label: "7D", value: tile.sevenDayAvg, unit: tile.unit)
                    Spacer()
                    tileColumn(label: "30D", value: tile.thirtyDayAvg, unit: tile.unit)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(ChronosTheme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected ? ChronosTheme.gold : ChronosTheme.border,
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
            .background(
                isSelected
                    ? RoundedRectangle(cornerRadius: 14).fill(ChronosTheme.gold.opacity(0.06))
                    : nil
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    @ViewBuilder
    private func tileColumn(label: String, value: Double?, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.jost(size: 8, weight: .light))
                .foregroundColor(ChronosTheme.muted)
                .tracking(1)
            if let v = value {
                Text(formattedValue(v, unit: unit))
                    .font(.jost(size: 11, weight: .medium))
                    .foregroundColor(ChronosTheme.text)
            } else {
                Text("—")
                    .font(.jost(size: 11, weight: .light))
                    .foregroundColor(ChronosTheme.faint)
            }
        }
    }

    private func formattedValue(_ v: Double, unit: String) -> String {
        switch unit {
        case "ms":  return "\(Int(v))ms"
        case "bpm": return "\(Int(v))"
        case "rpm": return "\(Int(v))"
        case "hrs": return String(format: "%.1fh", v)
        case "%":   return "\(Int(v))%"
        case "min": return "\(Int(v))m"
        default:    return v >= 1000 ? "\(Int(v / 1000))k" : "\(Int(v))"
        }
    }
}

// ─────────────────────────────────────────
// SIGNAL CALLOUTS — deterministic, two-section
// Computed by TrendViewModel — Claude does not generate these.
// If no callout conditions are met, the section is absent entirely.
// ─────────────────────────────────────────

struct SignalCallouts: View {
    let working: [TrendCallout]
    let watching: [TrendCallout]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !working.isEmpty {
                calloutSection(
                    title: "WORKING FOR YOU",
                    callouts: working,
                    accentColor: Color(red: 0.35, green: 0.80, blue: 0.45)
                )
            }
            if !watching.isEmpty {
                calloutSection(
                    title: "WORTH WATCHING",
                    callouts: watching,
                    accentColor: Color(red: 0.90, green: 0.65, blue: 0.30)
                )
            }
        }
    }

    @ViewBuilder
    private func calloutSection(title: String, callouts: [TrendCallout], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.jost(size: 9, weight: .light))
                .foregroundColor(accentColor.opacity(0.8))
                .tracking(2.5)

            ForEach(callouts) { callout in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 5, height: 5)
                        .padding(.top, 5)

                    Text(callout.text)
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(ChronosTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentColor.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// ─────────────────────────────────────────
// TREND SIGNAL PLACEHOLDER
// Only shown when user has fewer than 7 days of history.
// Retired after 7 days — never shown as a permanent state.
// ─────────────────────────────────────────

struct TrendSignalPlaceholder: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
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
// EMPTY STATE — no dashboard data at all
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
