// ios/MBI/MBI/Views/DomainBreakdownView.swift
// MBI Phase 1.5 — Domain Breakdown · Sprint 3B
//
// Sprint 3B additions:
//   §3.2  System Pattern Block — deterministic detection + narrate-domains-pattern narrative
//   §3.3  Section Divider — "SYSTEM BREAKDOWN" between pattern block and cards
//   §3.4  Role tag system — DRIVER / BUFFER / ELEVATED / WATCH / STABLE / BUILDING
//   §3.4  Card border treatment — rose for DRIVER, green for BUFFER
//   §3.4  Score color system — 4-tier spec, no score below 60 renders green
//   §3.4  Semantic progress bar — score / 30d domain baseline avg, capped 1.0
//   §3.4  Conflict badge (collapsed) — cross-domain tension, single line
//   §3.4  Expanded card content — real metric values + baseline + observational line
//   §3.5  Building state copy — D4 "Day X of 7 · pattern building" / D5 variant
//   §3.6  Synthesis line — session-cached with pattern narrative, below D5
//   Tap affordance — chevron only; full-card tap NOT wired (Phase 2)

import SwiftUI

// ─────────────────────────────────────────
// PATTERN DETECTION — DETERMINISTIC LAYER
// All pattern logic computed here before any Claude call.
// Claude receives structured output and returns copy only.
// ─────────────────────────────────────────

enum DomainPattern: String {
    case loadOutpacingRecovery   = "load_outpacing_recovery"
    case hiddenStressSignal      = "hidden_stress_signal"
    case sleepProtectingRecovery = "sleep_protecting_recovery"
    case systemsInAlignment      = "systems_in_alignment"
    case recoveryUnderPressure   = "recovery_under_pressure"
    case defaultPattern          = "default"
}

enum DomainRole: String {
    case driver   = "DRIVER"
    case buffer   = "BUFFER"
    case elevated = "ELEVATED"
    case watch    = "WATCH"
    case stable   = "STABLE"
    case building = "BUILDING"
}

struct PatternResult {
    let pattern: DomainPattern
    let driverDomain: String        // e.g. "D1"
    let bufferDomain: String?
    let watchDomain: String?
    let roles: [String: DomainRole] // keyed by "D1"..."D5"
}

struct ConflictResult {
    let hasDomain: String           // e.g. "D2"
    let withDomain: String          // e.g. "D1"
    let conflictType: String        // e.g. "compensation"
    let badgeText: String           // one-line collapsed badge
}

struct PatternEngine {

    static func detect(
        d1: Double?, d2: Double?, d3: Double?,
        d4: Double?, d5: Double?,
        historyDayCount: Int
    ) -> PatternResult {

        // Use 0 for nil/building domains in pattern logic
        let v1 = d1 ?? 0
        let v2 = d2 ?? 0
        let v3 = d3 ?? 0
        let v4 = d4 ?? 0

        let d4Active = historyDayCount >= 7
        let d5Active = historyDayCount >= 30

        // Active domain scores only
        var activeDomains: [(label: String, score: Double)] = [
            ("D1", v1), ("D2", v2), ("D3", v3)
        ]
        if d4Active, let s = d4 { activeDomains.append(("D4", s)) }
        if d5Active, let s = d5 { activeDomains.append(("D5", s)) }

        // Determine pattern
        let pattern: DomainPattern
        var driverDomain = "D1"
        var bufferDomain: String? = nil
        var watchDomain: String? = nil

        if v3 >= 80 && v1 < 65 {
            pattern = .loadOutpacingRecovery
            driverDomain = "D3"
            bufferDomain = v2 >= 75 ? "D2" : nil
            watchDomain = "D1"

        } else if d4Active && v4 < 65 && v2 >= 75 && v1 < 70 {
            pattern = .hiddenStressSignal
            driverDomain = "D4"
            bufferDomain = "D2"
            watchDomain = "D1"

        } else if v2 >= 80 && v1 < 70 {
            pattern = .sleepProtectingRecovery
            driverDomain = "D2"
            bufferDomain = nil
            watchDomain = "D1"

        } else if activeDomains.count >= 3 &&
                  activeDomains.allSatisfy({ $0.score >= 65 }) {
            let scores = activeDomains.map { $0.score }
            let maxS = scores.max() ?? 0
            let minS = scores.min() ?? 0
            if maxS - minS <= 15 {
                pattern = .systemsInAlignment
                // Driver = highest active domain
                driverDomain = activeDomains.max(by: { $0.score < $1.score })?.label ?? "D1"
            } else {
                pattern = .defaultPattern
                driverDomain = activeDomains.max(by: { $0.score < $1.score })?.label ?? "D1"
            }

        } else if v1 < 60 && d4Active && v4 < 65 {
            pattern = .recoveryUnderPressure
            driverDomain = v1 <= v4 ? "D1" : "D4"
            watchDomain = driverDomain == "D1" ? "D4" : "D1"

        } else {
            pattern = .defaultPattern
            // Most deviated domain as primary driver
            let sorted = activeDomains.sorted { $0.score < $1.score }
            driverDomain = sorted.first?.label ?? "D1"
        }

        // Assign roles
        var roles: [String: DomainRole] = [:]

        // D4 building
        if !d4Active {
            roles["D4"] = .building
        }
        // D5 building
        if !d5Active {
            roles["D5"] = .building
        }

        // Active domain roles
        for item in activeDomains {
            if item.label == driverDomain {
                roles[item.label] = .driver
            } else if let buf = bufferDomain, item.label == buf {
                roles[item.label] = .buffer
            } else if let watch = watchDomain, item.label == watch {
                roles[item.label] = .watch
            } else if item.score >= 80 {
                roles[item.label] = .elevated
            } else {
                roles[item.label] = .stable
            }
        }

        return PatternResult(
            pattern: pattern,
            driverDomain: driverDomain,
            bufferDomain: bufferDomain,
            watchDomain: watchDomain,
            roles: roles
        )
    }

