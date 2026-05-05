// ios/MBI/MBI/Views/DashboardView.swift
// MBI Phase 1.5 — Dashboard · Morning Brief
// Epic 1 Sprint 1 — Dashboard Redesign Build
// Changes:
//   §3.1  Header: time-aware greeting (sentence case, Large Title), date line added, first name only
//   §3.2  Score card: date removed, sparkline redesigned (state-colored, high/low labels, dashed baseline)
//   §3.3  Driver chips: value and signal word on separate lines, direction-aware signal color
//   §3.4  Driver detail: deviation data passed as navigation params (consumed in IntelligenceCardView)

import SwiftUI

// ─────────────────────────────────────────
// TIME OF DAY  — single source of truth
// Handoff §3.1: 12AM–11:59AM morning, 12PM–4:30PM afternoon, 4:31PM+ evening
// ─────────────────────────────────────────

enum TimeOfDay: String {
    case morning  = "morning"
    case daytime  = "daytime"
    case evening  = "evening"

    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        let minute = Calendar.current.component(.minute, from: Date())
        if hour < 12 { return .morning }
        // 4:31 PM cutoff = hour 16 minute 31+, or hour 17+
        if hour < 16 { return .daytime }
        if hour == 16 && minute <= 30 { return .daytime }
        return .evening
    }

    // §3.1: Sentence case — "Good morning", not "GOOD MORNING"
    var greeting: String {
        switch self {
        case .morning:  return "Good morning"
        case .daytime:  return "Good afternoon"
        case .evening:  return "Good evening"
        }
    }

    var label: String { rawValue }
}

// ─────────────────────────────────────────
// MAIN TAB
// ─────────────────────────────────────────

struct MainTabView: View {
    @EnvironmentObject var supabase: SupabaseService
    @EnvironmentObject var sync: SyncCoordinator
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Today", systemImage: "sun.horizon") }
                .tag(0)

            TrendView()
                .tabItem { Label("Trend", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(1)

            DomainBreakdownView()
                .tabItem { Label("Domains", systemImage: "hexagon") }
                .tag(2)

            HorizonModuleView()
                .environmentObject(sync)
                .environmentObject(supabase)
                .tabItem { Label("Horizon", systemImage: "scope") }
                .tag(3)
        }
        .accentColor(ChronosTheme.gold)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1)

            let mutedColor = UIColor(red: 0.965, green: 0.953, blue: 0.933, alpha: 0.35)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: mutedColor]
            appearance.stackedLayoutAppearance.normal.iconColor = mutedColor

            let goldColor = UIColor(red: 0.722, green: 0.580, blue: 0.416, alpha: 1)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: goldColor]
            appearance.stackedLayoutAppearance.selected.iconColor = goldColor

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// ─────────────────────────────────────────
// DASHBOARD VIEW
// ─────────────────────────────────────────

struct DashboardView: View {
    @EnvironmentObject var sync: SyncCoordinator
    @EnvironmentObject var supabase: SupabaseService
    @State private var showFeedback = false
    @State private var showAccount = false

    // Intelligence cache — keyed by metric raw string.
    // Persists across sheet opens for the same driver.
    // Cleared when drivers change (new day brings new score).
    @State private var intelligenceCache: [String: IntelligenceContent] = [:]
    @State private var activeDriverTap: DriverTapContext? = nil

    // Track last known drivers to detect day change and clear cache
    @State private var lastKnownDriver1: String = ""
    @State private var lastKnownDriver2: String = ""

