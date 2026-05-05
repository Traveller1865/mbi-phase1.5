// ios/MBI/MBI/Views/HorizonView.swift
// MBI Phase 1.5 — Horizon · Signal Surface
// Epic 1 Sprint 3 — Page 1 Redesign
//
// HorizonSignalView is Page 1 of HorizonModuleView.
// This file owns: HorizonSignalView, HorizonPathwayCard (+ model),
// HorizonHeader, AlphaBadge, SignalSectionHeader, HorizonSignalCardView,
// HorizonEmptyView, LaneState.
//
// What changed in Sprint 3:
//   - PathwaySection / PathwayLane replaced by three HorizonPathwayCards
//   - Score numbers removed from pathway cards entirely (hard requirement)
//   - "BASED ON TODAY'S DATA" → "READING YOUR CURRENT TRAJECTORY"
//   - ELEVATED card treatment: 6pt amber bar + glow + 1.5pt amber border (Option B)
//   - CALM card treatment: 4pt green bar, standard 1pt border
//   - Unique trajectory line + CTA per pathway per state (spec copy locked)
//   - HorizonPathwayCard data model extended with Phase 1.75 fields (all nil in Sprint 3)
//   - Duplicate CTA copy ("Keep this going — it's actively countering accumulated load.")
//     replaced with unique per-pathway CTAs per handoff §4.3.3

import SwiftUI

// ─────────────────────────────────────────
// LANE STATE
// Derived from domain score threshold only.
// CALM ≥ 70 | ELEVATED 50–69 | FLAGGED < 50
// ─────────────────────────────────────────

enum LaneState {
    case calm
    case elevated   // renamed from .active for clarity — maps to ELEVATED badge
    case flagged

    init(score: Double?) {
        guard let s = score else { self = .calm; return }
        if s >= 70      { self = .calm }
        else if s >= 50 { self = .elevated }
        else            { self = .flagged }
    }

    // Sprint 3 card treatment
    var isAlert: Bool {
        switch self {
        case .calm:              return false
        case .elevated, .flagged: return true
        }
    }

    var accentColor: Color {
        switch self {
        case .calm:              return Color(red: 0.40, green: 0.82, blue: 0.50)
        case .elevated, .flagged: return Color(red: 1.0, green: 0.75, blue: 0.35)
        }
    }

    // Accent bar width per Option B spec
    var barWidth: CGFloat {
        switch self {
        case .calm:              return 4
        case .elevated, .flagged: return 6
        }
    }

    var badgeLabel: String {
        switch self {
        case .calm:    return "CALM"
        case .elevated: return "ELEVATED"
        case .flagged:  return "FLAGGED"
        }
    }
}

// ─────────────────────────────────────────
// HORIZON PATHWAY CARD MODEL
// Sprint 3 fields are populated.
// Phase 1.75 fields are all nil — card renders identically when nil.
// Do not add display logic for Phase 1.75 fields in this sprint.
// ─────────────────────────────────────────

struct HorizonPathwayCardData: Identifiable {
    let id = UUID()

    // Sprint 3 — required
    let pathwayKey: String       // "autonomic" | "sleep" | "metabolic"
    let pathwayLabel: String     // "AUTONOMIC"
    let pathwaySubtitle: String  // "Nervous system · HRV · Heart rate"
    let score: Double?           // used only for state derivation — never displayed
    let trajectoryLine: String   // forward-facing sentence
    let ctaLine: String          // domain-specific closing line

    // Phase 1.75 — all nil in Sprint 3
    // When populated, card gains additional display logic without rebuild.
    var trajectoryLabel: String? = nil   // e.g. "Metabolic load building"
    var conditionClass: String? = nil    // e.g. "metabolic_stress_early"
    var escalationLevel: Int? = nil      // 0=none 1=self-redirect 2=monitor 3=doctor
    var confidenceGate: Double? = nil    // 0.0–1.0 min confidence for ontology output
    var daysInPattern: Int? = nil        // consecutive days pattern detected