    // ── Fallback synthesis line — shown when narrate-domains-pattern is unavailable ──
    // Returns a deterministic one-sentence summary so the synthesis card always renders.

    static func fallbackSynthesisLine(for pattern: DomainPattern) -> String {
        switch pattern {
        case .loadOutpacingRecovery:
            return "Your body is working hard — but recovery hasn't caught up yet"
        case .hiddenStressSignal:
            return "Sleep is holding steady while stress builds quietly underneath"
        case .sleepProtectingRecovery:
            return "Sleep is doing the heavy lifting while your nervous system rebuilds"
        case .systemsInAlignment:
            return "All systems are moving in the same direction today"
        case .recoveryUnderPressure:
            return "Your body is managing load while recovery works to keep pace"
        case .defaultPattern:
            return "Your systems are active — one domain is leading today's pattern"
        }
    }

    // ── Conflict detection ───────────────────────────────────────────────────
    // Returns conflicts for cards that should show a collapsed badge.

    static func detectConflicts(
        d1: Double?, d2: Double?, d3: Double?, d4: Double?,
        historyDayCount: Int
    ) -> [ConflictResult] {
        var conflicts: [ConflictResult] = []

        let v1 = d1 ?? 0
        let v2 = d2 ?? 0
        let v3 = d3 ?? 0
        let d4Active = historyDayCount >= 7

        // Sleep strong but autonomic hasn't followed
        if let _ = d2, let _ = d1, v2 >= 75 && v1 < 65 {
            conflicts.append(ConflictResult(
                hasDomain: "D2",
                withDomain: "D1",
                conflictType: "compensation",
                badgeText: "Sleep strong — but autonomic recovery hasn't followed yet"
            ))
        }

        // Activity elevated but recovery hasn't kept pace
        if let _ = d3, let _ = d1, v3 >= 80 && v1 < 70 {
            conflicts.append(ConflictResult(
                hasDomain: "D3",
                withDomain: "D1",
                conflictType: "suppression",
                badgeText: "Activity elevated — recovery hasn't kept pace"
            ))
        }

        // Stress building while sleep holding
        if d4Active, let _ = d4, let _ = d2, (d4 ?? 0) < 65 && v2 >= 75 {
            conflicts.append(ConflictResult(
                hasDomain: "D4",
                withDomain: "D2",
                conflictType: "suppression",
                badgeText: "Stress pattern building despite good sleep"
            ))
        }

        return conflicts
    }
}

// ─────────────────────────────────────────
// NARRATIVE MODELS
// Returned by narrate-domains-pattern and narrate-domain-expanded.
// ─────────────────────────────────────────

struct DomainPatternNarrative {
    let patternTitle: String       // max 6 words, no punctuation
    let patternBody: String        // max 80 tokens, 2-3 sentences
    let synthesisLine: String      // max 30 tokens, 1 sentence
}

struct DomainExpandedNarrative {
    let observationalLine: String  // max 40 tokens
    let conflictElaboration: String? // max 60 tokens or nil
}

// ─────────────────────────────────────────
// DOMAIN BREAKDOWN VIEW
// ─────────────────────────────────────────

struct DomainBreakdownView: View {
    @EnvironmentObject var sync: SyncCoordinator
    @EnvironmentObject var supabase: SupabaseService

    @State private var historyDayCount: Int = 0
    @State private var rawMetrics: DomainRawMetrics = .empty
    @State private var domainBaselines: DomainBaselines = .empty

    // Pattern narrative — session-cached on first load
    @State private var patternNarrative: DomainPatternNarrative? = nil
    @State private var patternNarrativeLoading: Bool = false