    var body: some View {
        ZStack {
            ChronosTheme.ink.ignoresSafeArea()

            RadialGradient(
                colors: [ChronosTheme.gold.opacity(0.05), .clear],
                center: .top, startRadius: 0, endRadius: 360
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // §3.1: Header now owns the greeting + date
                    MorningBriefHeader(
                        displayName: supabase.currentUser?.displayName ?? "",
                        syncState: sync.syncState,
                        onAccountTap: { showAccount = true }
                    )

                    if let data = sync.dashboard {

                        let failState = data.score.failState
                        // Sprint 1.5: Use computedBand for Yellowline detection.
                        // computedBand resolves client-side until backend emits "Yellowline" natively.
                        let band = data.computedBand

                        if failState == "Ghost-AtRisk" {
                            GhostAtRiskView(score: data.score) { }

                        } else if data.score.scoreBand == .redline {
                            RedlineDashboardView(
                                score: data.score,
                                explanation: data.explanation,
                                recentScores: data.recentScores
                            )
                            .environmentObject(supabase)

                        } else if band == .yellowline {
                            // Yellowline: normal layout, amber color theming via scoreBand override
                            // We pass a modified score view — same components, Yellowline tokens fire
                            // inside MorningScoreCard via scoreBand on the data model.
                            MorningScoreCard(
                                score: data.score,
                                recentScores: data.recentScores,
                                bandOverride: .yellowline
                            )
                            .padding(.horizontal, 20).padding(.bottom, 16)

                            DriverChipRow(
                                score: data.score,
                                onChipTap: { context in activeDriverTap = context }
                            )
                            .environmentObject(supabase)
                            .padding(.horizontal, 20).padding(.bottom, 16)

                            if let explanation = data.explanation {
                                LetterCard(score: data.score, explanation: explanation)
                                    .padding(.horizontal, 20).padding(.bottom, 16)

                                YellowlineNudgeCard(nudge: explanation.nudgeText)
                                    .padding(.horizontal, 20).padding(.bottom, 16)
                            }

                            FeedbackPromptCard(score: data.score) { showFeedback = true }
                                .padding(.horizontal, 20).padding(.bottom, 48)

                        } else {
                            // §3.2: Score card — date removed, sparkline redesigned
                            MorningScoreCard(score: data.score, recentScores: data.recentScores)
                                .padding(.horizontal, 20).padding(.bottom, 16)

                            // §3.3: Driver chips — value + signal word, direction-aware color
                            // §3.4: Deviation context passed through DriverTapContext
                            DriverChipRow(
                                score: data.score,
                                onChipTap: { context in
                                    activeDriverTap = context
                                }
                            )
                            .environmentObject(supabase)
                            .padding(.horizontal, 20).padding(.bottom, 16)

                            if let explanation = data.explanation {
                                LetterCard(score: data.score, explanation: explanation)
                                    .padding(.horizontal, 20).padding(.bottom, 16)

                                if failState == "Drift" {
                                    DriftNudgeCard(nudge: explanation.nudgeText)
                                        .padding(.horizontal, 20).padding(.bottom, 16)
                                } else {
                                    ChronosNudgeCard(nudge: explanation.nudgeText)
                                        .padding(.horizontal, 20).padding(.bottom, 16)
                                }
                            }

                            FeedbackPromptCard(score: data.score) { showFeedback = true }
                                .padding(.horizontal, 20).padding(.bottom, 48)
                        }

                    } else if case .syncing(let msg) = sync.syncState {
                        ChronosSyncingView(message: msg).padding(.top, 60)

                    } else if case .failed(let msg) = sync.syncState {
                        ChronosErrorView(message: msg) {
                            Task {
                                if let userId = supabase.session?.userId {
                                    if msg.contains("401") { await supabase.refreshSessionIfNeeded() }
                                    await sync.runDailySync(userId: userId)
                                }
                            }
                        }
                        .padding(.top, 60)

                    } else {
                        ChronosEmptyView().padding(.top, 60)
                    }
                }
            }
        }
        .sheet(isPresented: $showFeedback) {
            if let data = sync.dashboard { FeedbackView(score: data.score) }
        }
        .sheet(isPresented: $showAccount) {
            AccountView()
                .environmentObject(supabase)
                .environmentObject(sync)
        }
        // §3.4: Intelligence sheet now receives full deviation context
        .sheet(item: $activeDriverTap) { context in
            if let data = sync.dashboard {
                IntelligenceSheet(
                    metric: context.metric,
                    score: data.score,
                    driverContext: context,
                    cachedContent: $intelligenceCache
                )
            }
        }
        // iOS 17 two-parameter onChange — (oldValue, newValue)
        .onChange(of: sync.dashboard?.score.driver1) { _, newDriver in
            guard let driver = newDriver, driver != lastKnownDriver1 else { return }
            intelligenceCache.removeAll()
            lastKnownDriver1 = driver
            lastKnownDriver2 = sync.dashboard?.score.driver2 ?? ""
        }
    }
}

// ─────────────────────────────────────────
// DRIVER TAP CONTEXT
// §3.4: Carries deviation data from chip → detail screen.
// No new Supabase call from the detail screen.
// ─────────────────────────────────────────

struct DriverTapContext: Identifiable {
    let id: String           // metric raw string — used by sheet(item:)
    let metric: String
    let isDriver1: Bool      // true = "primary signal", false = "second-highest deviation"
    let todayValue: Double?
    let baselineValue: Double?
    let deviationDirection: DeviationDirection?
    let deviationMagnitudePct: Double?   // abs((today - baseline) / baseline) * 100
    let formattedTodayValue: String?     // pre-formatted for display (e.g. "23ms")
}

enum DeviationDirection {
    case above, below
}

// ─────────────────────────────────────────
// METRIC ID  — backwards compat for any remaining uses
// ─────────────────────────────────────────

struct MetricID: Identifiable {
    let id: String
}

