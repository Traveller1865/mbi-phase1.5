// ios/MBI/MBI/Views/IntelligenceCardView.swift
// MBI Phase 1.5 — Health Intelligence
// Epic 1 Sprint 1 — §3.4 Driver Detail Content Fix
//
// Changes:
//   - IntelligenceSheet now accepts `driverContext: DriverTapContext`
//   - IntelligenceCard now accepts and renders `driverContext`
//   - "Why This Is Your Driver Today" section inserted above Key Takeaway
//   - Section populated from passed navigation params — NO new Supabase call
//   - Driver 1 uses "primary signal", Driver 2 uses "second-highest deviation"
//   - Wellness framing only — no clinical language
//   - Existing "What It Measures", Key Takeaway, closing tagline — UNCHANGED

import SwiftUI

// ─────────────────────────────────────────
// INTELLIGENCE SHEET
// Top-level sheet container — Chronos chrome + scroll
// ─────────────────────────────────────────

struct IntelligenceSheet: View {
    let metric: String
    let score: DailyScore
    let driverContext: DriverTapContext      // §3.4: receives deviation data
    @Binding var cachedContent: [String: IntelligenceContent]
    @Environment(\.dismiss) var dismiss

    private let metricDisplayNames: [String: String] = [
        "hrv":               "Heart Rate Variability",
        "resting_hr":        "Resting Heart Rate",
        "respiratory_rate":  "Respiratory Rate",
        "sleep_duration":    "Sleep Duration",
        "sleep_efficiency":  "Sleep Quality",
        "steps":             "Daily Steps",
        "active_minutes":    "Active Minutes",
    ]

    var metricName: String {
        metricDisplayNames[metric]
            ?? metric.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var body: some View {
        ZStack {
            ChronosTheme.ink.ignoresSafeArea()

            RadialGradient(
                colors: [ChronosTheme.gold.opacity(0.05), .clear],
                center: .top, startRadius: 0, endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Dismiss ──
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.faint)
                            .padding(10)
                            .background(Circle().fill(ChronosTheme.surface))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                // ── Header ──
                VStack(alignment: .leading, spacing: 6) {
                    Text("CHRONOS · HEALTH INTELLIGENCE")
                        .font(.jost(size: 9, weight: .light))
                        .foregroundColor(ChronosTheme.gold)
                        .tracking(2.5)

                    Text(metricName)
                        .font(.cormorant(size: 30, weight: .light))
                        .foregroundColor(ChronosTheme.text)

                    Text("What this metric is telling your body — and you.")
                        .font(.jost(size: 12, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, ChronosTheme.gold.opacity(0.3), .clear],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .padding(.bottom, 24)

                // ── Card content ──
                ScrollView(showsIndicators: false) {
                    IntelligenceCard(
                        metric: metric,
                        score: score,
                        driverContext: driverContext,
                        cachedContent: $cachedContent
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 48)
                }
            }
        }
    }
}

// ─────────────────────────────────────────
// INTELLIGENCE CARD
// §3.4: Adds "Why This Is Your Driver Today" above Key Takeaway.
// Everything else — What It Measures, Key Takeaway, closing tagline — UNCHANGED.
// ─────────────────────────────────────────

struct IntelligenceCard: View {
    let metric: String
    let score: DailyScore
    let driverContext: DriverTapContext      // §3.4: deviation data — no new fetch
    @Binding var cachedContent: [String: IntelligenceContent]

    @State private var isLoading = false

    private let metricDisplayNames: [String: String] = [
        "hrv":               "Heart Rate Variability",
        "resting_hr":        "Resting Heart Rate",
        "respiratory_rate":  "Respiratory Rate",
        "sleep_duration":    "Sleep Duration",
        "sleep_efficiency":  "Sleep Quality",
        "steps":             "Daily Steps",
        "active_minutes":    "Active Minutes",
    ]

    var metricName: String {
        metricDisplayNames[metric]
            ?? metric.replacingOccurrences(of: "_", with: " ").capitalized
    }

    var content: IntelligenceContent? { cachedContent[metric] }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            if isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(ChronosTheme.gold.opacity(0.5))
                    Text("Preparing your intelligence brief...")
                        .font(.jost(size: 13, weight: .light))
                        .foregroundColor(ChronosTheme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 20)

            } else if let content {

                // ── What it measures (UNCHANGED) ──
                IntelligenceSection(
                    label: "WHAT IT MEASURES",
                    text: content.body
                )

                // ── §3.4: Why This Is Your Driver Today ──
                // Inserted above Key Takeaway.
                // Populated from driverContext params — deterministic, no LLM call.
                DriverReasonSection(
                    metricName: metricName,
                    context: driverContext
                )

                // ── Key takeaway (UNCHANGED) ──
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(ChronosTheme.goldDim)
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(ChronosTheme.gold.opacity(0.2), lineWidth: 1))

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(ChronosTheme.gold)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("KEY TAKEAWAY")
                                .font(.jost(size: 8, weight: .light))
                                .foregroundColor(ChronosTheme.gold.opacity(0.7))
                                .tracking(2.5)
                            Text(content.takeaway)
                                .font(.jost(size: 14, weight: .light))
                                .foregroundColor(ChronosTheme.goldLight)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(16)
                }