    // Expanded narratives — keyed by domain label, generated on expand
    @State private var expandedNarratives: [String: DomainExpandedNarrative] = [:]

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

                        let patternResult = PatternEngine.detect(
                            d1: score.d1Autonomic,
                            d2: score.d2Sleep,
                            d3: score.d3Activity,
                            d4: score.d4Stress,
                            d5: score.d5Allostatic,
                            historyDayCount: historyDayCount
                        )

                        let conflicts = PatternEngine.detectConflicts(
                            d1: score.d1Autonomic,
                            d2: score.d2Sleep,
                            d3: score.d3Activity,
                            d4: score.d4Stress,
                            historyDayCount: historyDayCount
                        )

                        VStack(spacing: 0) {

                            // §3.2 System Pattern Block
                            SystemPatternBlock(
                                patternResult: patternResult,
                                narrative: patternNarrative,
                                isLoading: patternNarrativeLoading
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)

                            // §3.3 Section Divider
                            SectionDividerLabel(text: "SYSTEM BREAKDOWN")
                                .padding(.horizontal, 20)
                                .padding(.bottom, 14)

                            // §3.4 Domain Cards
                            VStack(spacing: 10) {

                                ChronosDomainCard(
                                    label: "D1",
                                    title: "Autonomic Recovery",
                                    subtitle: "HRV · Resting HR",
                                    score: score.d1Autonomic,
                                    isActive: true,
                                    role: patternResult.roles["D1"] ?? .stable,
                                    conflict: conflicts.first(where: { $0.hasDomain == "D1" }),
                                    domainBaseline: domainBaselines.d1Autonomic,
                                    rawMetrics: rawMetrics,
                                    expandedNarrative: expandedNarratives["D1"],
                                    onExpandRequest: { fetchExpandedNarrative(domain: "D1", score: score.d1Autonomic) }
                                )

                                ChronosDomainCard(
                                    label: "D2",
                                    title: "Sleep Recovery",
                                    subtitle: "Duration · Quality",
                                    score: score.d2Sleep,
                                    isActive: true,
                                    role: patternResult.roles["D2"] ?? .stable,
                                    conflict: conflicts.first(where: { $0.hasDomain == "D2" }),
                                    domainBaseline: domainBaselines.d2Sleep,
                                    rawMetrics: rawMetrics,
                                    expandedNarrative: expandedNarratives["D2"],
                                    onExpandRequest: { fetchExpandedNarrative(domain: "D2", score: score.d2Sleep) }
                                )

                                ChronosDomainCard(
                                    label: "D3",
                                    title: "Activity Load",
                                    subtitle: "Steps · Active min",
                                    score: score.d3Activity,
                                    isActive: true,
                                    role: patternResult.roles["D3"] ?? .stable,
                                    conflict: conflicts.first(where: { $0.hasDomain == "D3" }),
                                    domainBaseline: domainBaselines.d3Activity,
                                    rawMetrics: rawMetrics,
                                    expandedNarrative: expandedNarratives["D3"],
                                    onExpandRequest: { fetchExpandedNarrative(domain: "D3", score: score.d3Activity) }
                                )

                                ChronosDomainCard(
                                    label: "D4",
                                    title: "Inferred Stress",
                                    subtitle: "7-day pattern",
                                    score: score.d4Stress,
                                    isActive: historyDayCount >= 7,
                                    role: patternResult.roles["D4"] ?? .building,
                                    conflict: conflicts.first(where: { $0.hasDomain == "D4" }),
                                    domainBaseline: domainBaselines.d4Stress,
                                    rawMetrics: rawMetrics,
                                    expandedNarrative: expandedNarratives["D4"],
                                    buildingMessage: historyDayCount < 7
                                        ? "Day \(historyDayCount) of 7 · pattern building"
                                        : nil,
                                    onExpandRequest: { fetchExpandedNarrative(domain: "D4", score: score.d4Stress) }
                                )

                                ChronosDomainCard(
                                    label: "D5",
                                    title: "Allostatic Trend",
                                    subtitle: "30-day composite",
                                    score: score.d5Allostatic,
                                    isActive: historyDayCount >= 30,
                                    role: patternResult.roles["D5"] ?? .building,
                                    conflict: nil,
                                    domainBaseline: domainBaselines.d5Allostatic,
                                    rawMetrics: rawMetrics,
                                    expandedNarrative: expandedNarratives["D5"],
                                    buildingMessage: historyDayCount < 30
                                        ? "Day \(historyDayCount) of 30 · building your long-arc baseline"
                                        : nil,
                                    onExpandRequest: { fetchExpandedNarrative(domain: "D5", score: score.d5Allostatic) }
                                )

                                // §3.6 Synthesis Line — below D5, above Allostatic Portrait
                                // Shows narrative synthesis when available, fallback when Edge Fn 404
                                let synthesisText = patternNarrative?.synthesisLine
                                    ?? PatternEngine.fallbackSynthesisLine(for: patternResult.pattern)
                                SynthesisLineCard(text: synthesisText)
                                    .padding(.top, 4)

                                // ── Allostatic Portrait (E-11) — unchanged ──
                                if score.d5Allostatic != nil {
                                    AllostaticPortraitCard()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 48)
                        }

                    } else {
                        DomainsEmptyView()
                            .padding(.top, 60)
                    }
                }
            }
        }
        .task {
            guard let userId = supabase.session?.userId else { return }

            async let dayCount = supabase.fetchHistoryDayCount(userId: userId)
            async let inputs   = supabase.fetchLatestDailyInputs(userId: userId)
            async let bases    = supabase.fetchDomainBaselines(userId: userId)

            historyDayCount  = (try? await dayCount) ?? 0
            rawMetrics       = (try? await inputs) ?? .empty
            domainBaselines  = (try? await bases) ?? .empty

            // Fetch pattern narrative after data loads — session-cached
            if let score = sync.dashboard?.score {
                await fetchPatternNarrative(score: score)
            }
        }
    }

    // ── Narrative fetches ────────────────────────────────────────────────────

    private func fetchPatternNarrative(score: DailyScore) async {
        guard patternNarrative == nil else { return }  // session cache — don't re-fetch
        patternNarrativeLoading = true

        let pattern = PatternEngine.detect(
            d1: score.d1Autonomic, d2: score.d2Sleep, d3: score.d3Activity,
            d4: score.d4Stress, d5: score.d5Allostatic,
            historyDayCount: historyDayCount
        )

        let payload: [String: Any] = [
            "pattern_type":    pattern.pattern.rawValue,
            "driver_domain":   pattern.driverDomain,
            "buffer_domain":   pattern.bufferDomain as Any,
            "watch_domain":    pattern.watchDomain as Any,
            "domain_scores":   [
                "d1": score.d1Autonomic as Any,
                "d2": score.d2Sleep as Any,
                "d3": score.d3Activity as Any,
                "d4": score.d4Stress as Any,
                "d5": score.d5Allostatic as Any
            ],
            "days_of_history": historyDayCount
        ]

        do {
            let result = try await supabase.callDomainEdgeFunction(
                url: Config.narrateDomainsPatternURL,
                body: payload
            )
            if let title = result["pattern_title"] as? String,
               let body  = result["pattern_body"] as? String,
               let synth = result["synthesis_line"] as? String {
                patternNarrative = DomainPatternNarrative(
                    patternTitle: title,
                    patternBody: body,
                    synthesisLine: synth
                )
            }
        } catch {
            print("[DomainBreakdownView] narrate-domains-pattern failed: \(error)")
        }
        patternNarrativeLoading = false
    }

    private func fetchExpandedNarrative(domain: String, score: Double?) {
        guard expandedNarratives[domain] == nil else { return }
        guard let score = score else { return }

        let conflicts = PatternEngine.detectConflicts(
            d1: sync.dashboard?.score.d1Autonomic,
            d2: sync.dashboard?.score.d2Sleep,
            d3: sync.dashboard?.score.d3Activity,
            d4: sync.dashboard?.score.d4Stress,
            historyDayCount: historyDayCount
        )
        let conflict = conflicts.first(where: { $0.hasDomain == domain })

        let metricValues   = rawMetricValues(for: domain)
        let baselineValues = rawBaselineValues(for: domain)

        var payload: [String: Any] = [
            "domain":          domain,
            "score":           score,
            "metric_values":   metricValues,
            "baseline_values": baselineValues
        ]
        if let c = conflict {
            payload["conflict_domain"] = c.withDomain
            payload["conflict_type"]   = c.conflictType
        }

        Task {
            do {
                let result = try await supabase.callDomainEdgeFunction(
                    url: Config.narrateDomainExpandedURL,
                    body: payload
                )
                if let line = result["observational_line"] as? String {
                    let elab = result["conflict_elaboration"] as? String
                    expandedNarratives[domain] = DomainExpandedNarrative(
                        observationalLine: line,
                        conflictElaboration: elab
                    )
                }
            } catch {
                print("[DomainBreakdownView] narrate-domain-expanded \(domain) failed: \(error)")
            }
        }
    }

    // ── Metric/baseline value maps for Edge Function payload ────────────────

    private func rawMetricValues(for domain: String) -> [String: Double?] {
        switch domain {
        case "D1": return ["hrv_ms": rawMetrics.hrv_ms, "resting_hr_bpm": rawMetrics.resting_hr_bpm]
        case "D2": return ["sleep_duration_hrs": rawMetrics.sleep_duration_hrs, "sleep_efficiency_pct": rawMetrics.sleep_efficiency_pct]
        case "D3": return ["steps": rawMetrics.steps, "active_minutes": rawMetrics.active_minutes]
        case "D4": return [:]  // D4 has no raw input metrics
        case "D5": return [:]  // D5 is composite only
        default:   return [:]
        }
    }

    private func rawBaselineValues(for domain: String) -> [String: Double?] {
        // Domain-level baseline — the same value used for the progress bar
        switch domain {
        case "D1": return ["d1_baseline": domainBaselines.d1Autonomic]
        case "D2": return ["d2_baseline": domainBaselines.d2Sleep]
        case "D3": return ["d3_baseline": domainBaselines.d3Activity]
        case "D4": return ["d4_baseline": domainBaselines.d4Stress]
        case "D5": return ["d5_baseline": domainBaselines.d5Allostatic]
        default:   return [:]
        }
    }
}