// ─────────────────────────────────────────
// HEADER  §3.1
// Changes from prior:
//   - Greeting: sentence case, Large Title weight (cormorant 28 light → larger presence)
//   - First name only (trim at first space)
//   - Date line added below greeting: "Friday · April 25" format, muted subheadline
//   - Avatar height scales to match combined two-line text block
//   - Greeting no longer uppercased
// ─────────────────────────────────────────

struct MorningBriefHeader: View {
    let displayName: String
    let syncState: SyncState
    let onAccountTap: () -> Void

    /// §3.1: Use first word only if display_name contains a space
    var firstName: String {
        let name = displayName.isEmpty ? "—" : displayName
        return String(name.split(separator: " ").first ?? Substring(name))
    }

    /// §3.1: "Friday · April 25" — no year
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE · MMMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                // §3.1: Sentence case, warm presence — reduced 25% from 30pt per founder feedback
                Text("\(TimeOfDay.current.greeting), \(firstName)")
                    .font(.cormorant(size: 22, weight: .light))
                    .foregroundColor(ChronosTheme.text)

                // §3.1: Date line — subheadline weight, muted, directly below greeting
                Text(formattedDate)
                    .font(.jost(size: 13, weight: .light))
                    .foregroundColor(ChronosTheme.muted)
            }
            Spacer()
            HStack(spacing: 12) {
                SyncStatusBadge(state: syncState)
                // §3.1: Avatar scales to match combined two-line text block height.
                // The two lines are approx: 30pt cormorant + 2pt spacing + 13pt jost = ~45pt
                // Use a GeometryReader-free approach: fixed size that matches the block.
                Button(action: onAccountTap) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 32, weight: .ultraLight))
                        .foregroundColor(ChronosTheme.gold.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
}

// ─────────────────────────────────────────
// SCORE CARD  §3.2
// Changes from prior:
//   - formattedDate() block REMOVED — date now lives in header
//   - GoldSparkline replaced with ChronosSparkline (functional 7-day signal)
//   - Delta parenthetical already correct — preserved as-is
// ─────────────────────────────────────────

struct MorningScoreCard: View {
    let score: DailyScore
    let recentScores: [Double]
    // Sprint 1.5: Yellowline routing passes .yellowline here since Supabase
    // doesn't emit it yet. Nil = use score.scoreBand directly.
    var bandOverride: ScoreBand? = nil

    private var effectiveBand: ScoreBand { bandOverride ?? score.scoreBand }

    var bandTint: Color {
        switch effectiveBand {
        case .thriving:   return Color(red: 0.15, green: 0.35, blue: 0.20)
        case .recovering: return Color(red: 0.18, green: 0.20, blue: 0.36)
        case .yellowline: return Color(red: 0.38, green: 0.28, blue: 0.05)
        case .drifting:   return Color(red: 0.36, green: 0.28, blue: 0.10)
        case .redline:    return Color(red: 0.38, green: 0.12, blue: 0.12)
        }
    }

    var bandColor: Color {
        switch effectiveBand {
        case .thriving:   return Color(red: 0.50, green: 0.90, blue: 0.55)
        case .recovering: return ChronosTheme.goldLight
        case .yellowline: return Color(red: 1.0,  green: 0.72, blue: 0.20)
        case .drifting:   return Color(red: 1.0,  green: 0.80, blue: 0.30)
        case .redline:    return Color(red: 1.0,  green: 0.42, blue: 0.42)
        }
    }

    // §3.2: Sparkline line color matches card state
    var sparklineColor: Color { bandColor }

    var yesterdayScore: Double? {
        guard recentScores.count >= 2 else { return nil }
        return recentScores[recentScores.count - 2]
    }

    var deltaText: String? {
        guard let yesterday = yesterdayScore else { return nil }
        let diff = Int(score.chronosScore) - Int(yesterday)
        if diff == 0 { return "— no change from yesterday (\(Int(yesterday)))" }
        return "\(diff > 0 ? "↑" : "↓") \(abs(diff)) from yesterday (\(Int(yesterday)))"
    }

