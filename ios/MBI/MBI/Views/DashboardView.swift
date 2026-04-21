// ios/MBI/MBI/Views/DashboardView.swift
// MBI Phase 1.5 — Dashboard · Morning Brief · E-10 update
// Changes: Account button relocated from MainTabView ZStack → MorningBriefHeader
//          showAccount state + AccountView sheet moved to DashboardView
//          MorningBriefHeader gains onAccountTap closure
//          MainTabView ZStack overlay removed entirely

import SwiftUI

// ─────────────────────────────────────────
// TIME OF DAY  — single source of truth
// Used by: header greeting, letter label, narrate payload
// ─────────────────────────────────────────

enum TimeOfDay: String {
    case morning  = "morning"
    case daytime  = "daytime"
    case evening  = "evening"

    /// Derived from the device clock at the moment of access.
    static var current: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return .morning }
        if hour < 17 { return .daytime }
        return .evening
    }

    var greeting: String {
        switch self {
        case .morning:  return "Good morning"
        case .daytime:  return "Good afternoon"
        case .evening:  return "Good evening"
        }
    }

    /// Short label used in LetterCard header ("Chronos · Monday morning")
    var label: String { rawValue }
}

// ─────────────────────────────────────────
// MAIN TAB
// ZStack overlay removed — account button now lives in MorningBriefHeader
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

            HorizonPlaceholderView()
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
// showAccount + AccountView sheet now owned here
// ─────────────────────────────────────────

struct DashboardView: View {
    @EnvironmentObject var sync: SyncCoordinator
    @EnvironmentObject var supabase: SupabaseService
    @State private var showFeedback = false
    @State private var showAccount = false

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

                    MorningBriefHeader(
                        displayName: supabase.currentUser?.displayName ?? "",
                        syncState: sync.syncState,
                        onAccountTap: { showAccount = true }
                    )

                    if let data = sync.dashboard {

                        let failState = data.score.failState

                        if failState == "Ghost-AtRisk" {
                            GhostAtRiskView(score: data.score) { }

                        } else if failState == "Redline" || data.score.scoreBand == .redline {
                            RedlineDashboardView(
                                score: data.score,
                                explanation: data.explanation,
                                recentScores: data.recentScores
                            )

                        } else {
                            MorningScoreCard(score: data.score, recentScores: data.recentScores)
                                .padding(.horizontal, 20).padding(.bottom, 16)

                            DriverChipRow(score: data.score)
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
    }
}

// ─────────────────────────────────────────
// HEADER
// Now owns the account button via onAccountTap closure
// greeting() delegates to TimeOfDay enum
// ─────────────────────────────────────────

struct MorningBriefHeader: View {
    let displayName: String
    let syncState: SyncState
    let onAccountTap: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(TimeOfDay.current.greeting.uppercased())
                    .font(.jost(size: 10, weight: .light))
                    .foregroundColor(ChronosTheme.gold)
                    .tracking(3)

                Text(displayName.isEmpty ? "—" : displayName)
                    .font(.cormorant(size: 26, weight: .light))
                    .foregroundColor(ChronosTheme.text)
            }
            Spacer()
            HStack(spacing: 12) {
                SyncStatusBadge(state: syncState)
                Button(action: onAccountTap) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 26, weight: .ultraLight))
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
// SCORE CARD
// ─────────────────────────────────────────

struct MorningScoreCard: View {
    let score: DailyScore
    let recentScores: [Double]

    var bandTint: Color {
        switch score.scoreBand {
        case .thriving:   return Color(red: 0.15, green: 0.35, blue: 0.20)
        case .recovering: return Color(red: 0.18, green: 0.20, blue: 0.36)
        case .drifting:   return Color(red: 0.36, green: 0.28, blue: 0.10)
        case .redline:    return Color(red: 0.38, green: 0.12, blue: 0.12)
        }
    }

    var bandColor: Color {
        switch score.scoreBand {
        case .thriving:   return Color(red: 0.50, green: 0.90, blue: 0.55)
        case .recovering: return ChronosTheme.goldLight
        case .drifting:   return Color(red: 1.0, green: 0.80, blue: 0.30)
        case .redline:    return Color(red: 1.0, green: 0.42, blue: 0.42)
        }
    }