// ─────────────────────────────────────────
// HEADER — unchanged from prior implementation
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
// SYSTEM PATTERN BLOCK  §3.2
// Leads the screen. Gold border treatment.
// Designed with expandable architecture — do not couple height to current content.
// ─────────────────────────────────────────

struct SystemPatternBlock: View {
    let patternResult: PatternResult
    let narrative: DomainPatternNarrative?
    let isLoading: Bool

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.11, green: 0.10, blue: 0.17),
                        Color(red: 0.08, green: 0.07, blue: 0.13)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(ChronosTheme.gold.opacity(0.35), lineWidth: 1)
                )

            // Gold top border
            VStack {
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, ChronosTheme.gold.opacity(0.6), .clear],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(height: 1)
                    .clipShape(.rect(topLeadingRadius: 16, topTrailingRadius: 16))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 14) {

                // Eyebrow
                Text("TODAY'S SYSTEM PATTERN")
                    .font(.jost(size: 9, weight: .light))
                    .foregroundColor(ChronosTheme.gold)
                    .tracking(3)

                if isLoading {
                    // Loading state — skeleton
                    VStack(alignment: .leading, spacing: 8) {
                        skeletonLine(width: 160, height: 14)
                        skeletonLine(width: .infinity, height: 10)
                        skeletonLine(width: 220, height: 10)
                    }
                } else if let n = narrative {
                    // Pattern title
                    Text(n.patternTitle)
                        .font(.cormorant(size: 22, weight: .light))
                        .foregroundColor(ChronosTheme.text)

                    // Pattern body
                    Text(n.patternBody)
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                } else {
                    // Fallback — show pattern label while narrative loads or if Edge Fn unavailable
                    Text(patternFallbackTitle(patternResult.pattern))
                        .font(.cormorant(size: 22, weight: .light))
                        .foregroundColor(ChronosTheme.text)
                }

                // Role pills — only show applicable roles
                let pills = rolePills(from: patternResult)
                if !pills.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(pills, id: \.0) { label, domain in
                            RolePill(label: label, domain: domain)
                        }
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
            .padding(20)
        }
    }

    private func rolePills(from result: PatternResult) -> [(String, String)] {
        var pills: [(String, String)] = []
        if let driverLabel = result.roles.first(where: { $0.value == .driver })?.key {
            pills.append(("PRIMARY DRIVER", driverLabel))
        }
        if let bufferLabel = result.roles.first(where: { $0.value == .buffer })?.key {
            pills.append(("PROTECTING", bufferLabel))
        }
        if let watchLabel = result.roles.first(where: { $0.value == .watch })?.key {
            pills.append(("WATCH", watchLabel))
        }
        return pills
    }

    private func patternFallbackTitle(_ pattern: DomainPattern) -> String {
        switch pattern {
        case .loadOutpacingRecovery:   return "Load outpacing recovery"
        case .hiddenStressSignal:      return "Hidden stress signal"
        case .sleepProtectingRecovery: return "Sleep protecting recovery"
        case .systemsInAlignment:      return "Systems in alignment"
        case .recoveryUnderPressure:   return "Recovery under pressure"
        case .defaultPattern:          return "System read"
        }
    }

    @ViewBuilder
    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        if width == .infinity {
            RoundedRectangle(cornerRadius: 3)
                .fill(ChronosTheme.faint.opacity(0.15))
                .frame(maxWidth: .infinity)
                .frame(height: height)
        } else {
            RoundedRectangle(cornerRadius: 3)
                .fill(ChronosTheme.faint.opacity(0.15))
                .frame(width: width, height: height)
        }
    }
}