    var deltaColor: Color {
        guard let yesterday = yesterdayScore else { return ChronosTheme.muted }
        return score.chronosScore >= yesterday
            ? Color(red: 0.50, green: 0.90, blue: 0.55)
            : Color(red: 1.0, green: 0.55, blue: 0.55)
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 20)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.09, blue: 0.16).blended(with: bandTint, fraction: 0.35),
                        Color(red: 0.06, green: 0.06, blue: 0.10).blended(with: bandTint, fraction: 0.15)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing))

            VStack {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, ChronosTheme.gold, .clear],
                                        startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
                Spacer()
            }

            VStack(spacing: 0) {
                // §3.2: Date line REMOVED from here — it now lives in MorningBriefHeader.
                // No empty space left behind — VStack starts directly with score number.

                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("\(Int(score.chronosScore))")
                        .font(.cormorant(size: 96, weight: .light))
                        .foregroundColor(bandColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(effectiveBand.rawValue.uppercased())
                            .font(.jost(size: 11, weight: .medium))
                            .foregroundColor(bandColor).tracking(3)

                        if let delta = deltaText {
                            Text(delta)
                                .font(.jost(size: 11, weight: .light))
                                .foregroundColor(deltaColor)
                        }
                    }
                    .padding(.bottom, 10)
                }
                .padding(.top, 22).padding(.horizontal, 24)

                if score.isProvisional {
                    Text("BUILDING BASELINE")
                        .font(.jost(size: 9, weight: .light))
                        .foregroundColor(ChronosTheme.gold.opacity(0.6))
                        .tracking(2.5).padding(.top, 2).padding(.bottom, 6)
                }

                // §3.2: Functional sparkline — state-colored, high/low labels, dashed baseline
                if recentScores.count > 1 {
                    ChronosSparkline(scores: recentScores, lineColor: sparklineColor)
                        .frame(height: 52)
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                } else {
                    Spacer().frame(height: 20)
                }
            }
        }
    }
}

// ─────────────────────────────────────────
// CHRONOS SPARKLINE  §3.2
// Replaces GoldSparkline — now functional signal display.
//
// Spec:
//   - Line: 7-day Chronos score history, continuous
//   - Color: matches card state (passed in as lineColor)
//   - Today's endpoint: slightly larger dot to anchor current state
//   - High label: value at actual high point x-position, small, muted
//   - Low label: value at actual low point x-position, small, muted
//   - Baseline reference: faint horizontal dashed line at 7-day mean
//   - No Y-axis, no gridlines, no scale numbers, no X-axis labels
//   - NOT tappable — read-only contextual element
// ─────────────────────────────────────────

struct ChronosSparkline: View {
    let scores: [Double]
    let lineColor: Color

    // ── Computed properties kept outside body — avoids ViewBuilder inference errors ──

    private var baseline: Double {
        scores.isEmpty ? 0 : scores.reduce(0, +) / Double(scores.count)
    }

    private var highIndex: Int {
        scores.indices.max(by: { scores[$0] < scores[$1] }) ?? 0
    }

    private var lowIndex: Int {
        scores.indices.min(by: { scores[$0] < scores[$1] }) ?? 0
    }

    // Extract all geometry math into a helper — keeps GeometryReader body
    // to pure View expressions only, which resolves the ViewBuilder errors.
    private func layout(in size: CGSize) -> SparklineLayout {
        let w = size.width
        let h = size.height
        let labelPad: CGFloat = 24
        let drawW = w - labelPad * 2
        let count = scores.count

        let minS = (scores.min() ?? 0) - 8
        let maxS = (scores.max() ?? 100) + 8
        let range = max(maxS - minS, 1)   // guard divide-by-zero
        let step = count > 1 ? drawW / CGFloat(count - 1) : drawW

        let points: [CGPoint] = scores.indices.map { i in
            CGPoint(
                x: labelPad + CGFloat(i) * step,
                y: h - CGFloat((scores[i] - minS) / range) * h
            )
        }
        let baselineY = h - CGFloat((baseline - minS) / range) * h

        return SparklineLayout(
            width: w, height: h,
            points: points,
            baselineY: baselineY,
            baselineAvg: baseline,
            highIndex: highIndex,
            lowIndex: lowIndex
        )
    }

    var body: some View {
        GeometryReader { geo in
            SparklineCanvas(
                layout: layout(in: geo.size),
                scores: scores,
                lineColor: lineColor
            )
        }
        // §3.2: Sparkline is NOT tappable — no gesture, no affordance
        .allowsHitTesting(false)
    }
}

// Layout value type — all CGPoints pre-computed, passed cleanly into the canvas view
private struct SparklineLayout {
    let width: CGFloat
    let height: CGFloat
    let points: [CGPoint]
    let baselineY: CGFloat
    let baselineAvg: Double    // Sprint 1.5: passed through for avg label display
    let highIndex: Int
    let lowIndex: Int
}

// Separate View for the actual rendering — no complex expressions in body
private struct SparklineCanvas: View {
    let layout: SparklineLayout
    let scores: [Double]
    let lineColor: Color

