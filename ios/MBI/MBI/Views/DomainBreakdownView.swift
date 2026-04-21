// ios/MBI/MBI/Views/DomainBreakdownView.swift
// MBI Phase 1.5 — Domain Breakdown · E-04

import SwiftUI

// ─────────────────────────────────────────
// DOMAIN BREAKDOWN VIEW
// ─────────────────────────────────────────

struct DomainBreakdownView: View {
    @EnvironmentObject var sync: SyncCoordinator

    var body: some View {
        ZStack {
            ChronosTheme.ink.ignoresSafeArea()

            RadialGradient(
                colors: [ChronosTheme.gold.opacity(0.04), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 300
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Header ──
                    DomainsHeader()

                    if let score = sync.dashboard?.score {
                        VStack(spacing: 10) {

                            ChronosDomainCard(
                                label: "D1",
                                title: "Autonomic Recovery",
                                subtitle: "HRV · Resting HR",
                                score: score.d1Autonomic,
                                previousScore: nil,
                                isActive: true,
                                description: "Reflects your autonomic nervous system balance — the foundational signal for how recovered and adaptable your body is today."
                            )

                            ChronosDomainCard(
                                label: "D2",
                                title: "Sleep Recovery",
                                subtitle: "Duration · Quality",
                                score: score.d2Sleep,
                                previousScore: nil,
                                isActive: true,
                                description: "Measures how much recovery work happened overnight — both hours in bed and the quality of that sleep relative to your baseline."
                            )

                            ChronosDomainCard(
                                label: "D3",
                                title: "Activity Load",
                                subtitle: "Steps · Active min",
                                score: score.d3Activity,
                                previousScore: nil,
                                isActive: true,
                                description: "How much physical work your body handled today relative to your personal movement baseline."
                            )

                            ChronosDomainCard(
                                label: "D4",
                                title: "Inferred Stress",
                                subtitle: "7-day pattern",
                                score: score.d4Stress,
                                previousScore: nil,
                                isActive: score.d4Stress != nil,
                                description: "Detects accumulating physiological stress patterns over the past week before they compound.",
                                pendingMessage: "Active after 7 days of history"
                            )

                            ChronosDomainCard(
                                label: "D5",
                                title: "Allostatic Trend",
                                subtitle: "30-day composite",
                                score: score.d5Allostatic,
                                previousScore: nil,
                                isActive: score.d5Allostatic != nil,
                                description: "The long-range view — where your body is heading across the past month. The prevention intelligence layer.",
                                pendingMessage: "Active after 30 days of history"
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 48)

                    } else {
                        DomainsEmptyView()
                            .padding(.top, 60)
                    }
                }
            }
        }
    }
}

// ─────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────

struct DomainsHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FIVE SYSTEMS")
                .font(.jost(size: 10, weight: .light))
                .foregroundColor(ChronosTheme.gold)
                .tracking(3)

            Text("One picture.")
                .font(.cormorant(size: 32, weight: .light))
                .foregroundColor(ChronosTheme.text)

            Text("How each system performed today relative to your baseline.")
                .font(.jost(size: 13, weight: .light))
                .foregroundColor(ChronosTheme.muted)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
}

// ─────────────────────────────────────────
// DOMAIN CARD
// ─────────────────────────────────────────

struct ChronosDomainCard: View {
    let label: String
    let title: String
    let subtitle: String
    let score: Double?
    let previousScore: Double?   // reserved for delta — wired in follow-up
    let isActive: Bool
    let description: String
    var pendingMessage: String? = nil

    @State private var isExpanded = false

    // Score drives bar and number color
    var scoreColor: Color {
        guard let s = score else { return ChronosTheme.faint }
        if s >= 80 { return Color(red: 0.40, green: 0.82, blue: 0.50) }
        if s >= 60 { return ChronosTheme.goldLight }
        if s >= 40 { return Color(red: 1.0, green: 0.78, blue: 0.28) }
        return Color(red: 1.0, green: 0.40, blue: 0.40)
    }

