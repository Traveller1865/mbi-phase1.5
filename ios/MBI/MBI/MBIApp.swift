// ios/MBI/MBI/MBIApp.swift
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
    @State private var isRestoringSession = true

    var body: some View {
        Group {
            if isRestoringSession {
                // Silent splash while we attempt token refresh
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 12) {
                        Text("CHRONOS")
                            .font(.system(size: 28, weight: .thin))
                            .tracking(8)
                            .foregroundColor(.white)
                        Text("by Mynd & Bodi Institute")
                            .font(.system(size: 10, weight: .light))
                            .tracking(4)
                            .foregroundColor(.gray)
                    }
                }
            } else if supabase.session == nil {
                AuthView()
            } else if supabase.currentUser?.onboardingComplete != true {
                OnboardingFlowView()
            } else {
                MainTabView()
                    .task {
                        if let userId = supabase.session?.userId {
                            try? await supabase.loadCurrentUser(userId: userId)
                            await sync.runDailySync(userId: userId)
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: supabase.session?.userId)
        .animation(.easeInOut(duration: 0.3), value: isRestoringSession)
        .task {
            // On every cold launch: attempt token refresh before showing any screen
            await supabase.refreshSessionIfNeeded()
            isRestoringSession = false
        }
    }
}