struct RolePill: View {
    let label: String
    let domain: String

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .font(.jost(size: 8, weight: .medium))
                .foregroundColor(ChronosTheme.gold.opacity(0.75))
                .tracking(1.5)
            Text("·")
                .font(.jost(size: 8, weight: .light))
                .foregroundColor(ChronosTheme.faint)
            Text(domain)
                .font(.jost(size: 8, weight: .medium))
                .foregroundColor(ChronosTheme.gold)
                .tracking(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(ChronosTheme.goldDim.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(ChronosTheme.gold.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// ─────────────────────────────────────────
// SECTION DIVIDER  §3.3
// ─────────────────────────────────────────

struct SectionDividerLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(ChronosTheme.gold.opacity(0.15))
                .frame(height: 1)
            Text(text)
                .font(.jost(size: 9, weight: .light))
                .foregroundColor(ChronosTheme.gold.opacity(0.5))
                .tracking(3)
                .fixedSize()
            Rectangle()
                .fill(ChronosTheme.gold.opacity(0.15))
                .frame(height: 1)
        }
    }
}

// ─────────────────────────────────────────
// DOMAIN CARD  §3.4
// ─────────────────────────────────────────

struct ChronosDomainCard: View {
    let label: String
    let title: String
    let subtitle: String
    let score: Double?
    let isActive: Bool
    let role: DomainRole
    let conflict: ConflictResult?
    let domainBaseline: Double?
    let rawMetrics: DomainRawMetrics
    let expandedNarrative: DomainExpandedNarrative?
    var buildingMessage: String? = nil
    let onExpandRequest: () -> Void