    var body: some View {
        ZStack {
            // ── Dashed baseline reference line — white 20% opacity per handoff ──
            Canvas { ctx, _ in
                var dash = Path()
                dash.move(to: CGPoint(x: 0, y: layout.baselineY))
                dash.addLine(to: CGPoint(x: layout.width, y: layout.baselineY))
                ctx.stroke(
                    dash,
                    with: .color(.white.opacity(0.20)),
                    style: StrokeStyle(lineWidth: 1, dash: [4, 4])
                )
            }

            // ── Sprint 1.5: Baseline avg label — left edge, vertically on the dashed line ──
            // Format: "avg 78" — Jost 9pt light, white 35% opacity, subordinate to high/low
            Text("avg \(Int(layout.baselineAvg.rounded()))")
                .font(.jost(size: 9, weight: .light))
                .foregroundColor(.white.opacity(0.35))
                .position(x: 18, y: layout.baselineY - 8)

            // ── Sparkline line ──
            Canvas { ctx, _ in
                guard layout.points.count > 1 else { return }
                var path = Path()
                path.move(to: layout.points[0])
                for pt in layout.points.dropFirst() { path.addLine(to: pt) }
                ctx.stroke(path, with: .color(lineColor.opacity(0.85)), lineWidth: 1.5)
            }

            // ── Today's endpoint dot — slightly larger to anchor current state ──
            if let last = layout.points.last {
                Circle()
                    .fill(lineColor)
                    .frame(width: 6, height: 6)
                    .position(last)
            }

            // ── High label at actual high-point x/y position ──
            if !scores.isEmpty {
                Text("\(Int(scores[layout.highIndex].rounded()))")
                    .font(.jost(size: 9, weight: .light))
                    .foregroundColor(ChronosTheme.muted)
                    .position(
                        x: layout.points[layout.highIndex].x,
                        y: layout.points[layout.highIndex].y - 10
                    )
            }

            // ── Low label at actual low-point x/y position ──
            if !scores.isEmpty {
                Text("\(Int(scores[layout.lowIndex].rounded()))")
                    .font(.jost(size: 9, weight: .light))
                    .foregroundColor(ChronosTheme.muted)
                    .position(
                        x: layout.points[layout.lowIndex].x,
                        y: layout.points[layout.lowIndex].y + 10
                    )
            }
        }
    }
}

// ─────────────────────────────────────────
// LETTER CARD
// ─────────────────────────────────────────

struct LetterCard: View {
    let score: DailyScore
    let explanation: Explanation

    // Use device Date() — same source as the header — so the day name always matches today,
    // regardless of which date the score row was generated for.
    var letterFromLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let day = formatter.string(from: Date())
        return "Chronos · \(day) \(TimeOfDay.current.label)"
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color(red: 0.10, green: 0.10, blue: 0.17),
                             Color(red: 0.07, green: 0.07, blue: 0.11)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(ChronosTheme.border, lineWidth: 1))

            VStack(alignment: .leading, spacing: 12) {
                Text(letterFromLabel)
                    .font(.jost(size: 10, weight: .light))
                    .foregroundColor(ChronosTheme.gold).tracking(2).textCase(.uppercase)

                Rectangle().fill(ChronosTheme.gold.opacity(0.25)).frame(height: 1)

                Text(explanation.explanationText)
                    .font(.jost(size: 15, weight: .light))
                    .foregroundColor(Color(red: 0.965, green: 0.953, blue: 0.920))
                    .lineSpacing(7).fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
    }
}

// ─────────────────────────────────────────
// NUDGE CARD
// ─────────────────────────────────────────

struct ChronosNudgeCard: View {
    let nudge: String

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color(red: 0.13, green: 0.11, blue: 0.08),
                             Color(red: 0.09, green: 0.08, blue: 0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(ChronosTheme.gold.opacity(0.18), lineWidth: 1))

            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(
                        colors: [ChronosTheme.gold.opacity(0.4), ChronosTheme.goldLight],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 3).padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's focus")
                        .font(.jost(size: 9, weight: .light))
                        .foregroundColor(ChronosTheme.gold).tracking(2.5).textCase(.uppercase)

                    Text(nudge)
                        .font(.jost(size: 15, weight: .light))
                        .foregroundColor(Color(red: 0.910, green: 0.788, blue: 0.604))
                        .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
    }
}

// ─────────────────────────────────────────
// YELLOWLINE NUDGE CARD  Sprint 1.5
// Amber treatment — warmer than Drift, not as urgent as Redline.
// Same single-sentence nudge constraint as all other states.
// ─────────────────────────────────────────

struct YellowlineNudgeCard: View {
    let nudge: String

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.20, green: 0.15, blue: 0.04),
                        Color(red: 0.14, green: 0.11, blue: 0.03)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 1.0, green: 0.72, blue: 0.20).opacity(0.25), lineWidth: 1))

            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.72, blue: 0.20).opacity(0.6),
                            Color(red: 1.0, green: 0.85, blue: 0.40)
                        ],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 3).padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Worth noting today")
                        .font(.jost(size: 9, weight: .light))
                        .foregroundColor(Color(red: 1.0, green: 0.72, blue: 0.20))
                        .tracking(2.5).textCase(.uppercase)

                    Text(nudge)
                        .font(.jost(size: 15, weight: .light))
                        .foregroundColor(Color(red: 0.980, green: 0.940, blue: 0.840))
                        .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
    }
}