    var yesterdayScore: Double? {
        guard recentScores.count >= 2 else { return nil }
        return recentScores[recentScores.count - 2]
    }

    var deltaText: String? {
        guard let yesterday = yesterdayScore else { return nil }
        let diff = Int(score.chronosScore) - Int(yesterday)
        if diff == 0 { return "— no change" }
        return "\(diff > 0 ? "↑" : "↓") \(abs(diff)) from yesterday"
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
                Text(formattedDate())
                    .font(.jost(size: 11, weight: .light))
                    .foregroundColor(ChronosTheme.muted)
                    .tracking(2).textCase(.uppercase)
                    .padding(.top, 22)

                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Text("\(Int(score.chronosScore))")
                        .font(.cormorant(size: 96, weight: .light))
                        .foregroundColor(bandColor)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(score.scoreBand.rawValue.uppercased())
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
                .padding(.top, 4).padding(.horizontal, 24)

                if score.isProvisional {
                    Text("BUILDING BASELINE")
                        .font(.jost(size: 9, weight: .light))
                        .foregroundColor(ChronosTheme.gold.opacity(0.6))
                        .tracking(2.5).padding(.top, 2).padding(.bottom, 6)
                }

                if recentScores.count > 1 {
                    GoldSparkline(scores: recentScores)
                        .frame(height: 28)
                        .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 20)
                } else {
                    Spacer().frame(height: 20)
                }
            }
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: score.date) {
            formatter.dateFormat = "EEEE · MMMM d"
            return formatter.string(from: date)
        }
        return score.date
    }
}

// ─────────────────────────────────────────
// GOLD SPARKLINE
// ─────────────────────────────────────────

struct GoldSparkline: View {
    let scores: [Double]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let minS = (scores.min() ?? 0) - 5
            let maxS = (scores.max() ?? 100) + 5
            let range = maxS - minS
            let step = w / CGFloat(max(scores.count - 1, 1))
            let points: [CGPoint] = scores.enumerated().map { i, s in
                CGPoint(x: CGFloat(i) * step, y: h - CGFloat((s - minS) / range) * h)
            }
            ZStack {
                Canvas { ctx, _ in
                    guard points.count > 1 else { return }
                    var path = Path()
                    path.move(to: points[0])
                    for pt in points.dropFirst() { path.addLine(to: pt) }
                    ctx.stroke(path,
                               with: .linearGradient(
                                Gradient(colors: [ChronosTheme.gold.opacity(0.2), ChronosTheme.goldLight]),
                                startPoint: CGPoint(x: 0, y: h / 2),
                                endPoint: CGPoint(x: w, y: h / 2)),
                               lineWidth: 1.5)
                }
                if let last = points.last {
                    Circle().fill(ChronosTheme.goldLight).frame(width: 5, height: 5).position(last)
                }
            }
        }
    }
}

// ─────────────────────────────────────────
// DRIVER CHIP ROW
// ─────────────────────────────────────────

struct DriverChipRow: View {
    let score: DailyScore
    var body: some View {
        HStack(spacing: 12) {
            DriverChip(label: "Driver 1", metricRaw: score.driver1, delta: nil)
            DriverChip(label: "Driver 2", metricRaw: score.driver2, delta: nil)
        }
    }
}

struct DriverChip: View {
    let label: String
    let metricRaw: String
    let delta: String?

    var metricName: String {
        Metric(rawValue: metricRaw)?.shortName
            ?? metricRaw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(ChronosTheme.ink)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(ChronosTheme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 5) {
                Text(label.uppercased())
                    .font(.jost(size: 9, weight: .light))
                    .foregroundColor(ChronosTheme.muted).tracking(2)

                Text(metricName)
                    .font(.cormorant(size: 20, weight: .medium))
                    .foregroundColor(ChronosTheme.text)

                if let d = delta {
                    Text(d).font(.jost(size: 11, weight: .light)).foregroundColor(ChronosTheme.gold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
    }
}

// ─────────────────────────────────────────
// LETTER CARD
// ─────────────────────────────────────────

struct LetterCard: View {
    let score: DailyScore
    let explanation: Explanation

    var letterFromLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: score.date) {
            formatter.dateFormat = "EEEE"
            let day = formatter.string(from: date)
            return "Chronos · \(day) \(TimeOfDay.current.label)"
        }
        return "Chronos"
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
