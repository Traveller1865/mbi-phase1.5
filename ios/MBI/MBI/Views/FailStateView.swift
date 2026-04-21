// ios/MBI/MBI/Views/FailStateView.swift
// MBI Phase 1.5 — Fail State UI · E-07
// Ghost Mode (At-Risk) + Redline tone shift
// Drift Mode handled inline in DashboardView (simplified nudge, no separate screen)
// Ghost Mode (Healthy) = system goes quiet, no UI needed

import SwiftUI

// ─────────────────────────────────────────
// GHOST MODE — AT RISK
// Full-screen soft intervention
// Triggered: 3+ days no engagement + score declining
// Non-negotiable: never silent during deterioration
// ─────────────────────────────────────────

struct GhostAtRiskView: View {
    let score: DailyScore
    let onSeeWhatHappened: () -> Void
    @State private var pulsing = false

    var body: some View {
        ZStack {
            ChronosTheme.ink.ignoresSafeArea()

            // Subtle amber ambient glow — not alarming, just present
            RadialGradient(
                colors: [Color(red: 0.55, green: 0.35, blue: 0.10).opacity(0.12), .clear],
                center: .center,
                startRadius: 0,
                endRadius: 380
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Clock icon — pulsing ──
                ZStack {
                    Circle()
                        .stroke(ChronosTheme.gold.opacity(pulsing ? 0.25 : 0.08), lineWidth: 1)
                        .frame(width: 90, height: 90)
                        .scaleEffect(pulsing ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulsing)

                    Circle()
                        .stroke(ChronosTheme.gold.opacity(0.15), lineWidth: 1)
                        .frame(width: 70, height: 70)

                    Image(systemName: "clock")
                        .font(.system(size: 26, weight: .ultraLight))
                        .foregroundColor(ChronosTheme.gold.opacity(0.7))
                }
                .padding(.bottom, 36)

                // ── Heading ──
                VStack(spacing: 10) {
                    Text("It's been a few days.")
                        .font(.cormorant(size: 30, weight: .light))
                        .foregroundColor(ChronosTheme.text)
                        .multilineTextAlignment(.center)

                    Text("Your score has been declining.\nChronos won't go quiet while that's happening.")
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 36)

                // ── Score card — surfaced inline ──
                VStack(spacing: 6) {
                    Text("YOUR SCORE · TODAY")
                        .font(.jost(size: 9, weight: .light))
                        .foregroundColor(ChronosTheme.gold)
                        .tracking(3)

                    Text("\(Int(score.chronosScore))")
                        .font(.cormorant(size: 64, weight: .light))
                        .foregroundColor(ChronosTheme.goldLight)

                    Text(score.scoreBand.rawValue.uppercased())
                        .font(.jost(size: 10, weight: .medium))
                        .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.28))
                        .tracking(3)

                    Text("4-day decline")
                        .font(.jost(size: 11, weight: .light))
                        .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.35))
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(ChronosTheme.goldDim)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(ChronosTheme.gold.opacity(0.2), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 40)

                Spacer()

                // ── CTA ──
                ChronosPrimaryButton(title: "See what happened") {
                    onSeeWhatHappened()
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
        .onAppear { pulsing = true }
    }
}

// ─────────────────────────────────────────
// REDLINE DASHBOARD
// Full UI tone shift to deep red
// Replaces normal morning brief content
// Triggered: score 0–39 or any Redline condition
// Calm, supportive, never clinical
// ─────────────────────────────────────────

struct RedlineDashboardView: View {
    let score: DailyScore
    let explanation: Explanation?
    let recentScores: [Double]

    var body: some View {
        ZStack {
            // Deep red background tint
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.05, blue: 0.05),
                    ChronosTheme.ink
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Ambient red glow
            RadialGradient(
                colors: [Color(red: 0.55, green: 0.10, blue: 0.10).opacity(0.15), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Score card — full red treatment ──
                    ZStack(alignment: .top) {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.07, blue: 0.07),
                                    Color(red: 0.14, green: 0.05, blue: 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))

                        // Red top border
                        VStack {
                            Rectangle()
                                .fill(LinearGradient(
                                    colors: [.clear, Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.6), .clear],
                                    startPoint: .leading, endPoint: .trailing))
                                .frame(height: 1)
                                .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
                            Spacer()
                        }

                        VStack(spacing: 0) {
                            Text(formattedDate())
                                .font(.jost(size: 11, weight: .light))
                                .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.55).opacity(0.7))
                                .tracking(2).textCase(.uppercase)
                                .padding(.top, 22)