                // ── Closing tagline (UNCHANGED) ──
                Text(content.headline)
                    .font(.cormorantItalic(size: 17))
                    .foregroundColor(ChronosTheme.muted)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
        .task { await loadIfNeeded() }
    }

    private func loadIfNeeded() async {
        if cachedContent[metric] != nil { return }

        isLoading = true
        do {
            cachedContent[metric] = try await fetchIntelligence()
        } catch {
            // Graceful fallback — never surface an error state
            cachedContent[metric] = IntelligenceContent(
                headline: "\(metricName) is a window into your body's current capacity.",
                body: "\(metricName) reflects how your body is managing its current demands. When it shifts, your physiology is signalling a change in how it's allocating resources — between stress, recovery, and adaptation. Consistent readings tell a story about what's sustained in your environment or habits.",
                takeaway: "Look at what's been stable over the past week — sleep timing, stress, nutrition — and you'll likely find what's driving this metric."
            )
        }
        isLoading = false
    }

    private func fetchIntelligence() async throws -> IntelligenceContent {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(Config.anthropicAPIKey, forHTTPHeaderField: "x-api-key")

        let prompt = """
        You are the voice of Mynd & Bodi Institute, a prevention-first health intelligence platform.

        ABSOLUTE RULES — NEVER VIOLATE:
        - Never use clinical language or diagnostic framing
        - Never say "autonomic dysfunction", "pathological", "risk factor", or any medical diagnostic term
        - Never say "consult a physician" or suggest medical evaluation
        - Never induce anxiety or shame
        - Always use wellness framing: recovery, resilience, patterns, energy, balance
        - Warm, knowledgeable guide — not a clinician

        CONTEXT:
        - The user has tapped on \(metricName) as one of their active physiological drivers today
        - Current Chronos band: \(score.scoreBand.rawValue)
        - This is a resource the user actively chose to open — not a warning or alert

        Write a clear, warm explanation of \(metricName) as a wellness resource.

        Respond in this exact JSON format with no extra text:
        {
          "headline": "A single compelling thought about what \(metricName) reveals (max 12 words, can be poetic)",
          "body": "3-4 sentences. What this metric measures in plain wellness language. What causes it to shift up or down. Why it matters for how someone feels day to day. Warm and specific.",
          "takeaway": "One sentence. The single most useful thing to know about supporting \(metricName) through daily habits."
        }
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 500,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let text = (json?["content"] as? [[String: Any]])?.first?["text"] as? String ?? ""

        guard let jsonRange = text.range(of: #"\{[\s\S]*\}"#, options: .regularExpression),
              let parsed = try? JSONSerialization.jsonObject(
                with: Data(text[jsonRange].utf8)
              ) as? [String: Any]
        else { throw URLError(.cannotParseResponse) }

        return IntelligenceContent(
            headline: parsed["headline"] as? String ?? "",
            body:     parsed["body"]     as? String ?? "",
            takeaway: parsed["takeaway"] as? String ?? ""
        )
    }
}

// ─────────────────────────────────────────
// DRIVER REASON SECTION  §3.4
//
// "Why This Is Your Driver Today"
// Inserted above Key Takeaway in IntelligenceCard.
//
// Spec:
//   - References metric name, today's value, baseline value, deviation %
//   - Driver 1 uses "primary signal", Driver 2 uses "second-highest deviation"
//   - Wellness framing only — no clinical language
//   - All data from driverContext params — no Supabase call
// ─────────────────────────────────────────

struct DriverReasonSection: View {
    let metricName: String
    let context: DriverTapContext

    // §3.4: Plain-language explanation built from deterministic deviation values
    var explanationText: String {
        guard let todayValue = context.formattedTodayValue,
              let baseline = context.baselineValue,
              let direction = context.deviationDirection,
              let magnitude = context.deviationMagnitudePct else {
            // Fallback: baseline still building
            return "Your \(metricName) is your \(signalPhrase) today. Your baseline is still being established — your body is being listened to."
        }

        let formattedBaseline = formatBaseline(value: baseline, metricRaw: context.metric)
        let directionWord = direction == .below ? "below" : "above"
        let magnitudePct = Int(magnitude.rounded())
        let signalRef = context.isDriver1 ? "primary signal" : "second-highest deviation"

        // §3.4 voice rules: wellness framing, reference plain number and percentage, not alarming
        switch direction {
        case .below:
            return "Your \(metricName) is \(todayValue) today. Your 7-day baseline is \(formattedBaseline) — \(magnitudePct)% \(directionWord) your norm. This is your \(signalRef) your body is prioritising recovery right now."
        case .above:
            return "Your \(metricName) is \(todayValue) today. Your 7-day baseline is \(formattedBaseline) — \(magnitudePct)% \(directionWord) your norm. This is your \(signalRef) your body is showing strong capacity today."
        }
    }

    /// §3.4: "primary signal" for Driver 1, "second-highest deviation" for Driver 2
    var signalPhrase: String {
        context.isDriver1 ? "primary signal" : "second-highest deviation"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WHY THIS IS YOUR DRIVER TODAY")
                .font(.jost(size: 9, weight: .light))
                .foregroundColor(ChronosTheme.gold.opacity(0.6))
                .tracking(2.5)

            Rectangle()
                .fill(ChronosTheme.gold.opacity(0.12))
                .frame(height: 1)

            Text(explanationText)
                .font(.jost(size: 14, weight: .light))
                .foregroundColor(Color(red: 0.865, green: 0.853, blue: 0.830))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Format baseline value in the same unit style as the chip value
    private func formatBaseline(value: Double, metricRaw: String) -> String {
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
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return (formatter.string(from: NSNumber(value: Int(value))) ?? "\(Int(value))") + " steps"
        case "active_minutes":
            return "\(Int(value)) min"
        case "distance":
            return "\(String(format: "%.1f", value)) km"
        default:
            return "\(String(format: "%.1f", value))"
        }
    }
}

// ─────────────────────────────────────────
// INTELLIGENCE SECTION (UNCHANGED)
// ─────────────────────────────────────────

struct IntelligenceSection: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.jost(size: 9, weight: .light))
                .foregroundColor(ChronosTheme.gold.opacity(0.6))
                .tracking(2.5)

            Rectangle()
                .fill(ChronosTheme.gold.opacity(0.12))
                .frame(height: 1)

            Text(text)
                .font(.jost(size: 14, weight: .light))
                .foregroundColor(Color(red: 0.865, green: 0.853, blue: 0.830))
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// ─────────────────────────────────────────
// CONTENT MODEL (UNCHANGED)
// ─────────────────────────────────────────

struct IntelligenceContent {
    let headline: String
    let body: String
    let takeaway: String
}