    var state: LaneState { LaneState(score: score) }
}

// ─────────────────────────────────────────
// HORIZON SIGNAL CARD MODEL (watch / protective sections)
// Unchanged from prior sprint — kept for signal card sections below pathway cards.
// ─────────────────────────────────────────

struct HorizonSignalCard: Identifiable {
    let id = UUID()
    let metricKey: String
    let metricLabel: String
    let direction: String
    let daysCount: Int
    let isWatch: Bool
    let bodyText: String
    let ctaText: String
}

// ─────────────────────────────────────────
// HORIZON SIGNAL VIEW — Page 1
// ─────────────────────────────────────────

struct HorizonSignalView: View {
    @EnvironmentObject var sync: SyncCoordinator
    @EnvironmentObject var supabase: SupabaseService

    @State private var baselines: [String: Double] = [:]
    @State private var streaks: [String: Int] = [:]
    @State private var isLoading = true

    var body: some View {
        ZStack {
            ChronosTheme.ink.ignoresSafeArea()

            RadialGradient(
                colors: [ChronosTheme.gold.opacity(0.04), .clear],
                center: .top, startRadius: 0, endRadius: 340
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    HorizonHeader()

                    // Alpha banner — always visible, never hidden
                    AlphaBadge()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)

                    if let score = sync.dashboard?.score {

                        // ── Three Pathway Cards (Sprint 3 redesign) ──────────
                        VStack(spacing: 10) {
                            ForEach(buildPathwayCards(score: score)) { card in
                                HorizonPathwayCardView(data: card)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)

                        if isLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .scaleEffect(0.65)
                                    .tint(ChronosTheme.gold.opacity(0.4))
                                Text("Reading your signals...")
                                    .font(.jost(size: 12, weight: .light))
                                    .foregroundColor(ChronosTheme.faint)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)

                        } else {
                            let watchCards = buildWatchCards(score: score)
                            let protectiveCards = buildProtectiveCards(score: score)

                            // ── Patterns Worth Watching ──────────────────────
                            if !watchCards.isEmpty {
                                SignalSectionHeader(
                                    title: "Patterns worth watching",
                                    subtitle: "Building early. Still fully reversible.",
                                    isWatch: true
                                )
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)

                                VStack(spacing: 10) {
                                    ForEach(watchCards) { card in
                                        HorizonSignalCardView(card: card)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }

                            // ── Working In Your Favor ────────────────────────
                            SignalSectionHeader(
                                title: "Working in your favor",
                                subtitle: "These signals are actively countering load.",
                                isWatch: false
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)

                            VStack(spacing: 10) {
                                ForEach(protectiveCards) { card in
                                    HorizonSignalCardView(card: card)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 64) // extra bottom pad for page indicator clearance
                        }

                    } else {
                        HorizonEmptyView()
                            .padding(.top, 60)
                    }
                }
            }
        }
        .task {
            guard let userId = supabase.session?.userId else {
                isLoading = false
                return
            }
            await loadSignalData(userId: userId)
        }
    }

    // ─────────────────────────────────────────
    // PATHWAY CARD BUILDER
    // Sprint 3: copy is locked per handoff §4.3.3.
    // State derived from domain scores — never displayed as numbers.
    // ─────────────────────────────────────────

    private func buildPathwayCards(score: DailyScore) -> [HorizonPathwayCardData] {
        [
            autonomicCard(score: score.d1Autonomic),
            sleepCard(score: score.d2Sleep),
            metabolicCard(score: score.d3Activity)
        ]
    }

    private func autonomicCard(score: Double?) -> HorizonPathwayCardData {
        let state = LaneState(score: score)
        return HorizonPathwayCardData(
            pathwayKey: "autonomic",
            pathwayLabel: "AUTONOMIC",
            pathwaySubtitle: "Nervous system · HRV · Heart rate",
            score: score,
            trajectoryLine: state.isAlert
                ? "Your nervous system is carrying elevated load. This pattern, if sustained, compounds into systemic stress."
                : "Your nervous system is balanced. This is building resilience that compounds over time.",
            ctaLine: state.isAlert
                ? "A 10-minute recovery window today interrupts this before it sets."
                : "Keep this going — autonomic balance is your body's primary defense against load accumulation."
        )
    }

    private func sleepCard(score: Double?) -> HorizonPathwayCardData {
        let state = LaneState(score: score)
        return HorizonPathwayCardData(
            pathwayKey: "sleep",
            pathwayLabel: "SLEEP",
            pathwaySubtitle: "Recovery · Duration · Quality",
            score: score,
            trajectoryLine: state.isAlert
                ? "Your recovery window is incomplete. Sleep debt compounds faster than it resolves."
                : "Your body is completing its repair window. Sleep quality is the foundation everything else builds on.",
            ctaLine: state.isAlert
                ? "Protecting tonight's sleep window is the highest-impact action available to you right now."
                : "Keep this going — consistent sleep quality is the single highest-leverage signal in your health trajectory."
        )
    }

    private func metabolicCard(score: Double?) -> HorizonPathwayCardData {
        let state = LaneState(score: score)
        return HorizonPathwayCardData(
            pathwayKey: "metabolic",
            pathwayLabel: "METABOLIC",
            pathwaySubtitle: "Activity · Movement · Energy",
            score: score,
            trajectoryLine: state.isAlert
                ? "Your activity load has been reduced. This pattern, if it continues, begins compounding metabolic load upstream."
                : "Your activity and movement signals are balanced. This is actively protecting your metabolic trajectory.",
            ctaLine: state.isAlert
                ? "A 20-minute walk today keeps this from compounding. Early redirection is still fully available."
                : "Keep this going — sustained movement consistency is your primary metabolic upstream defense."
        )
    }

    // ─────────────────────────────────────────
    // DATA LOADING
    // ─────────────────────────────────────────

    private func loadSignalData(userId: String) async {
        do {
            baselines = try await supabase.fetchLatestBaselines(userId: userId)
        } catch {
            print("[HorizonSignalView] baselines load failed: \(error)")
        }

        // Streak fetch is best-effort — failure does not block signal card rendering.
        // Cards render with daysCount = 1 if streak is unavailable.
        if let score = sync.dashboard?.score {
            do {
                let d1Streak = try await supabase.fetchDriverStreak(
                    userId: userId, todayDriver: score.driver1)
                streaks[score.driver1] = d1Streak
            } catch {
                print("[HorizonSignalView] d1 streak load failed (non-blocking): \(error)")
            }
            do {
                let d2Streak = try await supabase.fetchDriverStreak(
                    userId: userId, todayDriver: score.driver2)
                streaks[score.driver2] = d2Streak
            } catch {
                print("[HorizonSignalView] d2 streak load failed (non-blocking): \(error)")
            }
        }

        isLoading = false
    }

    // ─────────────────────────────────────────
    // WATCH CARD BUILDER (unchanged logic)
    // ─────────────────────────────────────────

    private func buildWatchCards(score: DailyScore) -> [HorizonSignalCard] {
        var cards: [HorizonSignalCard] = []
        let candidates: [(key: String, label: String, metricKey: String, score: Double?)] = [
            ("autonomic", "Autonomic Recovery",   "hrv",            score.d1Autonomic),
            ("sleep",     "Sleep Recovery",       "sleep_duration", score.d2Sleep),
            ("activity",  "Activity Load",        "steps",          score.d3Activity),
        ]
        for c in candidates {
            let state = LaneState(score: c.score)
            let streak = streaks[c.metricKey] ?? 0
            guard state.isAlert || streak >= 3 else { continue }
            let days = max(streak, 1)
            let direction: String = {
                switch c.key {
                case "autonomic": return "suppressed"
                case "sleep":     return "shortened"
                case "activity":  return "reduced"
                default:          return "elevated"
                }
            }()
            cards.append(HorizonSignalCard(
                metricKey: c.metricKey,
                metricLabel: c.label,
                direction: direction,
                daysCount: days,
                isWatch: true,
                bodyText: "Your \(c.label.lowercased()) has been \(direction) for \(days) \(days == 1 ? "day" : "days"). This pattern is early and still fully reversible.",
                ctaText: watchCTA(for: c.key)
            ))
            if cards.count >= 3 { break }
        }
        return cards
    }

    // ─────────────────────────────────────────
    // PROTECTIVE CARD BUILDER
    // Sprint 3: unique CTA per pathway (fixes duplicate copy from prior sprint)
    // ─────────────────────────────────────────

    private func buildProtectiveCards(score: DailyScore) -> [HorizonSignalCard] {
        var cards: [HorizonSignalCard] = []
        let candidates: [(key: String, label: String, metricKey: String, score: Double?)] = [
            ("autonomic", "Autonomic Recovery",   "hrv",            score.d1Autonomic),
            ("sleep",     "Sleep Recovery",       "sleep_duration", score.d2Sleep),
            ("activity",  "Activity Load",        "steps",          score.d3Activity),
        ]
        for c in candidates {
            guard LaneState(score: c.score) == .calm else { continue }
            cards.append(HorizonSignalCard(
                metricKey: c.metricKey,
                metricLabel: c.label,
                direction: "above baseline",
                daysCount: 1,
                isWatch: false,
                bodyText: protectiveBody(for: c.key),
                ctaText: protectiveCTA(for: c.key)
            ))
        }
        // Fallback: if no domain is calm, surface the strongest
        if cards.isEmpty, let best = candidates.filter({ $0.score != nil })
            .max(by: { ($0.score ?? 0) < ($1.score ?? 0) }) {
            cards.append(HorizonSignalCard(
                metricKey: best.metricKey,
                metricLabel: best.label,
                direction: "leading",
                daysCount: 1,
                isWatch: false,
                bodyText: "Your \(best.label.lowercased()) is your strongest signal right now. Building on this is the fastest path back to full recovery.",
                ctaText: "One good session here shifts the trajectory."
            ))
        }
        return cards
    }

    // ─────────────────────────────────────────
    // COPY HELPERS
    // ─────────────────────────────────────────

    private func watchCTA(for key: String) -> String {
        switch key {
        case "autonomic": return "A 10-minute recovery window today interrupts this before it sets."
        case "sleep":     return "Protecting tonight's sleep window is the highest-impact action available to you right now."
        case "activity":  return "A 20-minute walk today keeps this from compounding. Early redirection is still fully available."
        default:          return "Small, consistent actions are what move this signal."
        }
    }

    private func protectiveBody(for key: String) -> String {
        switch key {
        case "autonomic":
            return "Your autonomic recovery is working in your favor. Strong HRV means your nervous system is balanced and adaptive — this is actively building your resilience."
        case "sleep":
            return "Your sleep recovery is working in your favor. Your body is completing its repair window — this is the foundation everything else builds on."
        case "activity":
            return "Your activity load is working in your favor. Consistent movement is keeping your metabolic and cardiovascular systems engaged and resilient."
        default:
            return "This signal is working in your favor. It is actively countering accumulated load."
        }
    }

    private func protectiveCTA(for key: String) -> String {
        switch key {
        case "autonomic": return "Keep this going — autonomic balance is your body's primary defense against load accumulation."
        case "sleep":     return "Keep this going — consistent sleep quality is the single highest-leverage signal in your health trajectory."
        case "activity":  return "Keep this going — sustained movement consistency is your primary metabolic upstream defense."
        default:          return "Keep this going — it's actively countering accumulated load."
        }
    }
}