                            HStack(alignment: .firstTextBaseline, spacing: 16) {
                                Text("\(Int(score.chronosScore))")
                                    .font(.cormorant(size: 96, weight: .light))
                                    .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("REDLINE")
                                        .font(.jost(size: 11, weight: .medium))
                                        .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                                        .tracking(3)

                                    Text("Rest is the priority today.")
                                        .font(.jost(size: 11, weight: .light))
                                        .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.55).opacity(0.8))
                                }
                                .padding(.bottom, 10)
                            }
                            .padding(.top, 4).padding(.horizontal, 24)

                            // Red sparkline
                            if recentScores.count > 1 {
                                RedSparkline(scores: recentScores)
                                    .frame(height: 28)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 4)
                                    .padding(.bottom, 20)
                            } else {
                                Spacer().frame(height: 20)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // ── Driver chips — red tint ──
                    HStack(spacing: 12) {
                        RedlineDriverChip(label: "Driver 1", metricRaw: score.driver1)
                        RedlineDriverChip(label: "Driver 2", metricRaw: score.driver2)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                    // ── Explanation — calm, supportive ──
                    if let explanation = explanation {
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(
                                    colors: [
                                        Color(red: 0.14, green: 0.06, blue: 0.06),
                                        Color(red: 0.10, green: 0.05, blue: 0.05)
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.15), lineWidth: 1))

                            VStack(alignment: .leading, spacing: 12) {
                                Text("CHRONOS · WHAT HAPPENED")
                                    .font(.jost(size: 9, weight: .light))
                                    .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.8))
                                    .tracking(2)

                                Rectangle()
                                    .fill(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.2))
                                    .frame(height: 1)

                                Text(explanation.explanationText)
                                    .font(.jost(size: 15, weight: .light))
                                    .foregroundColor(Color(red: 0.965, green: 0.920, blue: 0.920))
                                    .lineSpacing(7)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)

                        // ── Nudge — red pip, single rest-focused action ──
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 0.16, green: 0.06, blue: 0.06))
                                .overlay(RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.2), lineWidth: 1))

                            HStack(spacing: 16) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(LinearGradient(
                                        colors: [
                                            Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.5),
                                            Color(red: 1.0, green: 0.55, blue: 0.55)
                                        ],
                                        startPoint: .top, endPoint: .bottom))
                                    .frame(width: 3).padding(.vertical, 4)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Today's only focus")
                                        .font(.jost(size: 9, weight: .light))
                                        .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42))
                                        .tracking(2.5).textCase(.uppercase)

                                    Text(explanation.nudgeText)
                                        .font(.jost(size: 15, weight: .light))
                                        .foregroundColor(Color(red: 0.965, green: 0.870, blue: 0.870))
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(20)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 48)
                    }
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
// RED SPARKLINE
// ─────────────────────────────────────────

struct RedSparkline: View {
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
                                Gradient(colors: [
                                    Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.2),
                                    Color(red: 1.0, green: 0.50, blue: 0.50)
                                ]),
                                startPoint: CGPoint(x: 0, y: h / 2),
                                endPoint: CGPoint(x: w, y: h / 2)),
                               lineWidth: 1.5)
                }
                if let last = points.last {
                    Circle()
                        .fill(Color(red: 1.0, green: 0.50, blue: 0.50))
                        .frame(width: 5, height: 5)
                        .position(last)
                }
            }
        }
    }
}

// ─────────────────────────────────────────
// REDLINE DRIVER CHIP
// ─────────────────────────────────────────

struct RedlineDriverChip: View {
    let label: String
    let metricRaw: String

    var metricName: String {
        Metric(rawValue: metricRaw)?.shortName
            ?? metricRaw.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.14, green: 0.06, blue: 0.06))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.2), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 5) {
                Text(label.uppercased())
                    .font(.jost(size: 9, weight: .light))
                    .foregroundColor(Color(red: 1.0, green: 0.42, blue: 0.42).opacity(0.7))
                    .tracking(2)

                Text(metricName)
                    .font(.cormorant(size: 20, weight: .medium))
                    .foregroundColor(Color(red: 0.965, green: 0.870, blue: 0.870))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
    }
}

// ─────────────────────────────────────────
// DRIFT MODE NUDGE CARD
// Used inline in DashboardView when failState == "Drift"
// Simplified — direct, lower cognitive load
// ─────────────────────────────────────────

struct DriftNudgeCard: View {
    let nudge: String

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.16, green: 0.12, blue: 0.05),
                        Color(red: 0.11, green: 0.09, blue: 0.04)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 1.0, green: 0.78, blue: 0.28).opacity(0.2), lineWidth: 1))

            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.78, blue: 0.28).opacity(0.5),
                            Color(red: 1.0, green: 0.88, blue: 0.45)
                        ],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: 3).padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("One thing today")
                        .font(.jost(size: 9, weight: .light))
                        .foregroundColor(Color(red: 1.0, green: 0.78, blue: 0.28))
                        .tracking(2.5).textCase(.uppercase)

                    Text(nudge)
                        .font(.jost(size: 15, weight: .light))
                        .foregroundColor(Color(red: 0.965, green: 0.930, blue: 0.820))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
    }
}
