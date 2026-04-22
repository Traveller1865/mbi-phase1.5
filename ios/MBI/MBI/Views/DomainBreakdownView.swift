// ios/MBI/MBI/Views/DomainBreakdownView.swift
// MBI Phase 1.5 — Domain Breakdown · E-11 update
// Added: AllostaticPortraitCard renders below D5 when d5_allostatic is non-null

import SwiftUI

// ─────────────────────────────────────────
// DOMAIN BREAKDOWN VIEW
// ─────────────────────────────────────────

struct DomainBreakdownView: View {
    @EnvironmentObject var sync: SyncCoordinator
    @EnvironmentObject var supabase: SupabaseService

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

                            // ── Allostatic Portrait (E-11) ──────────────
                            // Renders only when D5 is active
                            if score.d5Allostatic != nil {
                                AllostaticPortraitCard()
                            }
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
    let previousScore: Double?
    let isActive: Bool
    let description: String
    var pendingMessage: String? = nil

    @State private var isExpanded = false

    var scoreColor: Color {
        guard let s = score else { return ChronosTheme.faint }
        if s >= 80 { return Color(red: 0.40, green: 0.82, blue: 0.50) }
        if s >= 60 { return ChronosTheme.goldLight }
        if s >= 40 { return Color(red: 1.0, green: 0.78, blue: 0.28) }
        return Color(red: 1.0, green: 0.40, blue: 0.40)
    }

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
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.098, green: 0.098, blue: 0.157),
                        Color(red: 0.071, green: 0.071, blue: 0.118)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? ChronosTheme.gold.opacity(0.18) : ChronosTheme.border, lineWidth: 1))

            if isActive {
                VStack {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.clear, ChronosTheme.gold.opacity(0.5), .clear],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(height: 1)
                        .clipShape(.rect(topLeadingRadius: 16, topTrailingRadius: 16))
                    Spacer()
                }
            }

            VStack(spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                }) {
                    HStack(spacing: 12) {
                        Text(label)
                            .font(.jost(size: 9, weight: isActive ? .medium : .light))
                            .foregroundColor(isActive ? ChronosTheme.gold : ChronosTheme.faint)
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isActive ? ChronosTheme.goldDim : ChronosTheme.ink)
                                    .overlay(RoundedRectangle(cornerRadius: 8)
                                        .stroke(isActive ? ChronosTheme.gold.opacity(0.2) : ChronosTheme.border, lineWidth: 1))
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.jost(size: 13, weight: .regular))
                                .foregroundColor(isActive ? ChronosTheme.text : ChronosTheme.muted)
                            Text(subtitle)
                                .font(.jost(size: 10, weight: .light))
                                .foregroundColor(ChronosTheme.faint)
                        }

                        Spacer()

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

                if isActive, let s = score {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ChronosTheme.faint.opacity(0.4))
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barColor)
                                .frame(width: geo.size.width * CGFloat(s / 100), height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, isExpanded ? 0 : 14)
                }

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
        .opacity(label == "D5" && !isActive ? 0.35 : 1.0)
        .opacity(label == "D4" && !isActive ? 0.60 : 1.0)
    }
}

// ─────────────────────────────────────────
// ALLOSTATIC PORTRAIT CARD  (E-11)
// 90-day D5 load curve. Renders only when D5 active.
// Lower line = less cumulative stress = better.
// ─────────────────────────────────────────

struct AllostaticPortraitCard: View {
    @EnvironmentObject var supabase: SupabaseService

    @State private var history: [(date: String, value: Double)] = []
    @State private var isLoading = true

    // Trend derived from comparing first 7 vs last 7 points
    var trend: String {
        guard history.count >= 14 else { return "Building" }
        let recent = history.suffix(7).map { $0.value }
        let older  = history.prefix(7).map { $0.value }
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg  = older.reduce(0, +)  / Double(older.count)
        let delta = recentAvg - olderAvg
        if delta > 3  { return "Increasing" }   // load going up
        if delta < -3 { return "Improving" }    // load going down
        return "Stable"
    }