// ─────────────────────────────────────────
// HORIZON PATHWAY CARD VIEW
// Option B treatment:
//   CALM: 4pt green bar, 1pt border white@10%
//   ELEVATED/FLAGGED: 6pt amber bar + glow, 1.5pt amber border@50%
// Score numbers: NEVER rendered.
// ─────────────────────────────────────────

struct HorizonPathwayCardView: View {
    let data: HorizonPathwayCardData

    private var state: LaneState { data.state }
    private var accent: Color { state.accentColor }

    var body: some View {
        ZStack(alignment: .leading) {
            // Card background — dark surface, no fill change between states
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.09, green: 0.09, blue: 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            state.isAlert
                                ? accent.opacity(0.50)
                                : Color.white.opacity(0.10),
                            lineWidth: state.isAlert ? 1.5 : 1.0
                        )
                )

            HStack(alignment: .top, spacing: 14) {

                // Left accent bar — width and glow differ by state
                if state.isAlert {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accent)
                        .frame(width: state.barWidth)
                        .padding(.vertical, 6)
                        .shadow(color: accent.opacity(0.4), radius: 4, x: -2, y: 0)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accent)
                        .frame(width: state.barWidth)
                        .padding(.vertical, 6)
                }

                VStack(alignment: .leading, spacing: 10) {

                    // Header row: pathway name + badge
                    HStack(alignment: .center, spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(data.pathwayLabel)
                                .font(.jost(size: 11, weight: .medium))
                                .foregroundColor(ChronosTheme.text)
                                .tracking(1.5)
                            Text(data.pathwaySubtitle)
                                .font(.jost(size: 10, weight: .light))
                                .foregroundColor(ChronosTheme.faint)
                        }
                        Spacer()
                        // State badge — outlined style for ELEVATED, filled style for CALM
                        Text(state.badgeLabel)
                            .font(.jost(size: 8, weight: .medium))
                            .foregroundColor(accent)
                            .tracking(1.5)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(accent.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                accent.opacity(state.isAlert ? 0.5 : 0.25),
                                                lineWidth: state.isAlert ? 1 : 0
                                            )
                                    )
                            )
                    }

                    Rectangle()
                        .fill(accent.opacity(0.12))
                        .frame(height: 1)

                    // Trajectory line — forward-facing, amber tint when alert
                    Text(data.trajectoryLine)
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(
                            state.isAlert
                                ? accent.opacity(0.90)
                                : Color(red: 0.965, green: 0.953, blue: 0.920).opacity(0.85)
                        )
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    // CTA line — domain-specific, never duplicate across pathways
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: state.isAlert
                              ? "arrow.triangle.turn.up.right.diamond"
                              : "checkmark.circle")
                            .font(.system(size: 10, weight: .light))
                            .foregroundColor(accent.opacity(0.7))
                            .padding(.top, 1)
                        Text(data.ctaLine)
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(accent.opacity(0.85))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(.vertical, 16)
            .padding(.leading, 14)
        }
    }
}

