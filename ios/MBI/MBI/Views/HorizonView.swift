// ios/MBI/MBI/Views/HorizonView.swift
// MBI Phase 1.5 — Horizon Tab · Phase 2 Placeholder
// Standalone file — no longer housed in AccountView

import SwiftUI

struct HorizonPlaceholderView: View {
    var body: some View {
        ZStack {
            ChronosTheme.ink.ignoresSafeArea()

            RadialGradient(
                colors: [ChronosTheme.gold.opacity(0.04), .clear],
                center: .center, startRadius: 0, endRadius: 340
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {

                ZStack {
                    Circle()
                        .stroke(ChronosTheme.gold.opacity(0.12), lineWidth: 1)
                        .frame(width: 80, height: 80)
                    Circle()
                        .trim(from: 0, to: 0.65)
                        .stroke(
                            LinearGradient(
                                colors: [ChronosTheme.gold.opacity(0.2), ChronosTheme.goldLight.opacity(0.7)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "scope")
                        .font(.system(size: 22, weight: .ultraLight))
                        .foregroundColor(ChronosTheme.gold.opacity(0.6))
                }

                VStack(spacing: 8) {
                    Text("Horizon")
                        .font(.cormorant(size: 36, weight: .light))
                        .foregroundColor(ChronosTheme.text)
                    Text("RISK INTELLIGENCE · PHASE 2")
                        .font(.jost(size: 9, weight: .light))
                        .foregroundColor(ChronosTheme.gold)
                        .tracking(3)
                }

                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, ChronosTheme.gold.opacity(0.4), .clear],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .frame(width: 120, height: 1)

                Text("What's building upstream.\nUpstream pathway activation, contextual\nhealth intelligence, and your 90-day\nallostatic portrait.")
                    .font(.jost(size: 13, weight: .light))
                    .foregroundColor(ChronosTheme.muted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)

                Text("Unlocks as your baseline matures.")
                    .font(.cormorantItalic(size: 15))
                    .foregroundColor(ChronosTheme.faint)
            }
        }
    }
}
