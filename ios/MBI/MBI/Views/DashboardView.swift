// ios/MBI/MBI/Views/DashboardView.swift
// MBI Phase 1.5 — Daily Dashboard + Main Tab Container

import SwiftUI

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
                .tabItem { Label("Today", systemImage: "waveform.path.ecg") }
                .tag(0)

            DomainBreakdownView()
                .tabItem { Label("Domains", systemImage: "square.grid.2x2") }
                .tag(1)

            AdminView()
                .tabItem { Label("Admin", systemImage: "person.2") }
                .tag(2)
        }
        .accentColor(.white)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.backgroundColor = UIColor(white: 0.06, alpha: 1)
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
    @State private var showSignOutConfirm = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // ── Header ──
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(greeting())
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.4))
                            Text(supabase.currentUser?.displayName ?? "")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        SyncStatusBadge(state: sync.syncState)

                        // Sign out button
                        Button(action: { showSignOutConfirm = true }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.leading, 12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 24)

                    // ── Content ──
                    if let data = sync.dashboard {
                        ScoreCard(score: data.score)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                        if data.recentScores.count > 1 {
                            SparklineCard(scores: data.recentScores)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                        }

                        if let explanation = data.explanation {
                            ExplanationCard(explanation: explanation)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)

                            NudgeCard(nudge: explanation.nudgeText)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                        }

                        FeedbackPromptCard(score: data.score) {
                            showFeedback = true
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)

                    } else if case .syncing(let msg) = sync.syncState {
                        SyncingStateView(message: msg)
                            .padding(.top, 60)

                    } else if case .failed(let msg) = sync.syncState {
                        ErrorStateView(message: msg) {
                            Task {
                                if let userId = supabase.session?.userId {
                                    if msg.contains("401") {
                                        await supabase.refreshSessionIfNeeded()
                                    }
                                    await sync.runDailySync(userId: userId)
                                }
                            }
                        }
                        .padding(.top, 60)

                    } else {
                        EmptyScoreView()
                            .padding(.top, 60)
                    }
                }
            }
        }
        .sheet(isPresented: $showFeedback) {
            if let data = sync.dashboard {
                FeedbackView(score: data.score)
            }
        }
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign Out", role: .destructive) {
                supabase.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need to sign back in.")
        }
    }

    private func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }
}

// ─────────────────────────────────────────
// SCORE CARD
// ─────────────────────────────────────────

struct ScoreCard: View {
    let score: DailyScore

    var bandColor: Color {
        switch score.scoreBand {
        case .thriving:  return Color(red: 0.3,  green: 0.85, blue: 0.5)
        case .recovering: return Color(red: 0.4,  green: 0.7,  blue: 1.0)
        case .drifting:  return Color(red: 1.0,  green: 0.75, blue: 0.2)
        case .redline:   return Color(red: 1.0,  green: 0.35, blue: 0.35)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))

            VStack(spacing: 0) {
                Text(formattedDate())
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))
                    .padding(.top, 20)

                Text("\(Int(score.chronosScore))")
                    .font(.system(size: 80, weight: .thin))
                    .foregroundColor(bandColor)
                    .padding(.top, 4)

                Text(score.scoreBand.rawValue.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(bandColor.opacity(0.8))
                    .padding(.top, 2)

                if score.isProvisional {
                    Text("BUILDING BASELINE")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, 6)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                HStack(spacing: 0) {
                    DriverPill(label: "Driver 1", value: formatMetric(score.driver1))
                    Divider()
                        .background(Color.white.opacity(0.08))
                        .frame(height: 40)
                    DriverPill(label: "Driver 2", value: formatMetric(score.driver2))
                }
                .padding(.vertical, 16)
            }
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: score.date) {
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: date)
        }
        return score.date
    }

    private func formatMetric(_ raw: String) -> String {
        Metric(rawValue: raw)?.shortName ?? raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct DriverPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.3))
                .tracking(1.5)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
    }
}

// ─────────────────────────────────────────
// SPARKLINE CARD
// ─────────────────────────────────────────

struct SparklineCard: View {
    let scores: [Double]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))

            VStack(alignment: .leading, spacing: 12) {
                Text("7-Day Trend")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1.5)

                GeometryReader { geo in
                    SparklinePath(scores: scores, size: geo.size)
                }
                .frame(height: 48)

                HStack {
                    Text("7 days ago")
                    Spacer()
                    Text("Today")
                }
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.25))
            }
            .padding(16)
        }
        .frame(height: 120)
    }
}

struct SparklinePath: View {
    let scores: [Double]
    let size: CGSize

    var body: some View {
        let minScore = (scores.min() ?? 0) - 5
        let maxScore = (scores.max() ?? 100) + 5
        let range = maxScore - minScore

        Canvas { context, _ in
            guard scores.count > 1 else { return }
            let step = size.width / CGFloat(scores.count - 1)
            var path = Path()
            for (i, score) in scores.enumerated() {
                let x = CGFloat(i) * step
                let y = size.height - CGFloat((score - minScore) / range) * size.height
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 1.5)

            if let last = scores.last {
                let x = size.width
                let y = size.height - CGFloat((last - minScore) / range) * size.height
                let dotRect = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
                context.fill(Path(ellipseIn: dotRect), with: .color(.white))
            }
        }
    }
}

// ─────────────────────────────────────────
// EXPLANATION & NUDGE CARDS
// ─────────────────────────────────────────

struct ExplanationCard: View {
    let explanation: Explanation

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))

            VStack(alignment: .leading, spacing: 12) {
                Text("What happened")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                    .tracking(1.5)

                Text(explanation.explanationText)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(5)
            }
            .padding(20)
        }
    }
}

struct NudgeCard: View {
    let nudge: String

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 3)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's nudge")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(1.5)
                    Text(nudge)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .lineSpacing(3)
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
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    Text("Your feedback makes the score more accurate over time.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)))
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
                ProgressView().scaleEffect(0.7).tint(.white.opacity(0.5))
                Text("Syncing").font(.system(size: 12)).foregroundColor(.white.opacity(0.4))
            }
        case .stale:
            Text("Cached").font(.system(size: 12)).foregroundColor(.orange.opacity(0.6))
        case .failed:
            Image(systemName: "exclamationmark.triangle").foregroundColor(.orange.opacity(0.6))
        default:
            EmptyView()
        }
    }
}

// ─────────────────────────────────────────
// EMPTY / LOADING / ERROR STATES
// ─────────────────────────────────────────

struct SyncingStateView: View {
    let message: String
    var body: some View {
        VStack(spacing: 16) {
            ProgressView().tint(.white.opacity(0.6)).scaleEffect(1.2)
            Text(message).font(.system(size: 15)).foregroundColor(.white.opacity(0.5))
        }
    }
}

struct ErrorStateView: View {
    let message: String
    let onRetry: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36)).foregroundColor(.orange.opacity(0.6))
            Text(message)
                .font(.system(size: 14)).foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Try Again", action: onRetry)
                .font(.system(size: 15, weight: .medium)).foregroundColor(.white)
        }
    }
}

struct EmptyScoreView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.stars")
                .font(.system(size: 40)).foregroundColor(.white.opacity(0.3))
            Text("No score yet for today")
                .font(.system(size: 17, weight: .medium)).foregroundColor(.white.opacity(0.6))
            Text("Your score will appear after your first full day of Apple Watch data is synced.")
                .font(.system(size: 14)).foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center).padding(.horizontal, 48).lineSpacing(4)
        }
    }
}