// ─────────────────────────────────────────
// HORIZON HEADER
// "BASED ON TODAY'S DATA" → "READING YOUR CURRENT TRAJECTORY"
// All other copy unchanged — locked per handoff §4.3.1
// ─────────────────────────────────────────

struct HorizonHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HORIZON")
                .font(.jost(size: 10, weight: .light))
                .foregroundColor(ChronosTheme.gold)
                .tracking(3)

            Text("What's building upstream.")
                .font(.cormorant(size: 32, weight: .light))
                .foregroundColor(ChronosTheme.text)

            Text("Patterns today that become conditions tomorrow — surfaced early, while they're still reversible.")
                .font(.jost(size: 13, weight: .light))
                .foregroundColor(ChronosTheme.muted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 20)
    }
}

// ─────────────────────────────────────────
// ALPHA BADGE — unchanged, always visible
// ─────────────────────────────────────────

struct AlphaBadge: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(ChronosTheme.gold.opacity(0.5))
                .frame(width: 5, height: 5)
            Text("Alpha · Signal deepens with your baseline")
                .font(.jost(size: 10, weight: .light))
                .foregroundColor(ChronosTheme.gold.opacity(0.7))
                .tracking(0.5)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(ChronosTheme.goldDim.opacity(0.4))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .stroke(ChronosTheme.gold.opacity(0.15), lineWidth: 1))
        )
    }
}