    // Low score = muted red bar fill
    var barColor: LinearGradient {
        guard let s = score else {
            return LinearGradient(colors: [ChronosTheme.faint], startPoint: .leading, endPoint: .trailing)
        }
        if s < 50 {
            return LinearGradient(
                colors: [Color(red: 0.65, green: 0.25, blue: 0.25), Color(red: 0.78, green: 0.35, blue: 0.35)],
                startPoint: .leading, endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [ChronosTheme.gold.opacity(0.7), ChronosTheme.goldLight],
            startPoint: .leading, endPoint: .trailing
        )
    }

    var deltaText: String? {
        guard let s = score, let prev = previousScore else { return nil }
        let diff = Int(s) - Int(prev)
        if diff == 0 { return nil }
        return diff > 0 ? "↑ \(abs(diff))" : "↓ \(abs(diff))"
    }

    var deltaColor: Color {
        guard let s = score, let prev = previousScore else { return ChronosTheme.muted }
        return s >= prev
            ? Color(red: 0.40, green: 0.82, blue: 0.50)
            : Color(red: 1.0, green: 0.50, blue: 0.50)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Card background
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.098, green: 0.098, blue: 0.157),
                            Color(red: 0.071, green: 0.071, blue: 0.118)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isActive
                                ? ChronosTheme.gold.opacity(0.18)
                                : ChronosTheme.border,
                            lineWidth: 1
                        )
                )

            // Gold top border (active only)
            if isActive {
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, ChronosTheme.gold.opacity(0.5), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .clipShape(.rect(topLeadingRadius: 16, topTrailingRadius: 16))
                    Spacer()
                }
            }

            VStack(spacing: 0) {
                // ── Header row (tappable) ──
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 12) {

                        // Badge
                        Text(label)
                            .font(.jost(size: 9, weight: isActive ? .medium : .light))
                            .foregroundColor(isActive ? ChronosTheme.gold : ChronosTheme.faint)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        isActive
                                            ? ChronosTheme.goldDim
                                            : ChronosTheme.ink
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(
                                                isActive
                                                    ? ChronosTheme.gold.opacity(0.2)
                                                    : ChronosTheme.border,
                                                lineWidth: 1
                                            )
                                    )
                            )

                        // Title + subtitle
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.jost(size: 13, weight: .regular))
                                .foregroundColor(isActive ? ChronosTheme.text : ChronosTheme.muted)
                            Text(subtitle)
                                .font(.jost(size: 10, weight: .light))
                                .foregroundColor(ChronosTheme.faint)
                        }

                        Spacer()

                        // Score + delta
                        if let s = score {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                if let delta = deltaText {
                                    Text(delta)
                                        .font(.jost(size: 10, weight: .light))
                                        .foregroundColor(deltaColor)
                                }
                                Text("\(Int(s))")
                                    .font(.cormorant(size: 22, weight: .light))
                                    .foregroundColor(scoreColor)
                            }
                        }

                        // Chevron
                        if isActive {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .light))
                                .foregroundColor(ChronosTheme.faint)
                                .padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .disabled(!isActive)

                // ── Bar track (always visible when active, score available) ──
                if isActive, let s = score {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Track
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ChronosTheme.faint.opacity(0.4))
                                .frame(height: 3)

                            // Fill
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor)
                                .frame(width: geo.size.width * CGFloat(s / 100), height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, isExpanded ? 0 : 14)
                }

                // ── Pending lock row ──
                if !isActive, let msg = pendingMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "lock")
                            .font(.system(size: 9, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                        Text(msg.uppercased())
                            .font(.jost(size: 8, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                            .tracking(1.5)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }

                // ── Expanded description ──
                if isExpanded && isActive {
                    VStack(alignment: .leading, spacing: 0) {
                        Rectangle()
                            .fill(ChronosTheme.gold.opacity(0.12))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        Text(description)
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(ChronosTheme.muted)
                            .lineSpacing(5)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 16)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        // D5 pending — full card dimmed
        .opacity(label == "D5" && !isActive ? 0.35 : 1.0)
        // D4 pending — slightly dimmed
        .opacity(label == "D4" && !isActive ? 0.60 : 1.0)
    }
}

// ─────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────

struct DomainsEmptyView: View {
    var body: some View {
        VStack(spacing: 20) {
            ChronosLogoMark()
                .frame(width: 52, height: 52)
                .opacity(0.25)

            Text("No domain data yet")
                .font(.cormorant(size: 24))
                .foregroundColor(ChronosTheme.muted)

            Text("Sync your Apple Watch data to\nsee how each system is performing.")
                .font(.jost(size: 13, weight: .light))
                .foregroundColor(ChronosTheme.faint)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 48)
        }
    }
}