// ─────────────────────────────────────────
// FEEDBACK PROMPT
// ─────────────────────────────────────────

struct FeedbackPromptCard: View {
    let score: DailyScore
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Did this feel right?")
                        .font(.jost(size: 14, weight: .light)).foregroundColor(ChronosTheme.text)
                    Text("Your feedback sharpens your score over time.")
                        .font(.jost(size: 12, weight: .light)).foregroundColor(ChronosTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .light)).foregroundColor(ChronosTheme.faint)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(ChronosTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(ChronosTheme.border, lineWidth: 1))
            )
        }
    }
}

// ─────────────────────────────────────────
// SYNC STATUS BADGE
// ─────────────────────────────────────────

struct SyncStatusBadge: View {
    let state: SyncState

    var body: some View {
        switch state {
        case .syncing:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.65).tint(ChronosTheme.gold.opacity(0.5))
                Text("Syncing").font(.jost(size: 11, weight: .light)).foregroundColor(ChronosTheme.muted)
            }
        case .stale:
            Text("Cached").font(.jost(size: 11, weight: .light)).foregroundColor(.orange.opacity(0.6))
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12, weight: .light)).foregroundColor(.orange.opacity(0.6))
        default:
            EmptyView()
        }
    }
}

// ─────────────────────────────────────────
// STATE VIEWS
// ─────────────────────────────────────────

struct ChronosSyncingView: View {
    let message: String
    var body: some View {
        VStack(spacing: 20) {
            ChronosLogoMark().frame(width: 52, height: 52).opacity(0.5)
            Text(message).font(.jost(size: 14, weight: .light)).foregroundColor(ChronosTheme.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
    }
}

struct ChronosErrorView: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .thin)).foregroundColor(ChronosTheme.gold.opacity(0.5))
            Text(message).font(.jost(size: 13, weight: .light)).foregroundColor(ChronosTheme.muted)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button(action: onRetry) {
                Text("Try Again").font(.jost(size: 13, weight: .medium)).foregroundColor(ChronosTheme.gold)
                    .tracking(1.5).textCase(.uppercase)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ChronosTheme.gold.opacity(0.4), lineWidth: 1))
            }
        }
    }
}

struct ChronosEmptyView: View {
    var body: some View {
        VStack(spacing: 20) {
            ChronosLogoMark().frame(width: 52, height: 52).opacity(0.3)
            Text("No brief yet").font(.cormorant(size: 24)).foregroundColor(ChronosTheme.muted)
            Text("Your morning brief will appear after your\nfirst full night of Apple Watch data is synced.")
                .font(.jost(size: 13, weight: .light)).foregroundColor(ChronosTheme.faint)
                .multilineTextAlignment(.center).lineSpacing(5).padding(.horizontal, 48)
        }
    }
}

// ─────────────────────────────────────────
// DRIVER CHIP ROW  §3.3 + §3.4
//
// §3.3 changes:
//   - Value and signal word are now on separate lines
//   - Signal word color is direction-aware: green tint (positive), amber/red (negative)
//   - Value line: metric value with unit (e.g. "23ms", "6h 45m", "12,400 steps")
//   - Signal word: "above baseline" / "below baseline" / "above goal" / etc.
//
// §3.4 changes:
//   - Deviation data (today value, baseline, direction, magnitude %)
//     computed here and passed as DriverTapContext — no new Supabase call from detail screen
// ─────────────────────────────────────────

struct DriverChipRow: View {
    let score: DailyScore
    let onChipTap: (DriverTapContext) -> Void

    @EnvironmentObject var supabase: SupabaseService
    @State private var inputs: [String: Double?] = [:]
    @State private var baselines: [String: Double] = [:]

    var body: some View {
        HStack(spacing: 12) {
            DriverChip(
                label: "Driver 1",
                metricRaw: score.driver1,
                chipData: chipData(for: score.driver1, isDriver1: true),
                onTap: {
                    onChipTap(buildContext(for: score.driver1, isDriver1: true))
                }
            )
            DriverChip(
                label: "Driver 2",
                metricRaw: score.driver2,
                chipData: chipData(for: score.driver2, isDriver1: false),
                onTap: {
                    onChipTap(buildContext(for: score.driver2, isDriver1: false))
                }
            )
        }
        .task {
            guard let userId = supabase.session?.userId else { return }
            async let i = supabase.fetchInputs(userId: userId, date: score.date)
            async let b = supabase.fetchLatestBaselines(userId: userId)
            inputs = (try? await i) ?? [:]
            baselines = (try? await b) ?? [:]
        }
    }