// ─────────────────────────────────────────
// SIGNAL SECTION HEADER — unchanged
// ─────────────────────────────────────────

struct SignalSectionHeader: View {
    let title: String
    let subtitle: String
    let isWatch: Bool

    var accentColor: Color {
        isWatch
            ? Color(red: 1.0, green: 0.75, blue: 0.35)
            : Color(red: 0.40, green: 0.82, blue: 0.50)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 5, height: 5)
                Text(title.uppercased())
                    .font(.jost(size: 9, weight: .medium))
                    .foregroundColor(accentColor)
                    .tracking(2)
            }
            Text(subtitle)
                .font(.jost(size: 12, weight: .light))
                .foregroundColor(ChronosTheme.faint)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ─────────────────────────────────────────
// HORIZON SIGNAL CARD VIEW — unchanged
// ─────────────────────────────────────────

struct HorizonSignalCardView: View {
    let card: HorizonSignalCard

    var accentColor: Color {
        card.isWatch
            ? Color(red: 1.0, green: 0.75, blue: 0.35)
            : Color(red: 0.40, green: 0.82, blue: 0.50)
    }

    var cardBackground: Color {
        card.isWatch
            ? Color(red: 0.14, green: 0.10, blue: 0.06)
            : Color(red: 0.06, green: 0.12, blue: 0.08)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [cardBackground, ChronosTheme.ink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(accentColor.opacity(0.20), lineWidth: 1))

            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(
                        colors: [accentColor.opacity(0.5), accentColor],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .frame(width: 3)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(card.metricLabel.uppercased())
                            .font(.jost(size: 9, weight: .medium))
                            .foregroundColor(accentColor)
                            .tracking(2)
                        Spacer()
                        if card.isWatch && card.daysCount > 1 {
                            Text("building for \(card.daysCount) days".uppercased())
                                .font(.jost(size: 8, weight: .light))
                                .foregroundColor(accentColor.opacity(0.6))
                                .tracking(1)
                        }
                    }
                    Rectangle()
                        .fill(accentColor.opacity(0.15))
                        .frame(height: 1)
                    Text(card.bodyText)
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(Color(red: 0.965, green: 0.953, blue: 0.920).opacity(0.85))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: card.isWatch
                              ? "arrow.triangle.turn.up.right.diamond"
                              : "checkmark.circle")
                            .font(.system(size: 10, weight: .light))
                            .foregroundColor(accentColor.opacity(0.7))
                            .padding(.top, 1)
                        Text(card.ctaText)
                            .font(.jost(size: 12, weight: .light))
                            .foregroundColor(accentColor.opacity(0.85))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
        }
    }
}

// ─────────────────────────────────────────
// EMPTY STATE — unchanged
// ─────────────────────────────────────────

struct HorizonEmptyView: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .stroke(ChronosTheme.gold.opacity(0.10), lineWidth: 1)
                    .frame(width: 64, height: 64)
                Image(systemName: "scope")
                    .font(.system(size: 20, weight: .ultraLight))
                    .foregroundColor(ChronosTheme.gold.opacity(0.35))
            }
            Text("No signal yet")
                .font(.cormorant(size: 24))
                .foregroundColor(ChronosTheme.muted)
            Text("Horizon reads your domain scores.\nSync your Apple Watch data to activate.")
                .font(.jost(size: 13, weight: .light))
                .foregroundColor(ChronosTheme.faint)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .padding(.horizontal, 48)
        }
    }
}
