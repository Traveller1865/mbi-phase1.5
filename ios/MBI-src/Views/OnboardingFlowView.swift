// ios/MBI/Views/OnboardingFlowView.swift
// MBI Phase 1 — Onboarding Flow
// Steps: Name & Goal → HealthKit permissions → Baseline Bootstrap

import SwiftUI
import HealthKit

struct OnboardingFlowView: View {
    @EnvironmentObject var supabase: SupabaseService
    @State private var step = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch step {
            case 0: OnboardingNameView(onNext: { step = 1 })
            case 1: OnboardingHealthKitView(onNext: { step = 2 })
            case 2: OnboardingBootstrapView(onComplete: { step = 3 })
            default: EmptyView()
            }
        }
        .animation(.easeInOut, value: step)
    }
}

// ─────────────────────────────────────────
// STEP 1: Name & Step Goal
// ─────────────────────────────────────────

struct OnboardingNameView: View {
    @EnvironmentObject var supabase: SupabaseService
    let onNext: () -> Void

    @State private var displayName = ""
    @State private var stepGoalText = "8000"
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Let's get started")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white)
                Text("We'll personalize everything to you.")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)

            VStack(spacing: 16) {
                MBITextField(placeholder: "Your name", text: $displayName)

                VStack(alignment: .leading, spacing: 6) {
                    MBITextField(placeholder: "Daily step goal", text: $stepGoalText, keyboardType: .numberPad)
                    Text("Default is 8,000 steps. Adjust to your lifestyle.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 32)

            if let error = error {
                Text(error).font(.system(size: 13)).foregroundColor(.red.opacity(0.8))
                    .padding(.top, 12).padding(.horizontal, 32)
            }

            Spacer()

            MBIPrimaryButton(title: "Continue", isLoading: isLoading) {
                guard !displayName.isEmpty, let goal = Int(stepGoalText) else {
                    error = "Please enter your name and a valid step goal."
                    return
                }
                isLoading = true
                Task {
                    do {
                        guard let userId = supabase.session?.userId else { return }
                        try await supabase.updateUser(userId: userId, displayName: displayName, stepGoal: goal)
                        onNext()
                    } catch {
                        self.error = error.localizedDescription
                    }
                    isLoading = false
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

// ─────────────────────────────────────────
// STEP 2: HealthKit Permission
// ─────────────────────────────────────────

struct OnboardingHealthKitView: View {
    let onNext: () -> Void
    @State private var isLoading = false
    @State private var error: String?

    let metrics = [
        ("Heart Rate Variability", "HRV — your primary recovery signal"),
        ("Resting Heart Rate", "Autonomic balance and stress load"),
        ("Respiratory Rate", "Strongest early illness indicator"),
        ("Sleep Duration & Quality", "Cellular repair window"),
        ("Steps & Active Minutes", "Movement and behavioral patterns"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                Text("Connect Apple Health")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.white)
                Text("We read 7 metrics to build your daily score. Nothing is stored on device — all data stays in your private account.")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
                    .lineSpacing(4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 16) {
                ForEach(metrics, id: \.0) { metric in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(metric.0)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            Text(metric.1)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }
                }
            }
            .padding(.horizontal, 32)

            if let error = error {
                Text(error).font(.system(size: 13)).foregroundColor(.red.opacity(0.8))
                    .padding(.top, 16).padding(.horizontal, 32)
            }

            Spacer()

            MBIPrimaryButton(title: "Connect Apple Health", isLoading: isLoading) {
                isLoading = true
                Task {
                    do {
                        try await HealthKitManager.shared.requestAuthorization()
                        onNext()
                    } catch {
                        self.error = "HealthKit authorization failed. Please allow access in Settings → Privacy → Health."
                    }
                    isLoading = false
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

// ─────────────────────────────────────────
// STEP 3: Baseline Bootstrap
// ─────────────────────────────────────────

struct OnboardingBootstrapView: View {
    @EnvironmentObject var supabase: SupabaseService
    let onComplete: () -> Void

    @State private var progress = 0
    @State private var total = 7
    @State private var isStarted = false
    @State private var error: String?
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if isDone {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.white)

                    Text("You're all set")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.white)

                    Text("Your baseline is ready. Your first Chronos Score will be waiting for you tomorrow.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 32)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Building your baseline")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.white)
                    Text("We're reading 7 days of your Apple Health history to personalize your scoring. This takes about 30 seconds.")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.5))
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                if isStarted {
                    VStack(spacing: 16) {
                        ProgressView(value: Double(progress), total: Double(total))
                            .tint(.white)
                            .padding(.horizontal, 32)

                        Text("Reading day \(progress) of \(total)...")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                if let error = error {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                }
            }

            Spacer()

            if isDone {
                MBIPrimaryButton(title: "Open My Dashboard") {
                    Task {
                        if let userId = supabase.session?.userId {
                            try? await supabase.markOnboardingComplete(userId: userId)
                            try? await supabase.loadCurrentUser(userId: userId)
                        }
                        onComplete()
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            } else if !isStarted {
                MBIPrimaryButton(title: "Start Sync") {
                    isStarted = true
                    Task {
                        guard let userId = supabase.session?.userId else { return }
                        do {
                            try await SyncCoordinator.shared.runBaselineBootstrap(userId: userId) { done, total in
                                Task { @MainActor in
                                    self.progress = done
                                    self.total = total
                                }
                            }
                            isDone = true
                        } catch {
                            self.error = "Some data couldn't be read. That's okay — your score will improve as more history accumulates."
                            isDone = true
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

// ─────────────────────────────────────────
// SHARED: Primary Button
// ─────────────────────────────────────────

struct MBIPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .frame(height: 52)

                if isLoading {
                    ProgressView().tint(.black)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                }
            }
        }
        .disabled(isLoading)
    }
}