    var trendColor: Color {
        switch trend {
        case "Improving":  return Color(red: 0.40, green: 0.82, blue: 0.50)
        case "Increasing": return Color(red: 1.0,  green: 0.55, blue: 0.45)
        default:           return ChronosTheme.goldLight
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color(red: 0.07, green: 0.07, blue: 0.13),
                             Color(red: 0.05, green: 0.05, blue: 0.09)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(ChronosTheme.border, lineWidth: 1))

            // Subtle gold top border
            VStack {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, ChronosTheme.gold.opacity(0.30), .clear],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .clipShape(.rect(topLeadingRadius: 16, topTrailingRadius: 16))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 14) {

                // ── Header ──
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ALLOSTATIC PORTRAIT")
                            .font(.jost(size: 9, weight: .light))
                            .foregroundColor(ChronosTheme.gold)
                            .tracking(2.5)
                        Text("90-day cumulative load")
                            .font(.cormorant(size: 18, weight: .light))
                            .foregroundColor(ChronosTheme.text)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(trend.uppercased())
                            .font(.jost(size: 9, weight: .medium))
                            .foregroundColor(trendColor)
                            .tracking(2)
                        Text("load trend")
                            .font(.jost(size: 8, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                    }
                }

                Rectangle().fill(ChronosTheme.gold.opacity(0.15)).frame(height: 1)

                // ── Curve ──
                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(ChronosTheme.gold.opacity(0.4))
                        Text("Loading portrait...")
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                    }
                    .frame(height: 80)

                } else if history.isEmpty {
                    Text("Not enough history yet — check back in a few days.")
                        .font(.jost(size: 12, weight: .light))
                        .foregroundColor(ChronosTheme.faint)
                        .lineSpacing(4)
                        .frame(height: 80, alignment: .leading)

                } else {
                    AllostaticCurve(history: history)
                        .frame(height: 80)
                }

                // ── Context note ──
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(ChronosTheme.gold.opacity(0.4))
                        .frame(width: 4, height: 4)
                        .padding(.top, 5)
                    Text("Lower is better. A descending line means your body is carrying less cumulative stress over time.")
                        .font(.jost(size: 11, weight: .light))
                        .foregroundColor(ChronosTheme.faint)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
        .task {
            guard let userId = supabase.session?.userId else {
                isLoading = false
                return
            }
            do {
                history = try await supabase.fetchAllostaticHistory(userId: userId)
            } catch {
                print("[AllostaticPortrait] load failed: \(error)")
            }
            isLoading = false
        }
    }
}

// ─────────────────────────────────────────
// ALLOSTATIC CURVE  — Canvas line chart
// D5 score is physiological resilience (higher = better).
// We invert visually so the portrait reads as a load curve:
// high D5 score → low position on chart (low load).
// ─────────────────────────────────────────

struct AllostaticCurve: View {
    let history: [(date: String, value: Double)]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let values = history.map { $0.value }
            let minV = (values.min() ?? 0) - 5
            let maxV = (values.max() ?? 100) + 5
            let range = maxV - minV
            let step = w / CGFloat(max(values.count - 1, 1))

            // Invert Y: high score (good) = bottom of chart (low load)
            let points: [CGPoint] = values.enumerated().map { i, v in
                CGPoint(
                    x: CGFloat(i) * step,
                    y: h - CGFloat((v - minV) / range) * h
                )
            }

            ZStack {
                // Fill under curve
                Canvas { ctx, size in
                    guard points.count > 1 else { return }
                    var fill = Path()
                    fill.move(to: CGPoint(x: points[0].x, y: size.height))
                    fill.addLine(to: points[0])
                    for pt in points.dropFirst() { fill.addLine(to: pt) }
                    fill.addLine(to: CGPoint(x: points.last!.x, y: size.height))
                    fill.closeSubpath()
                    ctx.fill(fill, with: .linearGradient(
                        Gradient(colors: [ChronosTheme.gold.opacity(0.10), .clear]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: 0, y: size.height)
                    ))
                }

                // Line
                Canvas { ctx, size in
                    guard points.count > 1 else { return }
                    var path = Path()
                    path.move(to: points[0])
                    for pt in points.dropFirst() { path.addLine(to: pt) }
                    ctx.stroke(path, with: .linearGradient(
                        Gradient(colors: [ChronosTheme.gold.opacity(0.35), ChronosTheme.goldLight]),
                        startPoint: CGPoint(x: 0, y: h / 2),
                        endPoint: CGPoint(x: w, y: h / 2)
                    ), lineWidth: 1.5)
                }

                // End dot
                if let last = points.last {
                    Circle()
                        .fill(ChronosTheme.goldLight)
                        .frame(width: 6, height: 6)
                        .position(last)
                }

                // Date labels — first and last
                if let first = history.first, let last = history.last {
                    VStack {
                        Spacer()
                        HStack {
                            Text(shortDate(first.date))
                                .font(.jost(size: 8, weight: .light))
                                .foregroundColor(ChronosTheme.faint)
                            Spacer()
                            Text(shortDate(last.date))
                                .font(.jost(size: 8, weight: .light))
                                .foregroundColor(ChronosTheme.faint)
                        }
                    }
                }
            }
        }
    }

    private func shortDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
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
