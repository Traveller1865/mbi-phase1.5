// ios/MBI/MBI/Views/HorizonModuleView.swift
// MBI Phase 1.5 — Horizon Module Container
// Epic 1 Sprint 3 — Multi-page scaffold
//
// Sprint 3: Page 1 (HorizonSignalView) only.
// Pages 2–4 are commented stubs — not visible, not crashable.
// To add a page in Phase 1.75: add the view to the TabView body,
// increment totalPages in HorizonPageIndicator. No structural rebuild required.

import SwiftUI

struct HorizonModuleView: View {
    @EnvironmentObject var sync: SyncCoordinator
    @EnvironmentObject var supabase: SupabaseService

    @State private var currentPage = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $currentPage) {
                HorizonSignalView()
                    .environmentObject(sync)
                    .environmentObject(supabase)
                    .tag(0)
                    .ignoresSafeArea()

                // ── Phase 1.75 stubs ─────────────────────────────────────────
                // Uncomment and implement when Ontology Engine is ready.
                // Each addition: add view here + increment totalPages below.
                //
                // HorizonTrajectoryView()
                //     .tag(1)
                //
                // HorizonRedirectView()
                //     .tag(2)
                //
                // HorizonEscalateView()
                //     .tag(3)
                // ────────────────────────────────────────────────────────────
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .ignoresSafeArea()

            HorizonPageIndicator(currentPage: currentPage, totalPages: 1)
                .padding(.bottom, 16)
        }
    }
}

// ─────────────────────────────────────────
// PAGE INDICATOR
// Sprint 3: totalPages = 1, one dot rendered.
// Phase 1.75: increment totalPages when each page is activated.
// Active dot color matches current score band state (wired via environment in Phase 1.75).
// For Sprint 3, uses default white — single dot needs no state color differentiation.
// ─────────────────────────────────────────

struct HorizonPageIndicator: View {
    let currentPage: Int
    let totalPages: Int

    // Sprint 3: single dot, white active color is sufficient.
    // Phase 1.75: pass scoreBand in and resolve color here.
    private let dotSize: CGFloat = 6
    private let dotSpacing: CGFloat = 8
    private let activeColor: Color = .white.opacity(0.8)
    private let inactiveColor: Color = .white.opacity(0.25)

    var body: some View {
        HStack(spacing: dotSpacing) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? activeColor : inactiveColor)
                    .frame(width: dotSize, height: dotSize)
            }
        }
        .padding(.top, 12)
    }
}