    @State private var isExpanded = false

    // ── Score color — 4-tier spec, no score below 60 renders green ──────────
    var scoreColor: Color {
        guard let s = score else { return Color(hex: "7A8FA6") }  // building blue-grey
        if s >= 80 { return Color(hex: "4ADE80") }               // Strong — green
        if s >= 60 { return Color(hex: "C9A84C") }               // Moderate — gold
        if s >= 40 { return Color(hex: "B0936A") }               // Below baseline — warm tan
        return Color(hex: "E07070")                               // Low — rose
    }

    // ── Card border — role-driven ─────────────────────────────────────────
    var cardBorderColor: Color {
        switch role {
        case .driver:   return Color(red: 0.878, green: 0.439, blue: 0.439).opacity(0.25) // rose
        case .buffer:   return Color(red: 0.290, green: 0.871, blue: 0.502).opacity(0.18) // green
        default:        return isActive ? ChronosTheme.gold.opacity(0.18) : ChronosTheme.border
        }
    }

    // ── Semantic progress bar fill ────────────────────────────────────────
    var progressFill: CGFloat {
        guard let s = score, let baseline = domainBaseline, baseline > 0 else {
            return score.map { CGFloat($0 / 100) } ?? 0
        }
        return min(CGFloat(s / baseline), 1.0)
    }

    // ── Progress bar gradient — follows score color tier ─────────────────
    var barGradient: LinearGradient {
        guard let s = score else {
            return LinearGradient(colors: [Color(hex: "7A8FA6").opacity(0.3)], startPoint: .leading, endPoint: .trailing)
        }
        if s >= 80 {
            return LinearGradient(colors: [Color(hex: "4ADE80").opacity(0.6), Color(hex: "4ADE80")], startPoint: .leading, endPoint: .trailing)
        }
        if s >= 60 {
            return LinearGradient(colors: [ChronosTheme.gold.opacity(0.6), ChronosTheme.goldLight], startPoint: .leading, endPoint: .trailing)
        }
        if s >= 40 {
            return LinearGradient(colors: [Color(hex: "B0936A").opacity(0.7), Color(hex: "B0936A")], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [Color(hex: "E07070").opacity(0.6), Color(hex: "E07070")], startPoint: .leading, endPoint: .trailing)
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
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(cardBorderColor, lineWidth: 1)
                )

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

                // ── Header row — label, title, score, chevron ───────────────
                // Chevron is the tap target. Full-card tap NOT wired (Phase 2).
                HStack(spacing: 12) {
                    // Domain label badge
                    Text(label)
                        .font(.jost(size: 9, weight: isActive ? .medium : .light))
                        .foregroundColor(isActive ? ChronosTheme.gold : ChronosTheme.faint)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isActive ? ChronosTheme.goldDim : ChronosTheme.ink)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isActive ? ChronosTheme.gold.opacity(0.2) : ChronosTheme.border, lineWidth: 1)
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

                    // Score — right side
                    if let s = score {
                        Text("\(Int(s))")
                            .font(.cormorant(size: 22, weight: .light))
                            .foregroundColor(scoreColor)
                    } else if isActive {
                        // Score is nil but domain should be active — show dash in building color
                        Text("—")
                            .font(.cormorant(size: 22, weight: .light))
                            .foregroundColor(Color(hex: "7A8FA6"))
                    }

                    // Role tag — all active, non-building domains
                    if isActive && role != .building {
                        RoleTagView(role: role)
                    }