    // ── §3.3: Chip display data — value + signal word split ──

    struct ChipData {
        let formattedValue: String?       // e.g. "23ms" or "6h 45m"
        let signalWord: String?           // e.g. "below baseline"
        let signalIsPositive: Bool        // drives color
        let isBuilding: Bool             // true = baseline not yet established
    }

    private func chipData(for metricRaw: String, isDriver1: Bool) -> ChipData {
        let key = inputKey(for: metricRaw)
        guard let valueOpt = inputs[key], let value = valueOpt else {
            return ChipData(formattedValue: nil, signalWord: nil, signalIsPositive: true, isBuilding: false)
        }

        let formatted = formatValue(metricRaw: metricRaw, value: value)
        let baselineKey = baselineColumnKey(for: metricRaw)
        let baseline = baselines[baselineKey]

        if let baseline = baseline, baseline > 0 {
            let (signal, isPositive) = signalWord(metricRaw: metricRaw, value: value, baseline: baseline)
            return ChipData(formattedValue: formatted, signalWord: signal, signalIsPositive: isPositive, isBuilding: false)
        } else {
            // Fewer than 7 full days of data — §3.3 "building" signal word
            return ChipData(formattedValue: formatted, signalWord: "building", signalIsPositive: true, isBuilding: true)
        }
    }

    /// §3.3 Signal word logic — returns (word, isPositive)
    private func signalWord(metricRaw: String, value: Double, baseline: Double) -> (String, Bool) {
        let pctDiff = (value - baseline) / baseline
        let higherIsBad = ["resting_hr", "respiratory_rate"]
        let behavioralGoal = ["steps", "active_minutes"]

        if behavioralGoal.contains(metricRaw) {
            // Use goal framing for behavioral metrics
            if pctDiff >= 0.10  { return ("above goal", true) }
            if pctDiff >= -0.05 { return ("at goal", true) }
            return ("below goal", false)
        } else if higherIsBad.contains(metricRaw) {
            if pctDiff <= -0.10 { return ("strong", true) }
            if pctDiff <= 0     { return ("at baseline", true) }
            if pctDiff <= 0.10  { return ("above baseline", false) }
            return ("above baseline", false)
        } else {
            // HRV, sleep, SpO2, etc. — higher is better
            if pctDiff >= 0.10  { return ("above baseline", true) }
            if pctDiff >= -0.05 { return ("at baseline", true) }
            if pctDiff >= -0.15 { return ("below baseline", false) }
            return ("below baseline", false)
        }
    }

    // ── §3.4: Build DriverTapContext — compute deviation, pass as nav param ──

    private func buildContext(for metricRaw: String, isDriver1: Bool) -> DriverTapContext {
        let key = inputKey(for: metricRaw)
        let valueOpt = inputs[key].flatMap { $0 }
        let baselineKey = baselineColumnKey(for: metricRaw)
        let baseline = baselines[baselineKey]

        var direction: DeviationDirection? = nil
        var magnitude: Double? = nil

        if let value = valueOpt, let base = baseline, base > 0 {
            direction = value >= base ? .above : .below
            magnitude = abs((value - base) / base) * 100
        }

        return DriverTapContext(
            id: metricRaw,
            metric: metricRaw,
            isDriver1: isDriver1,
            todayValue: valueOpt,
            baselineValue: baseline,
            deviationDirection: direction,
            deviationMagnitudePct: magnitude,
            formattedTodayValue: valueOpt.map { formatValue(metricRaw: metricRaw, value: $0) }
        )
    }

    // ── Helpers (unchanged logic, same as prior) ──

    private func inputKey(for metricRaw: String) -> String {
        switch metricRaw {
        case "hrv":              return "hrv_ms"
        case "resting_hr":       return "resting_hr_bpm"
        case "respiratory_rate": return "respiratory_rate_rpm"
        case "sleep_duration":   return "sleep_duration_hrs"
        case "sleep_efficiency": return "sleep_efficiency_pct"
        case "steps":            return "steps"
        case "active_minutes":   return "active_minutes"
        case "distance":         return "distance_km"
        case "spo2":             return "spo2_pct"
        case "resting_energy":   return "resting_energy"
        case "stand_hours":      return "stand_hours"
        default:                 return metricRaw
        }
    }

