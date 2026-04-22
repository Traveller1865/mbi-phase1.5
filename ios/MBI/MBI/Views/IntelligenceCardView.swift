// ios/MBI/MBI/Views/IntelligenceCardView.swift
// MBI Phase 1.5 — Health Intelligence · E-11 revised
// Sheet presented when user taps a driver chip.
// Content cached by metric key — no re-call on repeat taps.
// Regenerates only when the driver changes (new day).
// Framed as a resource the user chose to open — not a warning.

import SwiftUI

// ─────────────────────────────────────────
// INTELLIGENCE SHEET
// Top-level sheet container — Chronos chrome + scroll
// ─────────────────────────────────────────

struct IntelligenceSheet: View {
    let metric: String
    let score: DailyScore
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
// Renders inside the sheet. Reads from and writes to
// the shared cache in DashboardView.
// ─────────────────────────────────────────

struct IntelligenceCard: View {
    let metric: String
    let score: DailyScore
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

                // ── What it measures ──
                IntelligenceSection(
                    label: "WHAT IT MEASURES",
                    text: content.body
                )

                // ── Key takeaway ──
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

                // ── Headline as closing thought ──
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
        // Already cached — nothing to do
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
// INTELLIGENCE SECTION
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
// CONTENT MODEL
// ─────────────────────────────────────────

struct IntelligenceContent {
    let headline: String
    let body: String
    let takeaway: String
}