                    // Chevron — tap affordance (Phase 2: full-card tap reserved)
                    if isActive {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isExpanded.toggle()
                                if isExpanded { onExpandRequest() }
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 11, weight: .light))
                                .foregroundColor(ChronosTheme.faint)
                                .frame(width: 28, height: 28)  // generous tap target
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, isActive ? 10 : 14)

                // ── Semantic progress bar ────────────────────────────────────
                if isActive, score != nil {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(ChronosTheme.faint.opacity(0.3))
                                .frame(height: 3)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(barGradient)
                                .frame(width: geo.size.width * progressFill, height: 3)
                        }
                    }
                    .frame(height: 3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, (isExpanded || conflict != nil) ? 0 : 12)
                }

                // ── Conflict badge — collapsed state ─────────────────────────
                if isActive, !isExpanded, let c = conflict {
                    ConflictBadge(text: c.badgeText)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }

                // ── Building state ──────────────────────────────────────────
                if !isActive, let msg = buildingMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 9, weight: .light))
                            .foregroundColor(Color(hex: "7A8FA6").opacity(0.7))
                        Text(msg.uppercased())
                            .font(.jost(size: 8, weight: .light))
                            .foregroundColor(Color(hex: "7A8FA6").opacity(0.7))
                            .tracking(1.5)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }

                // ── Expanded content ─────────────────────────────────────────
                if isExpanded && isActive {
                    ExpandedDomainContent(
                        label: label,
                        rawMetrics: rawMetrics,
                        narrative: expandedNarrative,
                        conflict: conflict
                    )
                    .padding(.bottom, 4)
                }
            }
        }
        .opacity(label == "D5" && !isActive && buildingMessage == nil ? 0.35 : 1.0)
        .opacity(label == "D4" && !isActive && buildingMessage == nil ? 0.60 : 1.0)
    }
}

// ─────────────────────────────────────────
// ROLE TAG
// ─────────────────────────────────────────

struct RoleTagView: View {
    let role: DomainRole

    var tagColor: Color {
        switch role {
        case .driver:   return Color(hex: "E07070")
        case .buffer:   return Color(hex: "4ADE80")
        case .elevated: return Color(hex: "4ADE80").opacity(0.7)
        case .watch:    return Color(hex: "C9A84C")
        case .stable:   return ChronosTheme.faint
        case .building: return Color(hex: "7A8FA6")
        }
    }

    var body: some View {
        Text(role.rawValue)
            .font(.jost(size: 7, weight: .medium))
            .foregroundColor(tagColor)
            .tracking(1.5)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(tagColor.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(tagColor.opacity(0.25), lineWidth: 1)
                    )
            )
    }
}

// ─────────────────────────────────────────
// CONFLICT BADGE — collapsed state
// ─────────────────────────────────────────

struct ConflictBadge: View {
    let text: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 8, weight: .light))
                .foregroundColor(Color(hex: "C9A84C").opacity(0.7))
            Text(text)
                .font(.jost(size: 10, weight: .light))
                .foregroundColor(ChronosTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(hex: "C9A84C").opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "C9A84C").opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// ─────────────────────────────────────────
// EXPANDED CARD CONTENT
// Today's metric values, baseline reference, observational line.
// Conflict elaboration if cross-domain tension exists.
// ─────────────────────────────────────────