    private func formatValue(metricRaw: String, value: Double) -> String {
        switch metricRaw {
        case "hrv":
            return "\(Int(value))ms"
        case "resting_hr":
            return "\(Int(value)) bpm"
        case "respiratory_rate":
            return "\(String(format: "%.1f", value)) rpm"
        case "sleep_duration":
            let hrs = Int(value)
            let mins = Int((value - Double(hrs)) * 60)
            return mins > 0 ? "\(hrs)h \(mins)m" : "\(hrs)h"
        case "sleep_efficiency":
            return "\(Int(value))%"
        case "steps":
            return "\(formattedInt(Int(value))) steps"
        case "active_minutes":
            return "\(Int(value)) min"
        case "distance":
            return "\(String(format: "%.1f", value)) km"
        case "spo2":
            return "\(String(format: "%.1f", value))%"
        case "resting_energy":
            return "\(Int(value)) kcal"
        case "stand_hours":
            return "\(Int(value)) hrs"
        default:
            return "\(String(format: "%.1f", value))"
        }
    }

    private func baselineColumnKey(for metricRaw: String) -> String {
        switch metricRaw {
        case "hrv":              return "hrv_avg"
        case "resting_hr":       return "resting_hr_avg"
        case "respiratory_rate": return "respiratory_rate_avg"
        case "sleep_duration":   return "sleep_duration_avg"
        case "sleep_efficiency": return "sleep_efficiency_avg"
        case "steps":            return "steps_avg"
        case "active_minutes":   return "active_minutes_avg"
        default:                 return "\(metricRaw)_avg"
        }
    }

    private func formattedInt(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// ─────────────────────────────────────────
// DRIVER CHIP  §3.3
//
// Layout per handoff:
//   DRIVER 1 / DRIVER 2   (small caps, muted — unchanged)
//   Metric name           (large, white — unchanged)
//   Value                 (own line, slightly smaller, unit included)
//   Signal word           (own line, direction-aware color)
//   ↓ Learn more          (unchanged)
// ─────────────────────────────────────────

struct DriverChip: View {
    let label: String
    let metricRaw: String
    let chipData: DriverChipRow.ChipData
    let onTap: () -> Void

    var metricName: String {
        Metric(rawValue: metricRaw)?.shortName
            ?? metricRaw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    // §3.3: Green tint for positive, amber/red for negative
    var signalColor: Color {
        if chipData.isBuilding {
            return ChronosTheme.gold.opacity(0.6)  // neutral — still establishing baseline
        }
        return chipData.signalIsPositive
            ? Color(red: 0.50, green: 0.90, blue: 0.55)   // green tint
            : Color(red: 1.0, green: 0.65, blue: 0.35)    // amber
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(ChronosTheme.ink)
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(ChronosTheme.border, lineWidth: 1))
                    .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)

                VStack(alignment: .leading, spacing: 5) {
                    // Driver label — small caps, muted (unchanged)
                    Text(label.uppercased())
                        .font(.jost(size: 9, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                        .tracking(2)

                    // Metric name — large, white (unchanged)
                    Text(metricName)
                        .font(.cormorant(size: 20, weight: .medium))
                        .foregroundColor(ChronosTheme.text)

                    // §3.3: Value — own line, slightly smaller than metric name, unit included
                    if let value = chipData.formattedValue {
                        Text(value)
                            .font(.jost(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.text.opacity(0.85))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    } else {
                        // Loading skeleton
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ChronosTheme.faint.opacity(0.2))
                            .frame(width: 60, height: 10)
                    }

                    // §3.3: Signal word — own line, direction-aware color
                    if let signal = chipData.signalWord {
                        Text(signal)
                            .font(.jost(size: 11, weight: .light))
                            .foregroundColor(signalColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    } else {
                        // Loading skeleton
                        RoundedRectangle(cornerRadius: 3)
                            .fill(ChronosTheme.faint.opacity(0.2))
                            .frame(width: 80, height: 10)
                    }

                    // Learn more — unchanged
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8, weight: .light))
                            .foregroundColor(ChronosTheme.gold.opacity(0.5))
                        Text("Learn more")
                            .font(.jost(size: 9, weight: .light))
                            .foregroundColor(ChronosTheme.gold.opacity(0.5))
                            .tracking(0.5)
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// ─────────────────────────────────────────
// COLOR BLEND HELPER
// ─────────────────────────────────────────

private extension Color {
    func blended(with other: Color, fraction: CGFloat) -> Color {
        let f = min(max(fraction, 0), 1)
        return Color(UIColor.blend(color1: UIColor(self), color2: UIColor(other), fraction: f))
    }
}

private extension UIColor {
    static func blend(color1: UIColor, color2: UIColor, fraction: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        color1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        color2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * fraction, green: g1 + (g2 - g1) * fraction,
                       blue: b1 + (b2 - b1) * fraction, alpha: a1 + (a2 - a1) * fraction)
    }
}
