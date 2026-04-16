// ios/MBI/Views/DomainBreakdownView.swift
// MBI Phase 1 — Domain Breakdown Screen
// D1–D3 active from Day 1. D4 after 7 days. D5 after 30 days.

import SwiftUI

struct DomainBreakdownView: View {
    @EnvironmentObject var sync: SyncCoordinator

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Text("Domain Breakdown")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 8)

                    Text("How your body is performing across each system")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.4))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)

                    if let score = sync.dashboard?.score {
                        VStack(spacing: 14) {
                            DomainCard(
                                title: "Autonomic Recovery",
                                label: "D1",
                                subtitle: "HRV + Resting Heart Rate",
                                score: score.d1Autonomic,
                                isActive: true,
                                description: "Reflects your autonomic nervous system balance — the foundational signal for how recovered and adaptable your body is."
                            )

                            DomainCard(
                                title: "Sleep Recovery",
                                label: "D2",
                                subtitle: "Sleep Duration + Sleep Quality",
                                score: score.d2Sleep,
                                isActive: true,
                                description: "Measures how much recovery work happened overnight — both the hours in bed and the quality of that sleep."
                            )

                            DomainCard(
                                title: "Activity Load",
                                label: "D3",
                                subtitle: "Steps + Active Minutes + Distance",
                                score: score.d3Activity,
                                isActive: true,
                                description: "How much physical work your body handled today relative to your personal baseline."
                            )

                            DomainCard(
                                title: "Inferred Stress",
                                label: "D4",
                                subtitle: "7-day HRV + RHR + Sleep trend",
                                score: score.d4Stress,
                                isActive: score.d4Stress != nil,
                                description: "Detects accumulating physiological stress patterns over the past week before they compound.",
                                pendingMessage: "Active after 7 days of history"
                            )

                            DomainCard(
                                title: "Allostatic Trend",
                                label: "D5",
                                subtitle: "30-day rolling composite",
                                score: score.d5Allostatic,
                                isActive: score.d5Allostatic != nil,
                                description: "The long-range view — where your body is heading across the past month.",
                                pendingMessage: "Active after 30 days of history"
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)

                    } else {
                        Text("No data yet. Sync to see your domain scores.")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.top, 60)
                    }
                }
            }
        }
    }
}

struct DomainCard: View {
    let title: String
    let label: String
    let subtitle: String
    let score: Double?
    let isActive: Bool
    let description: String
    var pendingMessage: String? = nil

    @State private var isExpanded = false

    var scoreColor: Color {
        guard let s = score else { return .white.opacity(0.3) }
        if s >= 80 { return Color(red: 0.3, green: 0.85, blue: 0.5) }
        if s >= 60 { return Color(red: 0.4, green: 0.7, blue: 1.0) }
        if s >= 40 { return Color(red: 1.0, green: 0.75, blue: 0.2) }
        return Color(red: 1.0, green: 0.35, blue: 0.35)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 16) {
                    // Label badge
                    Text(label)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(isActive ? scoreColor : .white.opacity(0.25))
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isActive ? scoreColor.opacity(0.12) : Color.white.opacity(0.05))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(isActive ? .white : .white.opacity(0.35))
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.35))
                    }

                    Spacer()

                    if let s = score {
                        Text("\(Int(s))")
                            .font(.system(size: 22, weight: .light))
                            .foregroundColor(scoreColor)
                    } else if let pending = pendingMessage {
                        Text("—")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(.white.opacity(0.2))
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(16)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)
                        .padding(.horizontal, 16)

                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .lineSpacing(4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 4)

                    if let pending = pendingMessage, score == nil {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 11))
                            Text(pending)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.white.opacity(0.3))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    }

                    if let s = score {
                        DomainScoreBar(score: s, color: scoreColor)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }
}

struct DomainScoreBar: View {
    let score: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(score / 100), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                Text("0")
                Spacer()
                Text("100")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.white.opacity(0.2))
        }
    }
}