struct ExpandedDomainContent: View {
    let label: String
    let rawMetrics: DomainRawMetrics
    let narrative: DomainExpandedNarrative?
    let conflict: ConflictResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(ChronosTheme.gold.opacity(0.10))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.top, 10)

            VStack(alignment: .leading, spacing: 12) {

                // Metric values + baseline reference
                let rows = metricRows(for: label)
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(rows, id: \.metric) { row in
                            MetricValueRow(
                                metric: row.metric,
                                value: row.value,
                                baseline: row.baseline,
                                unit: row.unit
                            )
                        }
                    }
                }

                // Observational line from narrative layer
                if let narrative = narrative {
                    Text(narrative.observationalLine)
                        .font(.jost(size: 12, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)

                    // Conflict elaboration
                    if let elab = narrative.conflictElaboration {
                        VStack(alignment: .leading, spacing: 6) {
                            Rectangle()
                                .fill(Color(hex: "C9A84C").opacity(0.15))
                                .frame(height: 1)
                            Text(elab)
                                .font(.jost(size: 12, weight: .light))
                                .foregroundColor(ChronosTheme.muted.opacity(0.85))
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    // Loading state for narrative
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.55)
                            .tint(ChronosTheme.gold.opacity(0.35))
                        Text("Reading signals...")
                            .font(.jost(size: 11, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }

    // ── Metric row data ──────────────────────────────────────────────────

    struct MetricRowData {
        let metric: String
        let value: Double?
        let baseline: Double?
        let unit: String
    }

    private func metricRows(for domain: String) -> [MetricRowData] {
        switch domain {
        case "D1":
            return [
                MetricRowData(metric: "HRV", value: rawMetrics.hrv_ms, baseline: nil, unit: "ms"),
                MetricRowData(metric: "Resting HR", value: rawMetrics.resting_hr_bpm, baseline: nil, unit: "bpm")
            ]
        case "D2":
            return [
                MetricRowData(metric: "Sleep", value: rawMetrics.sleep_duration_hrs, baseline: nil, unit: "hrs"),
                MetricRowData(metric: "Efficiency", value: rawMetrics.sleep_efficiency_pct, baseline: nil, unit: "%")
            ]
        case "D3":
            return [
                MetricRowData(metric: "Steps", value: rawMetrics.steps, baseline: nil, unit: "steps"),
                MetricRowData(metric: "Active min", value: rawMetrics.active_minutes, baseline: nil, unit: "min")
            ]
        case "D4":
            return []   // D4 has no raw input metrics to display
        case "D5":
            return []   // D5 is composite — no raw metric breakdown
        default:
            return []
        }
    }
}

struct MetricValueRow: View {
    let metric: String
    let value: Double?
    let baseline: Double?
    let unit: String

    var formattedValue: String {
        guard let v = value else { return "—" }
        switch unit {
        case "hrs":
            let hrs = Int(v)
            let mins = Int((v - Double(hrs)) * 60)
            return mins > 0 ? "\(hrs)h \(mins)m" : "\(hrs)h"
        case "steps":
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return (formatter.string(from: NSNumber(value: Int(v))) ?? "\(Int(v))") + " steps"
        case "%":
            return "\(Int(v))%"
        case "ms", "bpm", "min":
            return "\(Int(v)) \(unit)"
        default:
            return "\(String(format: "%.1f", v)) \(unit)"
        }
    }

    var body: some View {
        HStack {
            Text(metric)
                .font(.jost(size: 11, weight: .light))
                .foregroundColor(ChronosTheme.faint)
            Spacer()
            Text(formattedValue)
                .font(.jost(size: 11, weight: .regular))
                .foregroundColor(ChronosTheme.text.opacity(0.85))
        }
    }
}

// ─────────────────────────────────────────
// SYNTHESIS LINE  §3.6
// Anchors the bottom of domain content.
// Italic serif, muted border, card surface.
// ─────────────────────────────────────────

struct SynthesisLineCard: View {
    let text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.09, green: 0.09, blue: 0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ChronosTheme.border, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 10) {
                Text("TODAY IN ONE LINE")
                    .font(.jost(size: 9, weight: .light))
                    .foregroundColor(ChronosTheme.gold.opacity(0.6))
                    .tracking(3)

                Text("\u{201C}\(text)\u{201D}")
                    .font(.cormorant(size: 17, weight: .light))
                    .italic()
                    .foregroundColor(ChronosTheme.muted)
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

// ─────────────────────────────────────────
// ALLOSTATIC PORTRAIT CARD  (E-11) — unchanged
// 90-day D5 load curve. Renders only when D5 active.
// ─────────────────────────────────────────

struct AllostaticPortraitCard: View {
    @EnvironmentObject var supabase: SupabaseService

    @State private var history: [(date: String, value: Double)] = []
    @State private var isLoading = true

    var trend: String {
        guard history.count >= 14 else { return "Building" }
        let recent = history.suffix(7).map { $0.value }
        let older  = history.prefix(7).map { $0.value }
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg  = older.reduce(0, +)  / Double(older.count)
        let delta = recentAvg - olderAvg
        if delta > 3  { return "Increasing" }
        if delta < -3 { return "Improving" }
        return "Stable"
    }

    var trendColor: Color {
        switch trend {
        case "Improving":  return Color(hex: "4ADE80")
        case "Increasing": return Color(red: 1.0, green: 0.55, blue: 0.45)
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

                if isLoading {
                    HStack(spacing: 10) {
                        ProgressView().scaleEffect(0.6).tint(ChronosTheme.gold.opacity(0.4))
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
                    AllostaticCurve(history: history).frame(height: 80)
                }

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
            guard let userId = supabase.session?.userId else { isLoading = false; return }
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
// ALLOSTATIC CURVE — unchanged from E-11
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

            let points: [CGPoint] = values.enumerated().map { i, v in
                CGPoint(
                    x: CGFloat(i) * step,
                    y: h - CGFloat((v - minV) / range) * h
                )
            }

            ZStack {
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

                if let last = points.last {
                    Circle()
                        .fill(ChronosTheme.goldLight)
                        .frame(width: 6, height: 6)
                        .position(last)
                }

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
// EMPTY STATE — unchanged
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

// ─────────────────────────────────────────
// COLOR HELPER — hex initializer
// ─────────────────────────────────────────

private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8)  & 0xFF) / 255
        let b = Double(rgb         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
