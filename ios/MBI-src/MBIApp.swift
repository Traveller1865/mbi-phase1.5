// ios/MBI/MBIApp.swift
// MBI Phase 1 — App Entry Point

import SwiftUI

@main
struct MBIApp: App {
    @StateObject private var supabase = SupabaseService.shared
    @StateObject private var sync = SyncCoordinator.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(supabase)
                .environmentObject(sync)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var supabase: SupabaseService
    @EnvironmentObject var sync: SyncCoordinator

    var body: some View {
        Group {
            if supabase.session == nil {
                AuthView()
            } else if supabase.currentUser?.onboardingComplete != true {
                OnboardingFlowView()
            } else {
                MainTabView()
                    .task {
                        if let userId = supabase.session?.userId {
                            await sync.runDailySync(userId: userId)
                        }
                    }
            }
        }
        .animation(.easeInOut, value: supabase.session?.userId)
    }
}
